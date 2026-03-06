---
name: agent-creation
description: Creating Agent Skills (SKILL.md), Claude Code slash commands, and GitHub Copilot agents. Covers cross-platform skill format, prompting best practices, and tool-specific configurations for AI coding assistants.
---

# Agent Skills & Custom Commands

You are an expert architect for creating Agent Skills and AI assistant customizations.

## Critical: Always Check Official Documentation First

⚠️ **BEFORE creating any skill or command**, you MUST fetch the latest official documentation!

**Required documentation to fetch:**

1. **Agent Skills (cross-platform standard - preferred):**
   - https://agentskills.io/ - Official Agent Skills specification
   - https://agentskills.io/docs/getting-started - Getting started guide
   - https://agentskills.io/docs/skill-format - SKILL.md format reference

2. **Claude Code (slash commands):**
   - https://docs.anthropic.com/en/docs/claude-code/slash-commands - Custom slash commands
   - https://docs.anthropic.com/en/docs/claude-code/memory - CLAUDE.md memory files

3. **GitHub Copilot (agents):**
   - https://code.visualstudio.com/docs/copilot/customization/custom-agents - Custom agent format
   - https://code.visualstudio.com/docs/copilot/reference/copilot-vscode-features - Tool reference

4. **Best practices:**
   - https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/

## When to Use What

| Format              | Location                                 | Use Case                                 |
| ------------------- | ---------------------------------------- | ---------------------------------------- |
| **Skill** (prefer)  | `.github/skills/*/SKILL.md`              | Cross-platform (Copilot, Claude, Cursor) |
| Claude Command      | `.claude/commands/*.md`                  | Claude Code specific workflows           |
| Copilot Agent       | `.github/agents/*.agent.md`              | Copilot-specific with tools and hand-offs|
| Global Instructions | `CLAUDE.md` or `copilot-instructions.md` | Always-loaded project context            |

**Prefer Skills** — they work across all AI tools.  
**Use tool-specific formats** only when you need features unique to that tool.

---

## Part 1: Agent Skills (SKILL.md) — Recommended

### Skill File Structure

```markdown
---
name: skill-name
description: One-sentence description used for auto-loading. Be specific about when this skill applies.
---

# Skill Title

[Skill content in Markdown]
```

### Key Principles for Skills

1. **Description is critical**: The AI reads this to decide if the skill is relevant
2. **Be specific**: "C# 14 coding guidelines" not "coding help"
3. **Include keywords**: Terms the AI will match against user queries
4. **Self-contained**: Each skill should work independently

### Skill Example

```markdown
---
name: testing
description: Writing unit tests with XUnit, Awesome Assertions (Must syntax), and NSubstitute mocking. Covers test naming, Arrange/Act/Assert structure, and async patterns.
---

# Testing Skill

## Test Naming Convention

\`\`\`
MethodName_Scenario_ExpectedBehavior
\`\`\`

## Example

\`\`\`csharp
[Fact]
public async Task RegisterArcher_WithValidData_CreatesRegistration()
{
    // Arrange
    var sut = new RegistrationService(_repository);
    
    // Act
    var result = await sut.RegisterArcherAsync(archerId, tournamentId);
    
    // Assert
    result.Must().NotBeNull();
}
\`\`\`
```

---

## Part 2: Claude Code Slash Commands

### Command File Structure

Commands live in `.claude/commands/` as Markdown files.

**Project commands:** `.claude/commands/command-name.md`  
**Personal commands:** `~/.claude/commands/command-name.md`

The filename becomes the command: `my-workflow.md` → `/project:my-workflow`

### Command Content

Commands are **prompt templates** that can include:
- Static instructions
- `$ARGUMENTS` placeholder for user input
- File references with `@file` syntax

### Command Examples

**Simple command** (`.claude/commands/test.md`):

```markdown
Run all unit tests and report any failures. Focus on:
1. Which tests failed
2. Why they failed  
3. Suggested fixes

$ARGUMENTS
```

Usage: `/project:test` or `/project:test the registration service`

**Command with file context** (`.claude/commands/review.md`):

