---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tsconfig.json"
---

# TypeScript navigation via coder MCP

- On the first TypeScript task in a session, call `mcp__coder__typescript_guide`
  and follow it for the rest of the session, including refactors.
- Look up symbols with coder tools, not file reads:
  - function body -> `typescript_function`; type -> `typescript_type`; const/var -> `typescript_const` / `typescript_var`
  - who calls X -> `typescript_callers`; where X is used -> `typescript_references`
  - classes/interfaces/enums -> `typescript_classes` / `typescript_interfaces` / `typescript_enums`
  - project map -> `typescript_snapshot`
- Never use `grep`, `head`, `sed`, or `cat` via Bash to inspect TypeScript code.
- Read is allowed only to load exact file contents immediately before an Edit.
