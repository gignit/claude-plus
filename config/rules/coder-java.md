---
paths:
  - "**/*.java"
---

# Java navigation via coder MCP

- On the first Java task in a session, call `mcp__coder__java_guide` and follow
  it for the rest of the session, including refactors.
- Look up symbols with coder tools, not file reads:
  - method body -> `java_method`; class -> `java_class`; field -> `java_field`
  - who calls X -> `java_callers`; where X is used -> `java_references`
  - package overview -> `java_package`; project map -> `java_snapshot`
- Never use `grep`, `head`, `sed`, or `cat` via Bash to inspect Java code.
- Read is allowed only to load exact file contents immediately before an Edit.
