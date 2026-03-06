---
name: markdown-docs
description: Markdown formatting guidelines for documentation files. Use when writing, reviewing, or modifying Markdown files (.md). Covers table formatting, headings, lists, code blocks, and Mermaid diagrams.
---

# Markdown Formatting Guidelines

When working with Markdown files (`.md`), always adhere to the following guidelines:

## Table Formatting

**Tables must be formatted with aligned borders for plain text readability.**

All table columns must be aligned so that:

- Column separators (`|`) line up vertically
- Header separator dashes (`---`) match the column width
- Cell content is padded with spaces to match the widest cell in each column

### Good Example

```markdown
| Field          | Type | Required | Description                    |
| -------------- | ---- | -------- | ------------------------------ |
| `archerId`     | GUID | Yes      | The archer's unique identifier |
| `tournamentId` | GUID | Yes      | The tournament to register for |
```

### Bad Example

```text
| Field | Type | Required | Description |
|---|---|---|---|
| `archerId` | GUID | Yes | The archer's unique identifier |
| `tournamentId` | GUID | Yes | The tournament to register for |
```

## General Markdown Guidelines

1. **Headings**: Use ATX-style headings (`#`, `##`, `###`) with a blank line before and after.
2. **Lists**: Use `-` for unordered lists and `1.` for ordered lists. Indent nested items with 2 spaces.
3. **Code Blocks**: Use triple backticks with language identifier for syntax highlighting.
4. **Links**: Use reference-style links for repeated URLs or when the URL is long.
5. **Line Length**: Keep lines under 120 characters where practical. Break long paragraphs naturally.
6. **Blank Lines**: Use single blank lines to separate sections. Never use more than one consecutive blank line.

## Mermaid Diagrams

- Limit diagrams to 15-20 nodes maximum
- Use `%%` comments to document purpose and last-updated date
- Use consistent direction within a diagram (`LR` for flows, `TB` for hierarchies)
- Maintain consistent direction throughout a diagram
- Use `subgraph` to group related elements
- Include a legend when using custom colors or non-obvious symbols
