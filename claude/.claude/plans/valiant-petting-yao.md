# Gemini Manager Skill — Model Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add model selection guidance to the gemini-manager skill so Claude picks the right Gemini model based on task complexity.

**Architecture:** Single-file edit — add a `## Model Selection` section to the skill and reference it in Phase 2 of the Manager Workflow. No new files needed.

**Tech Stack:** Markdown skill file

---

## Context

The gemini-manager skill currently instructs Claude to delegate all coding to Gemini CLI but doesn't specify which model to use. The user wants Claude to:
- Use `gemini-2.5-pro-preview-03-25` for complex tasks (multi-file changes, architecture, debugging)
- Use `gemini-2.5-flash-preview-04-17` for simple/quick tasks (typos, renames, single-line fixes)

This avoids over-using expensive Pro for trivial work and under-using it for tasks that need deep reasoning.

**File to modify:** `~/.claude/skills/gemini-manager/SKILL.md`

---

## Task 1: Add Model Selection Section

**Files:**
- Modify: `~/.claude/skills/gemini-manager/SKILL.md`

- [ ] **Step 1: Add `## Model Selection` section after `## Core Principle`**

Insert this block after line 19 (after the Core Principle section, before `## Absolute Rules`):

```markdown
## Model Selection

Always pick the model based on task complexity before invoking Gemini:

| Task Type | Model | Examples |
|-----------|-------|---------|
| **Complex** | `gemini-2.5-pro-preview-03-25` | Multi-file changes, new features, architecture decisions, debugging non-trivial bugs, refactoring |
| **Simple** | `gemini-2.5-flash-preview-04-17` | Single-line fixes, renaming, adding comments, formatting, trivial typos |

**When in doubt, use Pro.** Flash is only for tasks where the change is obvious and self-contained.
```

- [ ] **Step 2: Update Phase 2 of Manager Workflow to reference model selection**

In the `### Phase 2: Delegate to Gemini` section, replace:

```markdown
Issue clear, specific instructions with context, constraints, and direct language requiring immediate implementation using `--yolo`.
```

with:

```markdown
1. **Select the model** (see Model Selection section above)
2. Issue clear, specific instructions with context, constraints, and direct language requiring immediate implementation using `--yolo` and `--model <selected-model>`.

Example invocation:
```bash
gemini --yolo --model gemini-2.5-pro-preview-03-25 "Implement X in file Y, following pattern Z"
```
```

- [ ] **Step 3: Verify the file looks correct**

Read `~/.claude/skills/gemini-manager/SKILL.md` and confirm:
- `## Model Selection` section exists between `## Core Principle` and `## Absolute Rules`
- Phase 2 references `--model <selected-model>`
- The table has both `gemini-2.5-pro-preview-03-25` and `gemini-2.5-flash-preview-04-17`

---

## Verification

After the edit, open a new Claude Code session and type `/gemini-manager`. Confirm the loaded skill shows the Model Selection section and the updated Phase 2.
