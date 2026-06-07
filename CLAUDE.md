# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal macOS dotfiles managed with [Dotbot](https://github.com/anishathalye/dotbot). There is no build/test/lint cycle — the unit of work is "change a config file and re-link."

## Core mechanism: everything is a symlink

`install.conf.yaml` is the source of truth. Each entry maps a path in `$HOME` to a file in this repo, and `./install` creates symlinks (`relink: true`, so it overwrites existing links).

**Consequence: tracked files are symlinked into `$HOME`, so editing a file here edits the live, active config immediately** — no copy step. Conversely, anything written directly to `~/.config/...` that isn't in `install.conf.yaml` is *not* tracked here.

To add a new dotfile: drop it under the matching repo subdir, add a `~/path: subdir/path` line to `install.conf.yaml`, then run `./install`.

## Commands

```bash
./install            # init required submodules + run dotbot: link files, brew bundle, mise install
./install --only link # (any dotbot flag passes through after `./install`)
```

`./install` is idempotent and safe to re-run. It is the only command — there is no separate build or test.

## Install pipeline (meta/)

`./install` runs dotbot with three stages driven by `install.conf.yaml`:
1. **link** — symlinks per the `link:` block.
2. **brewfile** (`meta/dotbot-brew`, submodule) — installs `homebrew/.Brewfile`.
3. **mise** (`meta/configs/dotbot-mise.py`, local custom plugin) — runs `mise install` from `$HOME` to install everything in `mise/.config/mise/config.toml`.

`meta/dotbot` and `meta/dotbot-brew` are git submodules (`./install` initializes them). The mise plugin is a local file, not a submodule.

## Shell environment: single source of truth

`shell/.profile` holds all env vars / PATH and is loaded by both shells:
- **zsh**: `.zshenv` → `source ~/.profile`.
- **fish**: `config.fish` uses `replay source ~/.profile` ([replay.fish](https://github.com/jorgebucaran/replay.fish)) to import POSIX exports into fish.

So put environment changes in `shell/.profile`, not in shell-specific files. Secrets live in `~/.secrets` (gitignored), sourced at the end of `.profile`. Fish plugins are declared in `fish/.config/fish/fish_plugins` (managed by Fisher).

## The claude/ directory

The whole `~/.claude` is force-symlinked to `claude/.claude`. `claude/.claude/.gitignore` is what separates **tracked config** (`settings.json`, `CLAUDE.md`, `commands/`, `skills/`, `rules/`, statusline scripts) from **untracked runtime state** (`projects/`, `sessions/`, `history.jsonl`, `cache/`, `plugins/`, etc.). When adding new Claude config, confirm it isn't caught by that ignore list, or it won't be committed.
