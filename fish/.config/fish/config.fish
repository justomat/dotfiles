replay source ~/.profile
# source ~/.aliases

zb completion fish | source

if status is-interactive
    mise activate fish | source
    starship init fish | source
    zoxide init fish | source
    uv generate-shell-completion fish | source
else
    mise activate fish --shims | source
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Abbreviations
abbr -a vim nvim
abbr -a cat bat
abbr -a ls 'eza --group-directories-first -F'
abbr -a mkdir 'mkdir -p'
abbr -a d docker
abbr -a dc 'docker compose'
abbr -a compose 'docker compose'

# Added by Antigravity
fish_add_path /Users/ger/.antigravity/antigravity/bin
