---
name: commit
description: Creating git commits using Conventional Commits specification. Covers commit types (feat, fix, docs, etc.), scopes, breaking changes, body, and footer formatting.
---

# Conventional Commits

You are an expert at creating well-structured git commit messages following the Conventional Commits v1.0.0 specification.

## Commit Message Structure

```
<type>[optional scope]: <description>

[optional body]

```

## Commit Types

| Type       | Description                                           | SemVer Impact |
| ---------- | ----------------------------------------------------- | ------------- |
| `feat`     | New feature for the user                              | MINOR         |
| `fix`      | Bug fix for the user                                  | PATCH         |
| `docs`     | Documentation only changes                            | -             |
| `style`    | Formatting, missing semicolons, etc (no logic)        | -             |
| `refactor` | Code change that neither fixes a bug nor adds feature | -             |
| `perf`     | Performance improvement                               | PATCH         |
| `test`     | Adding or correcting tests                            | -             |
| `build`    | Changes to build system or dependencies               | -             |
| `ci`       | CI configuration changes                              | -             |
| `chore`    | Other changes that don't modify src or test           | -             |
| `revert`   | Reverts a previous commit                             | -             |

## Breaking Changes

Two ways to indicate a breaking change (MAJOR version bump):

```bash
# Method 1: Exclamation mark before colon
feat!: remove deprecated API endpoints

# Method 2: Footer with BREAKING CHANGE
feat: change authentication flow

BREAKING CHANGE: JWT tokens now expire after 1 hour instead of 24 hours
```

## Scope (Optional)

Scope provides context about what part of the codebase changed:

```bash
feat(auth): add password reset functionality
fix(booking): correct date calculation for recurring classes
docs(api): update webhook documentation
refactor(ui): simplify form validation logic
```

**Common scopes for BookMotion**:

- `auth` - Authentication/authorization
- `booking` - Booking system
- `course` - Course management
- `class` - Class/training sessions
- `payment` - Stripe/payment integration
- `profile` - User profiles
- `subscription` - Subscription management
- `ui` - UI components
- `api` - API routes/endpoints
- `db` - Database/migrations
- `email` - Email system

## Description Rules

- Use imperative mood: "add" not "added" or "adds"
- Don't capitalize first letter
- No period at the end
- Keep under 72 characters
- Describe WHAT, not HOW

```bash
# Good
feat(booking): add waitlist notification system
fix(auth): prevent session timeout on active users
refactor(ui): simplify booking form validation

# Bad
feat(booking): Added waitlist notifications.   # Past tense, period, capitalized
fix: fixed the bug                             # Vague, past tense
feat: Changes to booking system                # Vague, not imperative
```

## Body (Optional)

- Blank line between description and body
- Explain WHY the change was made
- Can include motivation and contrast with previous behavior
- Wrap at 72 characters

```bash
fix(booking): prevent double booking on slow networks

Users on slow connections could click the book button multiple times
before receiving confirmation, resulting in duplicate bookings.

Add debounce and optimistic UI lock to prevent this race condition.
```

## Footer (Optional)

- Blank line between body and footer
- Reference issues: `Refs: #123, #456`
- Close issues: `Closes: #123` or `Fixes: #789`
- Breaking changes: `BREAKING CHANGE: description`
- Co-authors: `Co-authored-by: Name <email>`

```bash
feat(subscription): add family plan support

Implement shared subscription for family members with individual
booking limits per member.

Closes: #234
Refs: #198
Co-authored-by: Claude Opus 4.5 <noreply@anthropic.com>
```

## Complete Examples

### Simple fix

```bash
fix(ui): correct button alignment on mobile
```

### Feature with scope and body

```bash
feat(course): add multi-day course scheduling

Courses can now span multiple non-consecutive days. This enables
workshops that meet twice weekly over several weeks.

Closes: #456
```

### Breaking change with explanation

```bash
feat(api)!: change booking response format

BREAKING CHANGE: The booking API now returns a nested structure with
separate `booking` and `payment` objects instead of a flat response.

Migration: Update client code to access `response.booking.id` instead
of `response.id`.
```

### Revert

```bash
revert: feat(booking): add auto-confirmation for trusted users

This reverts commit abc123def.

Auto-confirmation caused issues with subscription validation. Reverting
until the subscription check can be integrated properly.

Refs: #789
```

## Workflow for Creating Commits

1. **Check changes**: `git status` and `git diff --staged`
2. **Identify type**: What kind of change is this?
3. **Determine scope**: What area of the codebase?
4. **Write description**: Imperative, concise, WHAT not HOW
5. **Add body if needed**: Explain WHY for non-obvious changes
6. **Add footer**: Reference issues, breaking changes

## Commit Message Template

Use HEREDOC for proper formatting:

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body - optional, explain WHY>

<footer - optional>
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

## Boundaries

**Always do**:

- Use lowercase for type and scope
- Use imperative mood in description
- Keep description under 72 characters
- Add body for non-trivial changes
- Reference related issues in footer
- Include Co-Authored-By when AI assisted

**Ask first**:

- Before using unconventional types
- Before force pushing or amending shared commits
- If unsure about breaking change classification

**Never do**:

- Use past tense ("added", "fixed")
- Capitalize description first letter
- End description with period
- Create empty commits
- Commit sensitive data (.env, secrets)
- Use vague messages ("fix bug", "update code", "WIP")
