---
description: Create a well-structured conventional commit for staged changes
---

1. Run `git diff --staged` to see what is staged
2. Run `git status` to confirm what files are included

Then create a conventional commit:

- Pick the correct type: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`
- Add scope if it clarifies the area changed (e.g. `auth`, `booking`, `ui`, `api`, `db`)
- Write a concise imperative description under 72 chars — WHAT changed, not HOW
- **Only add a body** if the WHY is non-obvious and genuinely helps future readers
- No `Co-Authored-By` or AI attribution lines

Run the commit directly with `git commit -m "<message>"`. Do not ask for confirmation unless there is nothing staged.
