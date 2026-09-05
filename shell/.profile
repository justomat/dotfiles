source ~/.aliases

export EDITOR="zed --wait"
export VISUAL="zed --wait"
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
export ANDROID_HOME=$HOME/Library/Android/sdk
export NODE_OPTIONS="--max-old-space-size=16384"

paths=(
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.orbstack/bin"
    "$HOME/.antigravity/antigravity/bin"
    "$ANDROID_HOME/emulator"
    "$ANDROID_HOME/platform-tools"
)
PATH="$( IFS=":" ; echo "${paths[*]}" ):$PATH"

eval "$(/opt/homebrew/bin/brew shellenv)"

update() {
    local prev_dir="$PWD"
    cd ~
    brew upgrade 2>&1 | sed 's/^/[BREW] /' &
    mise self-update 2>&1 | sed 's/^/[MISE] /'
    if [[ ${pipestatus[1]} -eq 0 ]]; then
        mise up --bump 2>&1 | sed 's/^/[MISE] /' &
    fi
    claude update 2>&1 | sed 's/^/[CLAUDE] /'
    wait
    cd "$prev_dir"
}

# Secrets (API keys, tokens) — not tracked in git
[ -f ~/.secrets ] && . ~/.secrets


# Added by Antigravity CLI installer
export PATH="/Users/ger/.local/bin:$PATH"
