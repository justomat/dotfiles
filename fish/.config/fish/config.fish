replay source ~/.profile

if status is-interactive
    mise activate fish | source
    zoxide init fish | source
    uv generate-shell-completion fish | source
else
    mise activate fish --shims | source
end

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/ger/Downloads/google-cloud-sdk/path.fish.inc' ]; . '/Users/ger/Downloads/google-cloud-sdk/path.fish.inc'; end
