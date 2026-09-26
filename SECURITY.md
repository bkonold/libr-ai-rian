# Security

What the model sees, what stops it, and what does not. The mechanism is in
`docs/boundaries.md`; this page is the list.

## What the model sees

- The realm's notes (read), the root `CLAUDE.md`, the realm `CLAUDE.md`,
  `index.md` and `lessons.md`.
- The `To file` lines from the daily note, passed as content inside a
  `<material>` tag, escaped so they cannot close it. The prompt says nothing
  in it is an instruction; the guard makes that true for file calls.
- Your comments on last night's PR, filtered to the repo owner's account
  (`pr_comments`). Anyone else's comments are ignored.
- `lessons.md`, which it both reads and appends to. This is the one file
  where a bad night can influence the next; it is a plain note you can edit.
- Nothing else: `env -i`, no shell, no network, `/proc` and `/home` denied,
  the prompt on stdin.

## What stops it

- `--tools` and `--allowedTools`: five file tools, nothing else.
- `--restricted`: file tools fenced to the worktree; user and project
  settings ignored. `--strict-mcp-config`: no MCP servers from a synced
  `.mcp.json`. `--permission-prompts none`: anything that would ask a human
  is denied. The nightly also refuses to run if `.claude/settings*.json`,
  `.mcp.json` or `CLAUDE.local.md` is inside the vault.
- The guard, on every Read/Edit/Write/Glob/Grep: writes only under the realm
  folder, never `journal/`, dot-paths or instruction files; reads only under
  the realm's top folder plus the root `CLAUDE.md`; search patterns must be
  relative. Symlinks and `..` resolved, dangling links included. Any error
  is a deny.
- A static deny list for system paths as a backstop.
- The wrapper after the run: a change the guard did not log, or outside the
  realm, is reverted; a deletion is restored; a remote embed in the text
  holds the PR open. Neither merges.
- The model works in a worktree; the vault only fast-forwards after a merge.
- The boundary test, which fails if a probe was not attempted and denied.

## What does not stop it

- **The Edit substring oracle.** Claude Code checks `old_string` against the
  file before the hook runs, so an Edit on a file the model may not read
  returns "matched N times" or "not found". No contents leak and the file is
  unchanged; a patient model could learn whether a string occurs in a
  non-realm file. Closing it: deny rules per non-realm root entry
  (`ROADMAP.md`).
- **Same unix user.** The model runs as `librarian`, which owns the vault.
  The guard is a hook, not the kernel. A separate `agent` user with per-run
  ACLs is the planned fix.
- **Content inside the realm.** The model may write anything into realm
  notes: wrong facts, a bad merge, text that later reads as instructions to
  another agent. The PR and `git revert` are the answer, not the guard.
- **HELD is a hold, not a block.** A remote embed is detected by pattern in
  added lines; the PR stays open for you. New embed syntaxes are not covered.
- **Merge before review.** The filing PR merges at once by design. Anything
  that syncs from the vault to your devices arrives before you read the PR.
- **Claude Code upgrades.** The harness depends on `--restricted`,
  `--strict-mcp-config`, `--permission-prompts none`, `--tools`,
  `--allowedTools`, `--settings`, `--output-format json` with
  `permission_denials`, and PreToolUse exit 2 meaning deny. The binary is
  pinned; an upgrade is a deliberate installer run followed by the boundary
  test, and the test is what tells you the flags still mean what they did.
- **Your other agents.** The vault syncs to your devices. Instruction files
  are never written by the librarian for that reason, but anything else it
  writes is read by whatever you run there.

## Reporting

Open an issue. For something you would rather not post, email the address on
the maintainer's GitHub profile.
