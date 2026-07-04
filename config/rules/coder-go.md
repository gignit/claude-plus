---
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go navigation via coder MCP

- On the first Go task in a session, call `mcp__coder__go_guide` and follow it
  for the rest of the session, including refactors.
- Look up symbols with coder tools, not file reads:
  - function/method body -> `go_function`; type -> `go_type`; const/var -> `go_const` / `go_var`
  - who calls X -> `go_callers`; where X is used -> `go_references`
  - package overview -> `go_package`; project map -> `go_snapshot`
- Never use `grep`, `head`, `sed`, or `cat` via Bash to inspect Go code.
- Read is allowed only to load exact file contents immediately before an Edit.
