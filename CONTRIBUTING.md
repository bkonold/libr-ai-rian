# Contributing

Read `CLAUDE.md` first; it is written for an agent but the rules are the
rules. In short:

- A "must never" is a guard rule and a numbered boundary-test step first, a
  sentence in a prompt second. Prompts enforce nothing.
- No code for harmless noise; a sentence of explanation instead.
- Bash you can read top to bottom, Python only for parsing, no new
  dependencies, one PR a night, a deny list that never grows.
- Docs cite files and functions, never line numbers, and stay short enough
  to proofread.

Before a PR: `bash -n` on every script you touched; the offline simulator in
`docs/operations.md` for anything in the nightly; `librarian-boundary-test`
must print `PASS` on a real install for any change to `lib/`. Say in the PR
what changed, how you tested it, and what an operator must do to deploy it.
