- avoid ASCII art diagrams with box-drawing characters (┌─┐│└┘) in responses - they render incorrectly in Zed ACP panel. Use simple text-based layouts, indentation, or bullet points instead. For architecture diagrams, use markdown lists or describe the structure in prose.
- MANDATORY: always use jq to read/write JSON, never use sed/awk/grep/python/node/bash
- always use modern tools by default
  - `ls` → `eza` (colors, icons, git integration)
  - `cat` → `bat` (syntax highlighting, line numbers)
  - `find` → `fd` (50-100x faster, respects .gitignore)
  - `grep` → `rg/ripgrep` (10-50x faster, smarter defaults)
  - `cd` → `z/zoxide` (frecent directory jumping)
  - `diff` → `delta` (better formatting, syntax highlighting)

@RTK.md
