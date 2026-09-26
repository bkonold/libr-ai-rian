# librarian

A nightly job that files your one-line captures into an Obsidian vault, as a
pull request you read over coffee. The model that does the filing runs inside
a boundary you can test, not one you have to trust.

## The two ideas

**Propose, then review, with git as the record.** You jot lines under
`### To file` in today's daily note, on any device. At 03:00 the librarian
commits your day as `you: DATE`, runs a confined `claude -p` per realm
(`personal/`, `work/<co>/`) in a throwaway git worktree, and opens one pull
request on the vault's private GitHub repo, merged at once. The daily note
gets a `## Filed` list linking every note that changed. In the morning you
read the PR; a comment on it is applied the next night, and a stated rule
lands in that realm's `lessons.md`. Nothing waits on you. `git revert`
undoes a night. An optional second PR, `tidy: DATE`, proposes fixes to notes
you edited yourself and is left open for you to merge or ignore.

**A confinement kit whose test fails if the model merely refuses.** The model
has five tools (Read, Edit, Write, Glob, Grep), no shell, no network, an
empty environment, and a fenced working directory. One short Python hook,
`lib/guard`, decides every file call: writes only under the realm folder,
never `journal/`, dot-files or instruction files; reads only inside the
realm. It fails closed. After the run, bash compares what changed with what
the guard allowed and reverts anything else. `librarian-boundary-test` tells
a real model to break 26 rules and passes only if each call was made **and
denied**; a model that politely declines is a FAIL, because no lock fired.
`docs/boundaries.md` has the full picture, `SECURITY.md` what is not stopped.

## A night, in 90 seconds

1. Preflight: stop file absent, lock taken, the daily note exists, the
   librarian is logged in, no Claude Code config synced into the vault.
2. `git add -A; commit "you: DATE"; push`.
3. Per realm: extract `To file` material, last night's PR comments, files you
   touched; render `prompts/file.md`; run the model in the worktree; verify;
   commit.
4. One PR; `To file` cleared; `## Filed` written; merge; `git pull --ff-only`
   into the vault. That pull is the only way the vault's files change.
5. Optional tidy PR; prune old run artifacts; healthchecks ping.

`docs/architecture.md` walks through it with a sequence diagram.

## Requirements

- Linux with systemd, root for the installer, a dedicated `librarian` user
  (the installer creates it).
- A Claude Code login for that user (a personal subscription works; a
  Team token can carry the work realm).
- A private GitHub repo for the vault and a fine-grained token with
  Contents and Pull requests write access on it.
- A vault directory that reaches the server by any means: a sync tool, a
  mount, or the server being where you edit. The vault and its worktrees
  must live outside `/home`, `/var` and `/tmp` (the model is denied those).
- Sync, backup and monitoring are yours to bring; the librarian takes a
  healthchecks.io URL and an optional stop file.

`INSTALL.md` is the walk-through. `docs/daily-note.md` is the contract for
the note layout, `docs/vault-structure.md` the folder layout.

## Using only the kit

`lib/settings.sh` and `lib/guard` need nothing else here. `make_settings
REALM_DIR OUT` writes a per-run Claude Code settings file (static deny list,
the guard as a PreToolUse hook); `claude_confined PROMPT SETTINGS OUT_PREFIX
MAX_TURNS REALM_DIR` runs one `claude -p` with `--restricted
--strict-mcp-config --permission-prompts none`, five tools, `env -i`, the
prompt on stdin, and writes the model's text, denials (`[guard]` or
`[rule]`) and allowed writes next to `OUT_PREFIX`. The guard reads
`LIBRARIAN_VAULT` and `LIBRARIAN_REALM_DIR` from the environment
`claude_confined` sets. `bin/librarian-boundary-test` shows how to prove
the boundary for your own layout.

## Layout

| Path | What |
|---|---|
| `install.sh` | root installer: user, packages, config prompts, `/usr/local`, systemd |
| `bin/` | `librarian-nightly`, `librarian-newday`, `librarian-vault-init`, `librarian-boundary-test`, `dailynote.py` |
| `lib/` | `guard`, `settings.sh`: the kit |
| `prompts/` | `file.md`, `tidy.md` |
| `vault/` | rule files, indexes, template, lessons stub, gitignore installed into the vault |
| `docs/` | architecture, boundaries, daily note, operations, vault structure |
| `examples/` | a night's inputs and outputs, from the offline simulator |

`CLAUDE.md` is for an agent working on this repo. MIT license.
