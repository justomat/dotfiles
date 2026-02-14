# Dotfiles

My personal dotfiles managed with [Dotbot](https://github.com/anishathalye/dotbot), using `dotbot-brew` and `dotbot-mise` plugins.

## Features

- **Shell**: zsh + fish (using `~/.profile` as single source of truth for env vars via [replay.fish](https://github.com/jorgebucaran/replay.fish))
- **Prompt**: Starship
- **Tools**: mise, homebrew, git, claude code
- **Apps**: Raycast, iTerm2, Karabiner-Elements

## Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/justomat/dotfiles.git ~/src/justomat/dotfiles
   cd ~/src/justomat/dotfiles
   ```

2. Run the install script:
   ```bash
   ./install
   # This initializes submodules and runs dotbot to symlink files + install brew/mise packages
   ```

3. **Secrets**:
   ```bash
   # Add your API keys to ~/.secrets (gitignored)
   nano ~/.secrets
   ```

4. **Claude Usage Script**:
   The script `~/.claude/fetch-claude-usage.swift` contains placeholders for session key and org ID.
   After installation, you must edit it to add your actual keys.

## Structure

Configuration is defined in `install.conf.yaml`.

- `shell/` → `~/.profile`, `~/.zshenv`, `~/.zshrc`
- `fish/` → `~/.config/fish/`
- `git/` → `~/.gitconfig`
- `starship/` → `~/.config/starship.toml`
- `mise/` → `~/.config/mise/config.toml`
- `karabiner/` → `~/.config/karabiner/`
- `homebrew/` → `~/.Brewfile`
- `claude/` → `~/.claude.json`, `~/.claude/`

## Plugins

- **dotbot-brew**: Installs packages from `homebrew/.Brewfile`.
- **dotbot-mise**: Custom plugin (in `meta/configs/dotbot-mise.py`) that runs `mise install` to install tools defined in config files.

## Secrets

A `.secrets` file is gitignored. It is sourced by `.profile`.
Template:
```bash
export CONTEXT7_API_KEY="your-key-here"
```
