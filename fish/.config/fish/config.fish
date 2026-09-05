replay source ~/.profile

if status is-interactive
    /Users/ger/.local/bin/mise activate fish | source
    zoxide init fish | source
    uv generate-shell-completion fish | source
else
    /Users/ger/.local/bin/mise activate fish --shims | source
end

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/ger/Downloads/google-cloud-sdk/path.fish.inc' ]; . '/Users/ger/Downloads/google-cloud-sdk/path.fish.inc'; end


# Added by Antigravity CLI installer
set -gx PATH "/Users/ger/.local/bin" $PATH
