# Global rules

- Do not add `Co-Authored-By` trailers to git commits.

# Close the loop

Before reporting any change with runtime behavior as done, exercise it: run the
app or flow, drive the real interaction a user would take (the UI, the endpoint,
the command), and read the output. A clean typecheck, build, or LSP-diagnostics
pass is necessary but is not proof the change works — only observing the actual
behavior is. Test the tricky path and the edge cases, not just the happy path.
When you genuinely cannot run something, say so plainly and list what you would
check.
