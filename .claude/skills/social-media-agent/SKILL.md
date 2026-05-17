---
name: social-media-agent
description: Full LinkedIn content pipeline — researches a topic, writes a post,
  generates a whiteboard diagram image, and publishes or schedules to LinkedIn.
  Trigger on: "/social-media-agent", "post about", "write and publish", "create a
  LinkedIn post on", "schedule a post about". Supports --no-image, --draft,
  --schedule, --timezone, --tone flags.
---

Delegate everything to the `social-media-agent` agent defined at
`.claude/agents/social-media-agent.md`. Pass the full input (topic + all flags)
to that agent unchanged and return its result.
