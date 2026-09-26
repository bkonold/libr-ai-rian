# The boundary

This is the only document that describes enforcement. `CLAUDE.md` files and
the prompts *describe* the limits so the model does not waste turns; they
enforce nothing.

## How it works

The model runs as user `librarian` with five tools: Read, Edit, Write,
Glob, Grep. No shell, no network, no MCP servers, no skills, and an empty
environment, so it cannot run commands, reach other machines, or see the
GitHub token. It never runs inside the vault itself: the vault is a
synced folder, so the wrapper gives the model a git worktree of the
vault's repo next to the vault and the vault's files only change
by a fast-forward pull after the PR has merged. Claude Code's
`--restricted` mode fences every file tool to that worktree. Inside that fence, **one program decides
every file call: `lib/guard`**, a short Python hook that resolves the real
path (symlinks, `..`) and allows writes only under the realm folder (never
`journal/`, dot-files, or instruction files such as `CLAUDE.md`) and reads
only under the realm's top folder plus the root `CLAUDE.md`. It fails
closed: any error is a deny. A short, static deny list in the generated
settings is a backstop for system paths (`/home`, `/etc`, `/proc`, `.git`),
not the boundary. After the run,
the wrapper (bash, no model) compares `git status` with the guard's log of
what it allowed: anything the model wrote where it must not is **reverted**,
deletions are restored, and a remote embed in its text **holds** the PR
open; either way the PR is not merged. `librarian-boundary-test` proves all
of this with a real model told to break each rule. Run it after any change
to the guard, `lib/settings.sh`, or the pinned Claude Code binary.

## The pieces

| Piece | File | Job |
|---|---|---|
| Tool list | `lib/settings.sh` (`CLAUDE_TOOLS`) | The five tools. `--tools` removes everything else; `--allowedTools` lets these run without a prompt (`--permission-prompts none` denies anything that would ask). |
| Worktree | `worktree_open` in `bin/librarian-nightly` | The model works in a checkout next to the vault, never in the synced vault. The vault only fast-forwards after the merge; a held or reverted run never touches it. |
| Fence | `--restricted`, `--strict-mcp-config`, `env -i`, prompt on stdin | Worktree-only file access, no synced settings/MCP/skills, no secrets in the environment, nothing in the process list. One deliberate exception: if `/etc/librarian/work-token` exists, the work realm's runs get it as `CLAUDE_CODE_OAUTH_TOKEN` so work notes run on a work account. The model has no shell and `/proc` is denied, so it cannot read its own environment. |
| Guard | `lib/guard` | THE decision on every Read/Edit/Write/Glob/Grep. Rules are listed at the top of the file. Logs allowed writes and denied calls. |
| Backstop | `make_settings` in `lib/settings.sh` | ~15 static deny rules for system paths. Never grows; the guard handles vault paths. |
| Wrapper check | `verify_run` in `bin/librarian-nightly` | Outcomes `REVERTED` (undone, guard should have caught it) and `HELD` (embed in text, kept for you). Both leave the PR open. |
| Proof | `bin/librarian-boundary-test` | 26 numbered prompt steps, each tied to a check by number; denial lines say which lock fired (`[guard]` or `[rule]`). |
| Pin | `CLAUDE_BIN` in `/etc/librarian/env` | The exact Claude Code binary the runs use; an upgrade is a deliberate re-run of the installer followed by the test. |

Config the wrapper reads lives root-owned in `/etc/librarian/`; the
installer parses it as data and never sources it. The GitHub token is read
by the wrapper per `gh` call and never exported.

## Testing the boundary, not trusting it

```bash
sudo -u librarian -H librarian-boundary-test
```

Expected output ends in `PASS`. Part (a) proves each forbidden call was
attempted **and denied** (a model that politely refuses is a FAIL, because
then no lock was exercised); part (b) proves nothing changed on disk. It
runs in a throwaway worktree, like the nightly, so it is safe on the live
vault.
A `FAIL` means the boundary no longer holds: keep `librarian-nightly.timer`
disabled until it passes.

## Why the model may write `lessons.md` but not `CLAUDE.md`

The vault syncs to the owner's other devices, where other agents
read instruction files. A prompt-injected run writing `CLAUDE.md` would be
writing instructions for an unconfined agent. Rules learned from PR
feedback therefore go in the realm's `lessons.md`, a plain note the
prompts read explicitly.

## Planned: OS-level enforcement

Today the model runs as `librarian`, the user that owns the vault, so the
guard is the only thing between it and `journal/`. The plan (`ROADMAP.md`):
a second unix user, `agent`, runs `claude -p`; POSIX ACLs give it write
only on the current realm's folders, set by the wrapper before each run
and removed after. Then the kernel enforces what the guard enforces today.

What is and is not stopped, as a list: `SECURITY.md`.

## Rules of thumb

- Anything "the model must never do" is a guard rule first and a sentence
  in `CLAUDE.md` second.
- New capability for the model (a tool, a folder) is added deliberately and
  covered by a numbered step in the boundary test.
- The wrapper, never the model, touches the daily note, git, GitHub and
  credentials.
