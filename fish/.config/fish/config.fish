replay source ~/.profile

if status is-interactive
    mise activate fish | source
    zoxide init fish | source
    uv generate-shell-completion fish | source
else
    mise activate fish --shims | source
end
