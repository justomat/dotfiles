eval "$(/opt/homebrew/bin/brew shellenv)"

. "$HOME/.cargo/env"

export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

export NODE_OPTIONS="--max-old-space-size=16384"

# Secrets (API keys, tokens) — not tracked in git
[ -f ~/.secrets ] && . ~/.secrets
# zerobrew
export ZEROBREW_DIR=/Users/ger/.zerobrew
export ZEROBREW_BIN=/Users/ger/.local/bin
export ZEROBREW_ROOT=/opt/zerobrew
export ZEROBREW_PREFIX=/opt/zerobrew/prefix
export PKG_CONFIG_PATH="/opt/zerobrew/prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
_zb_path_append() {
    local argpath="$1"
    case ":${PATH}:" in
        *:"$argpath":*) ;;
        *) export PATH="$argpath:$PATH" ;;
    esac;
}
_zb_path_append $ZEROBREW_BIN
_zb_path_append $ZEROBREW_PREFIX/bin

# zerobrew
export PATH="/opt/zerobrew/prefix/bin:$PATH"
