if status is-interactive
    # Commands to run in interactive sessions can go here
    starship init fish | source
    zoxide init fish | source
end

fenv source ~/.profile

function tmosh
    mosh --no-init $1 -- tmux new-session -ADs main
end

# homebrew
set -gx LDFLAGS -L/opt/homebrew/lib -L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/libpq/lib
set -gx CPPFLAGS -I/opt/homebrew/include -I/opt/homebrew/opt/openssl@3/include -I/opt/homebrew/opt/libpq/include
set -gx PKG_CONFIG_PATH /opt/homebrew/opt/openssl@3/lib/pkgconfig /opt/homebrew/opt/libpq/lib/pkgconfig

fish_add_path /opt/homebrew/bin
# homebrew end

source /opt/homebrew/opt/asdf/libexec/asdf.fish
source "/opt/homebrew/share/google-cloud-sdk/path.fish.inc"

# pnpm
set -gx PNPM_HOME /Users/ger/Library/pnpm
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba init' !!
set -gx MAMBA_EXE /opt/homebrew/opt/micromamba/bin/micromamba
set -gx MAMBA_ROOT_PREFIX /Users/ger/micromamba
$MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
# <<< mamba initialize <<<

# tabtab source for packages
# uninstall by removing these lines
[ -f ~/.config/tabtab/fish/__tabtab.fish ]; and . ~/.config/tabtab/fish/__tabtab.fish; or true
