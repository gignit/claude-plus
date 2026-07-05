# Global rules

- Do not add `Co-Authored-By` trailers to git commits.

# Reuse before you invent

Before writing new code, understand what already exists. Search this codebase —
and the libraries and SDK it already depends on — for a function, helper, type,
or pattern that does the job, and use it. Follow the conventions already in the
file instead of adding a second way to do the same thing, and don't hand-roll
what a dependency or the SDK already provides. Reuse an existing helper rather
than duplicating its logic inline. Reach for a new abstraction only after you
have confirmed the code doesn't already have one.

# Close the loop

Before reporting any change with runtime behavior as done, exercise it: run the
app or flow, drive the real interaction a user would take (the UI, the endpoint,
the command), and read the output. A clean typecheck, build, or LSP-diagnostics
pass is necessary but is not proof the change works — only observing the actual
behavior is. Test the tricky path and the edge cases, not just the happy path.
When you genuinely cannot run something, say so plainly and list what you would
check.
