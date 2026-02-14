# Dotfiles

My personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Features

- **Shell**: zsh + fish (using `~/.profile` as single source of truth for env vars via [replay.fish](https://github.com/jorgebucaran/replay.fish))
- **Prompt**: Starship
- **Tools**: mise, homebrew, git, claude code
- **Apps**: Raycast, iTerm2, Karabiner-Elements

## Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/yourusername/dotfiles.git ~/src/justomat/dotfiles
   cd ~/src/justomat/dotfiles
   ```

2. Run the install script:
   ```bash
   ./install.sh
   # This will install stow via brew (if missing) and symlink all packages
   ```

3. Create verify secrets:
   ```bash
   # Add your API keys to ~/.secrets (gitignored)
   nano ~/.secrets
   ```

## Structure

Each top-level directory is a stow package that maps to `$HOME`.

- `shell/` → `~/.profile`, `~/.zshenv`, `~/.zshrc`
- `fish/` → `~/.config/fish/`
- `git/` → `~/.gitconfig`
- `starship/` → `~/.config/starship.toml`
- `mise/` → `~/.config/mise/config.toml`
- `karabiner/` → `~/.config/karabiner/`
- `homebrew/` → `~/.Brewfile`
- `claude/` → `~/.claude.json`, `~/.claude/`

## Secrets

A `.secrets` file is gitignored. It is sourced by `.profile`.
Template:
```bash
export CONTEXT7_API_KEY="your-key-here"
```
