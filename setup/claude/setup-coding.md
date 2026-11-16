## MANDATORY: Keep code simple (KISS) and cyclomatic complexity minimal

These rules apply to all code you write or change, in any language, and to every code review.

- **KISS:** choose the simplest design that meets the requirement. Add no speculative generality, and no layers,
  options or abstractions the task does not need. Prefer plain, direct code a reader understands at a glance.
- **Minimal cyclomatic complexity:** keep each function's branching to the minimum. Prefer early returns, small helper
  functions and flat control flow over nested conditionals and long if/else chains.
- **goto:** use it only where avoiding it would raise cyclomatic complexity, for example one cleanup or error-exit
  label in C that replaces deeply nested conditionals. Never use it as a convenience.
- **Reviews:** every code review checks the changed code against these rules. Code more complex than the task
  requires, or with avoidable branching or nesting, is a finding.
