alias cat="bat"
alias ls="eza --group-directories-first -F"

alias mkdir="mkdir -p"
alias fix-spotlight="fd ~ -type d -path './.*' -prune -o -path './Pictures*' -prune -o -path './Library*' -prune -o -path '*node_modules/*' -prune -o -type d -name 'node_modules' -exec touch '{}/.metadata_never_index' \; -print"
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'
