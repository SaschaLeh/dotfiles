---
description: Generate a PR title and body from the current git diff
---

1. Run `git log main..HEAD --oneline` to see commits on this branch
2. Run `git diff main...HEAD --stat` to see changed files
3. Run `git diff main...HEAD` for the full diff

Then generate a pull request description:

**Title**: A concise, imperative-mood title following conventional commit style (e.g. `feat(auth): add OAuth2 login`)

**Body**:
```
## Summary
[What this PR does and why]

## Changes
[Bullet list of key changes]

## Testing
[How to verify this works]
```

Keep it factual and based on the actual diff. Do not invent context not present in the code.