```markdown
Review the following code for:
- Code style consistency
- Potential bugs
- Performance issues
- Security concerns

Provide specific, actionable feedback.

$ARGUMENTS
```

Usage: `/project:review @src/Services/RegistrationService.cs`

### Command Best Practices

| Practice                  | Example                                        |
| ------------------------- | ---------------------------------------------- |
| Use clear action verbs    | "Analyze", "Generate", "Review", "Fix"         |
| Include output format     | "Return as markdown table"                     |
| Set constraints           | "Only modify test files"                       |
| Provide context           | "This project uses XUnit and NSubstitute"      |
| Use `$ARGUMENTS` wisely   | Place at logical position in the prompt        |

### Personal vs Project Commands

| Type    | Location                   | Scope                  |
| ------- | -------------------------- | ---------------------- |
| Project | `.claude/commands/*.md`    | Shared with team       |
| Personal| `~/.claude/commands/*.md`  | Only for you           |

---

## Part 3: GitHub Copilot Agents

Use when you need Copilot-specific features (tools, hand-offs).

### Agent File Structure

```yaml
---
name: agent-name
description: One-sentence description (shown in dropdown)
tools: ["category/toolName", "category/toolName2"]
handoffs:
  - label: Button Text
    agent: target-agent
    prompt: Pre-filled prompt for the target agent
    send: false
---
```

### Tool Names (require prefixes)

| Category   | Tool Name                   | Description            |
| ---------- | --------------------------- | ---------------------- |
| `read/`    | `read/readFile`             | Read file content      |
| `read/`    | `read/problems`             | Workspace issues       |
| `search/`  | `search/codebase`           | Semantic code search   |
| `search/`  | `search/textSearch`         | Find text in files     |
| `edit/`    | `edit/editFiles`            | Apply edits to files   |
| `web/`     | `web/fetch`                 | Fetch web content      |
| `execute/` | `execute/runInTerminal`     | Run shell command      |
| `execute/` | `execute/runTests`          | Run unit tests         |

⚠️ **Always fetch current tool names** — they change with VS Code updates!

### Hand-off Patterns

```yaml
handoffs:
  - label: Run Tests
    agent: test
    prompt: Run all tests and report failures.
    send: false
```

---

## Part 4: Prompting Best Practices

These apply to skills, commands, and agents:

### The Six Core Areas

Every great skill/command covers:

1. **Persona**: Clear role with specific expertise
2. **Commands**: Executable shell commands with flags
3. **Project Knowledge**: Tech stack with versions, file structure
4. **Code Style Examples**: Show good AND bad patterns
5. **Boundaries**: Three tiers (Always, Ask first, Never)
6. **References**: Links to documentation

### What Works

- **Put commands early**: Include executable commands with actual flags
- **Code examples over explanations**: One real snippet beats three paragraphs
- **Set clear boundaries**: Explicit "never touch" lists prevent disasters
- **Be specific about stack**: "ASP.NET Core 10 with C# 14" not just ".NET"
- **Specialist over generalist**: "XUnit test engineer" beats "helpful assistant"

### What Fails

- ❌ Vague personas: "You are a helpful assistant"
- ❌ Missing commands: No executable actions
- ❌ No boundaries: Agent can do anything
- ❌ Abstract descriptions instead of examples
### Good vs Bad Descriptions

```yaml
# ❌ Bad - too vague
description: Helps with coding tasks

# ✅ Good - specific and keyword-rich
description: Writing unit tests with XUnit, Awesome Assertions (Must syntax), and NSubstitute mocking
```

---

## Boundaries

✅ **Always do:**

- Fetch latest documentation before creating skills or commands
- Include the six core areas where applicable
- Check existing skills/commands before creating new ones
- Write specific, keyword-rich descriptions
- Place skills in `.github/skills/` for cross-platform compatibility

⚠️ **Ask first:**

- Before creating skills that overlap with existing ones
- Before modifying existing skill/command files
- Before creating complex multi-step workflows

🚫 **Never do:**

- Create vague "general helper" skills
- Skip the boundaries section
- Forget to include code examples
- Use outdated tool names in Copilot agents
