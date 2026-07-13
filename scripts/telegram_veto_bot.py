#!/usr/bin/env python3
"""
telegram_veto_bot.py — long-poll listener that powers the ❌ Cancel button on the
scheduled-LinkedIn Telegram notifications sent by run_scheduled.sh (HITL Model B,
veto-in-Telegram).

Flow: run_scheduled.sh schedules a post via Zernio and sends a Telegram photo whose
inline button has callback_data "cancel:<zernioPostId>:<publishEpoch>". This bot polls
Telegram for that tap and, if it is still before <publishEpoch>, calls
DELETE https://zernio.com/api/v1/posts/<id> to cancel the scheduled post. Once the
publish time has passed the post is (best-effort) already live, so the bot refuses and
tells the user to remove it in LinkedIn/Zernio instead — matching the "only cancel if
still scheduled" decision.

Design notes:
  * Stdlib only (urllib/json/subprocess) — no pip deps, runs under systemd on the VM.
  * Secrets come from GCP Secret Manager at startup via `gcloud` (same source the rest of
    the pipeline uses); nothing is written to disk.
  * Only callbacks originating from telegram-chat-id (the owner) are honored; taps from any
    other chat are ignored, so a leaked button can't be actioned by a stranger.
  * The loop never dies on a single bad update; systemd (Restart=always) covers hard crashes.
"""

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

PROJECT = os.environ.get("PROJECT", "personalassistant-501418")
ZERNIO_BASE = "https://zernio.com/api/v1"
POLL_TIMEOUT = 50  # long-poll seconds


def _gcloud_bin():
    cand = shutil.which("gcloud")
    if cand:
        return cand
    for p in (
        os.path.expanduser("~/google-cloud-sdk/bin/gcloud"),
        "/usr/bin/gcloud",
        "/usr/local/bin/gcloud",
        "/snap/bin/gcloud",
    ):
        if os.path.exists(p):
            return p
    raise RuntimeError("gcloud not found on PATH; set PATH in the systemd unit")


def get_secret(name):
    out = subprocess.run(
        [_gcloud_bin(), "secrets", "versions", "access", "latest",
         "--secret", name, "--project", PROJECT],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def tg(token, method, **params):
    """Call a Telegram Bot API method; return parsed JSON (never raises on API error)."""
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = urllib.parse.urlencode(params).encode()
    try:
        with urllib.request.urlopen(url, data=data, timeout=POLL_TIMEOUT + 15) as r:
            return json.loads(r.read().decode())
    except Exception as e:  # noqa: BLE001 — best-effort, keep the loop alive
        print(f"[warn] telegram {method} failed: {e}", flush=True)
        return {"ok": False}


def zernio_delete(api_key, post_id):
    """DELETE a Zernio post. Returns (ok, detail)."""
    req = urllib.request.Request(
        f"{ZERNIO_BASE}/posts/{urllib.parse.quote(post_id)}",
        method="DELETE",
        headers={"Authorization": f"Bearer {api_key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return True, r.read().decode()[:200]
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code}: {e.read().decode()[:200]}"
    except Exception as e:  # noqa: BLE001
        return False, str(e)


def handle_callback(token, api_key, owner_chat, cq):
    cq_id = cq.get("id")
    data = cq.get("data", "")
    msg = cq.get("message", {}) or {}
    chat_id = str((msg.get("chat", {}) or {}).get("id", ""))

    # Owner gate: ignore taps from anyone but the configured chat.
    if chat_id != str(owner_chat):
        tg(token, "answerCallbackQuery", callback_query_id=cq_id,
           text="Not authorized.", show_alert=True)
        print(f"[warn] ignoring callback from non-owner chat {chat_id}", flush=True)
        return

    if not data.startswith("cancel:"):
        tg(token, "answerCallbackQuery", callback_query_id=cq_id)
        return

    parts = data.split(":")
    post_id = parts[1] if len(parts) > 1 else ""
    try:
        epoch = int(parts[2]) if len(parts) > 2 else 0
    except ValueError:
        epoch = 0

    # Time guard: once the scheduled instant has passed, the post is (best-effort) live.
    if epoch and time.time() >= epoch:
        tg(token, "answerCallbackQuery", callback_query_id=cq_id,
           text="Already published — remove it in LinkedIn/Zernio.", show_alert=True)
        _mark(token, msg, "⚠️ Too late to cancel — this post already published.")
        return

    if not post_id:
        tg(token, "answerCallbackQuery", callback_query_id=cq_id,
           text="Missing post id.", show_alert=True)
        return

    ok, detail = zernio_delete(api_key, post_id)
    if ok:
        tg(token, "answerCallbackQuery", callback_query_id=cq_id, text="Cancelled ✅")
        _mark(token, msg, "❌ Cancelled — this post will NOT be published.")
        print(f"[info] cancelled Zernio post {post_id}", flush=True)
    else:
        tg(token, "answerCallbackQuery", callback_query_id=cq_id,
           text="Cancel failed — see the bot log.", show_alert=True)
        print(f"[error] Zernio delete failed for {post_id}: {detail}", flush=True)


def _mark(token, msg, note):
    """Append a status note to the original message and drop its inline keyboard."""
    chat_id = (msg.get("chat", {}) or {}).get("id")
    mid = msg.get("message_id")
    if chat_id is None or mid is None:
        return
    if "caption" in msg:
        tg(token, "editMessageCaption", chat_id=chat_id, message_id=mid,
           caption=(msg.get("caption", "") + "\n\n" + note))
    else:
        tg(token, "editMessageText", chat_id=chat_id, message_id=mid,
           text=(msg.get("text", "") + "\n\n" + note))


def main():
    token = get_secret("linkedin-bot-token")
    owner_chat = get_secret("telegram-chat-id")
    api_key = get_secret("zernio-api-key")
    print(f"[info] veto bot started (project={PROJECT}, owner_chat={owner_chat})", flush=True)

    offset = None
    while True:
        try:
            params = {"timeout": POLL_TIMEOUT, "allowed_updates": json.dumps(["callback_query"])}
            if offset is not None:
                params["offset"] = offset
            resp = tg(token, "getUpdates", **params)
            for upd in resp.get("result", []):
                offset = upd["update_id"] + 1
                cq = upd.get("callback_query")
                if cq:
                    try:
                        handle_callback(token, api_key, owner_chat, cq)
                    except Exception as e:  # noqa: BLE001 — one bad update must not kill the bot
                        print(f"[error] handling callback failed: {e}", flush=True)
        except Exception as e:  # noqa: BLE001
            print(f"[error] poll loop error: {e}", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
