---
paths:
  - "**/*.c"
  - "**/*.cc"
  - "**/*.cpp"
  - "**/*.cxx"
  - "**/*.h"
  - "**/*.hh"
  - "**/*.hpp"
---

# C/C++ navigation via coder MCP

- On the first C/C++ task in a session, call `mcp__coder__cpp_guide` and follow
  it for the rest of the session, including refactors.
- Look up symbols with coder tools, not file reads:
  - function body -> `cpp_function`; class -> `cpp_class`; type -> `cpp_type`
  - const/var -> `cpp_const` / `cpp_var`; macro -> `cpp_macro`
  - who calls X -> `cpp_callers`; where X is used -> `cpp_references`
  - namespace overview -> `cpp_namespace`; project map -> `cpp_snapshot`
- Never use `grep`, `head`, `sed`, or `cat` via Bash to inspect C/C++ code.
- Read is allowed only to load exact file contents immediately before an Edit.
