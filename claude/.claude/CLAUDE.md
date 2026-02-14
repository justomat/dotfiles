- do not advertise claude in git commit
- avoid ASCII art diagrams with box-drawing characters (┌─┐│└┘) in responses - they render incorrectly in Zed ACP panel. Use simple text-based layouts, indentation, or bullet points instead. For architecture diagrams, use markdown lists or describe the structure in prose.
- token limit management: When token usage approaches limits (within 15-20% of max), pause work immediately. Save current state/progress clearly, inform user of token limit approaching, and suggest resuming after limit refresh. Never continue blindly when near limits - proper checkpointing prevents lost work.
- always use modern tools by default
  - `ls` → `eza` (colors, icons, git integration)
  - `cat` → `bat` (syntax highlighting, line numbers)
  - `find` → `fd` (50-100x faster, respects .gitignore)
  - `grep` → `rg/ripgrep` (10-50x faster, smarter defaults)
  - `cd` → `z/zoxide` (frecent directory jumping)
  - `diff` → `delta` (better formatting, syntax highlighting)
  - JSON parsing → `jq` (never use sed/awk/grep for JSON)
  - usage examples:
    fd "pattern"              # find files
    fd -t f "\.js$"           # find JS files only
    rg "pattern"              # search content
    rg -i "pattern"           # case-insensitive
    jq '.' file.json          # pretty print
    jq '.key' file.json       # extract value
