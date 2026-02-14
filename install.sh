#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(shell fish git starship mise karabiner raycast iterm homebrew claude)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Install stow if missing
if ! command -v stow &>/dev/null; then
    warn "GNU Stow not found, installing via Homebrew..."
    brew install stow
fi

# Copy .secrets to home if it doesn't exist yet
if [ -f "$DOTFILES_DIR/.secrets" ] && [ ! -f "$HOME/.secrets" ]; then
    cp "$DOTFILES_DIR/.secrets" "$HOME/.secrets"
    chmod 600 "$HOME/.secrets"
    info "Copied .secrets to ~/.secrets (update with your actual keys)"
fi

# Backup existing files that would conflict with stow
backup_if_exists() {
    local file="$1"
    if [ -e "$file" ] && [ ! -L "$file" ]; then
        local backup="${file}.dotfiles-backup.$(date +%Y%m%d%H%M%S)"
        warn "Backing up $file → $backup"
        mv "$file" "$backup"
    fi
}

# Pre-flight: backup any real files that stow would replace
for pkg in "${PACKAGES[@]}"; do
    pkg_dir="$DOTFILES_DIR/$pkg"
    [ -d "$pkg_dir" ] || continue

    # Find all files in the package and check if they exist as real files in $HOME
    while IFS= read -r rel_path; do
        target="$HOME/$rel_path"
        backup_if_exists "$target"
    done < <(cd "$pkg_dir" && find . -type f -not -name '.gitkeep' | sed 's|^\./||')
done

echo ""
info "Stowing packages from $DOTFILES_DIR"
echo ""

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        stow -v -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" 2>&1 | while read -r line; do
            echo "  $line"
        done
        info "Stowed: $pkg"
    else
        warn "Skipped: $pkg (directory not found)"
    fi
done

echo ""
info "Done! All dotfiles symlinked."
info "Run 'source ~/.profile' or open a new shell to apply changes."
