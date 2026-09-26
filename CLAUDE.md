# The librarian: read this first

A nightly job on the owner's server that files what they jotted into their
Obsidian vault. The owner types one-line captures under `### To file` in the
day's daily note; a sync tool carries it to the server; at 03:00 a bash wrapper runs a confined `claude -p` per realm (`personal/`,
`work/<co>/`) in a throwaway git worktree and opens **one pull request** on
the vault's private GitHub repo, merged at once. The owner reads it over
coffee and comments on anything wrong; the next night applies the comments.
Nothing waits on the owner; `git revert` undoes a night.

## Non-negotiables (from the owner)

- **Enforcement is the guard and the fence, never a prompt.** A "must never"
  is a rule in `lib/guard` first and a sentence in a `CLAUDE.md` second.
- **No code for harmless noise.** A warning that breaks nothing gets a sentence
  of explanation, not a fix (e.g. git's "credential storage lock" line).
- **`journal/` is never written by any agent.**
- **The synced vault is never hand-edited by an agent.** The model works in
  a worktree next to the vault; the vault changes only by `git pull --ff-only`
  after a merge. A vault file change is an installer step or an owner commit.
- **The vault and its worktrees live outside `/home`, `/var`, `/tmp`** (the
  static deny rules cover those; `install.sh` refuses such a path).
- **Secrets are pasted into installer prompts only**, never into chat, never
  into a file an agent writes. Config is root-owned in `/etc/librarian/`.
- **Folder names are lowercase**; note names keep their case.
- **The daily-note headings are a contract**: `docs/daily-note.md`.
- **Easy to reason about beats clever.** One PR a night, one guard, a static
  deny list that never grows, bash you can read top to bottom (`set -Eeuo
  pipefail`, short commented functions, `|| true` on a `grep` that may not
  match, Python only for parsing, no new dependencies).

## Map

| Path | What |
|---|---|
| `bin/librarian-nightly` | The night, start to finish. Read it whole once. |
| `bin/librarian-newday` | 00:05: today's note from `templates/daily.md`. |
| `bin/librarian-vault-init` | Lays out an empty vault (realm folders, rule files, git). Skips what exists. |
| `bin/dailynote.py` | The only thing that edits the daily note. |
| `bin/librarian-boundary-test` | A real model told to break 26 rules; PASS = every lock fired. |
| `lib/guard` | PreToolUse hook: THE decision on every file tool call. Fails closed. |
| `lib/settings.sh` | `make_settings` (per-run settings.json), `claude_confined` (the `claude -p` call). |
| `prompts/*.md` | The two prompts; `{{KEY}}` placeholders filled by `render` in the nightly. |
| `vault/`, `install.sh` | Rule files, indexes, template, lessons stub, gitignore; the idempotent root installer that deploys everything. |
| `docs/` | `architecture.md` (a night), `boundaries.md` (enforcement), `daily-note.md` (the contract), `operations.md` (commands, playbooks), `vault-structure.md`. |
| on the server | deployed copies `/usr/local/bin/librarian-*`, `/usr/local/lib/librarian/`; config `/etc/librarian/`; state `/var/lib/librarian/`; logs `/var/log/librarian/`. |

## How to change something

1. Branch; change; `bash -n` every script you touched.
2. Test without a model where you can: the offline simulator in
   `docs/operations.md` with `--no-github`; `--dry-run` prints rendered prompts.
3. Open a PR: what changed, how tested, the deploy step, the session's
   attribution lines at the end. The owner reviews every PR to this repo.
4. The owner merges and runs `git pull && sudo bash ./install.sh` in their
   checkout. Root steps are the owner's: hand them over, then verify (`cmp`
   deployed vs repo, `systemctl list-timers`).
5. If `lib/guard`, `lib/settings.sh` or the pinned Claude binary changed, the
   owner runs `sudo -u librarian -H librarian-boundary-test`; it must end in
   `PASS` before the nightly timer is re-armed (the installer disarms it).
