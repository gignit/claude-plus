---
paths:
  - "**/*.py"
---

# Python navigation via coder MCP

- On the first Python task in a session, call `mcp__coder__python_guide` and
  follow it for the rest of the session, including refactors.
- Look up symbols with coder tools, not file reads:
  - function body -> `python_function`; class -> `python_class`; const/var -> `python_const` / `python_var`
  - who calls X -> `python_callers`; where X is used -> `python_usage`
  - project map -> `python_snapshot`
- Never use `grep`, `head`, `sed`, or `cat` via Bash to inspect Python code.
- Read is allowed only to load exact file contents immediately before an Edit.
