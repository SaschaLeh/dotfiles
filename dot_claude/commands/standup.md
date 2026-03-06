---
description: Summarize recent commits as a standup update
---

1. Run `git log --since="2 days ago" --oneline --author="$(git config user.name)"` to get recent commits
2. Run `git diff HEAD~5..HEAD --stat` for a sense of scope

Then write a brief standup update in this format:

**Yesterday / Recent work:**
- [bullet per meaningful commit or grouped theme]

**Today:**
- [infer next logical work from branch name, open changes, or recent context]

**Blockers:**
- None (unless you can identify one from the diff)

Keep it concise and human — one sentence per bullet max.
