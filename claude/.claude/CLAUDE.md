- avoid ASCII art diagrams with box-drawing characters (┌─┐│└┘) in responses - they render incorrectly in Zed ACP panel. Use simple text-based layouts, indentation, or bullet points instead. For architecture diagrams, use markdown lists or describe the structure in prose.
- MANDATORY: always use jq to read/write JSON, never use sed/awk/grep/python/node/bash
- always use modern tools by default
  - `ls` → `eza` (colors, icons, git integration)
  - `cat` → `bat` (syntax highlighting, line numbers)
  - `find` → `fd` (50-100x faster, respects .gitignore)
  - `grep` → `rg/ripgrep` (10-50x faster, smarter defaults)
  - `cd` → `z/zoxide` (frecent directory jumping)
  - `diff` → `delta` (better formatting, syntax highlighting)


## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available gstack skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/setup-gbrain`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`.