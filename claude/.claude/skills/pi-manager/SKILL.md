---
name: pi-manager
description: Use when Claude Code should delegate implementation, refactoring, research, or bulk edits to the `pi` coding-agent harness instead of doing them directly. Covers composing `pi -p` prompts, flag selection (--model, --session-id, --mode, --thinking, tool allow/denylists), and verifying pi's work. Always runs pi on Antigravity's gemini-3.8-flash model.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# pi Manager Skill

Claude Code is the **manager**: it plans, scopes, writes the prompt, and verifies. `pi` is the
**worker**: it reads, edits, writes, and runs commands in the repo.

`pi` is at `/Users/ger/.local/share/mise/installs/npm-earendil-works-pi-coding-agent/latest/bin/pi`
(on PATH as `pi`).

## Mandatory model

Every invocation MUST pin the model:

```
--model antigravity/gemini-3.8-flash
```

Never omit it — `pi`'s default provider is `google`, not `antigravity`. The `provider/id` form is
required; `--model gemini-3.8-flash` alone resolves against the default provider.

`pi auth check --provider antigravity` reports `provider_not_found`; that check does not know about
the antigravity provider and is **not** a sign of broken auth. The real readiness test is a run:

```bash
pi -p --model antigravity/gemini-3.8-flash --no-session -nt "reply with exactly: OK"
```

## The standard call

```bash
pi -p --model antigravity/gemini-3.8-flash "<prompt>"
```

- `-p` / `--print` — non-interactive: process the prompt, print the final assistant text, exit.
  **Required** for anything Claude runs via Bash; without it `pi` opens a TUI and hangs.
- In `-p` mode pi executes its tools (read/bash/edit/write) without asking for approval. There is no
  `--dangerously-skip-permissions`-style flag and none is needed — which means the prompt itself is
  the only guardrail. Scope it.
- pi runs in the Bash tool's current working directory and picks up `AGENTS.md` / `CLAUDE.md` from
  there. `cd` to the right repo/subdir first (or pass the path in the prompt).

Run pi in the background (`run_in_background: true`) when the task is more than a small edit —
delegated runs routinely take minutes.

## Flag selection

| Need | Flag |
|---|---|
| Non-interactive (always) | `-p` |
| Pin the model (always) | `--model antigravity/gemini-3.8-flash` |
| Multi-step delegation with memory | `--session-id <stable-id>` |
| Continue the last session | `-c` / `--continue` |
| Throwaway run, no session file | `--no-session` |
| Machine-readable event stream | `--mode json` |
| Reasoning budget | `--thinking off\|minimal\|low\|medium\|high\|xhigh\|max` |
| Read-only investigation | `-t read,bash` or `-xt edit,write` |
| Pure text answer, no tools | `-nt` |
| Extra instructions on top of the system prompt | `--append-system-prompt <text-or-file>` |
| Include files in the first message | `@path/to/file` before the prompt |
| Prompt starts with `-` | `pi -p ... -- "- do the thing"` |

Built-in tools are `read`, `bash`, `edit`, `write`. Names in `-t`/`-xt` are not validated — a typo
silently allows/denies nothing, so double-check spelling.

### Sessions

`--session-id <id>` uses that exact project session and creates it if missing, so it is the reliable
way to hold a multi-turn delegation together:

```bash
pi -p --model antigravity/gemini-3.8-flash --session-id refactor-auth "Step 1: ..."
pi -p --model antigravity/gemini-3.8-flash --session-id refactor-auth "Now apply the same to ..."
```

The first call prints `Warning: No project session found with id '<id>'; creating a new session` —
expected, not an error. Prefer explicit `--session-id` over `-c`, which is ambiguous when other pi
runs are interleaved.

### JSON mode

`--mode json` streams one JSON object per line (`session`, `message_*`, `tool_execution_*`,
`turn_end`, `agent_end`). It is very verbose — never dump it raw into context. Filter with jq:

```bash
# final assistant text
pi -p --mode json --model antigravity/gemini-3.8-flash "<prompt>" \
  | jq -rs '[.[] | select(.type=="agent_end")][-1].messages[-1].content[] | select(.type=="text").text'

# which files pi touched, plus token/cost totals
pi -p --mode json --model antigravity/gemini-3.8-flash "<prompt>" > /tmp/pi.jsonl
jq -r 'select(.type=="entry_appended") | .entry.data.fileChanges[]? | "\(.path) +\(.added) -\(.removed)"' /tmp/pi.jsonl
jq -r 'select(.type=="entry_appended") | .entry.data.usage? // empty' /tmp/pi.jsonl
```

Use plain text mode by default; reach for JSON only when you need the file-change list, usage, or
session id programmatically.

## Writing the prompt

pi gets no context from this conversation. Every prompt must stand alone and carry:

1. **Scope** — exact files or directories; forbid touching anything else.
2. **Goal** — the behavior change, not a vague intent.
3. **Constraints** — existing patterns to follow, APIs to keep stable, tests that must keep passing.
4. **Acceptance check** — the command that proves it worked (`cargo check --workspace`,
   `pnpm test`, …). Tell pi to run it and report the result.
5. **Reporting** — ask for a short summary of files changed and anything it could not do.

Good:

```
In crates/calipa-core/src/channels/whatsapp.rs only: extract the duplicated signature-verification
block in parse_inbound and parse_status into a private fn verify_signature(headers, body, secret)
-> Result<(), CoreError>. Keep both public signatures unchanged. Do not touch other crates.
Then run `cargo check -p calipa-core` and report the outcome and the files you changed.
```

Bad: `clean up the whatsapp parser`.

## Verification (never skip)

pi's self-report is a claim, not evidence. After every delegated run:

```bash
git status --short
git diff
```

Then run the project's own checks (`cargo check --workspace --all-targets`, `cargo clippy`,
`nx run-many -t test`, …) yourself. If pi went out of scope, `git checkout --` the stray files and
re-delegate with a tighter prompt rather than arguing across turns.

## Task routing

| Task | Approach |
|---|---|
| Mechanical, well-specified edits across files | Delegate to pi |
| Bulk renames, boilerplate, test scaffolding, doc comments | Delegate to pi |
| Codebase investigation ("where is X handled?") | Delegate read-only: `-t read,bash` |
| Architecture decisions, API design, trade-offs | Claude decides; pi implements the decision |
| One-line fix Claude already has in context | Claude edits directly — delegation costs more |
| Anything destructive (migrations, force-push, deletes) | Claude does it, after the user confirms |

## Pitfalls

- No `timeout`/`gtimeout` on this machine. Bound long runs with the Bash tool's own `timeout`
  parameter, or `run_in_background`.
- `--mode json` output is enormous; always pipe through jq.
- pi is a sibling of, not a wrapper around, the `antigravity-manager` skill's `agy` CLI — flags do
  not carry over between them.
- Interleaving `-c` with concurrent pi runs picks up the wrong history. Use `--session-id`.
