# Install

On the server, as a user with sudo. About fifteen minutes, one model call.

## 1. Run the installer

```bash
git clone https://github.com/bkonold/libr-ai-rian git clone https://github.com/<you>/librarian && cd librariangit clone https://github.com/<you>/librarian && cd librarian cd libr-ai-rian
sudo bash ./install.sh
```

It creates the `librarian` user, installs git, gh, python3 and curl, and asks
once for:

| Prompt | Notes |
|---|---|
| Vault directory | absolute; not under `/home`, `/var` or `/tmp`; created if missing, owned by `librarian` |
| Work realm folder name | `work/<this>/`, e.g. `acme` |
| Your name and email | author of the nightly `you: DATE` commits |
| GitHub repo slug | `owner/name`, a private repo you created empty; Enter to skip GitHub for now |
| healthchecks.io URL | optional; `/start`, success and `/fail` pings |
| Stop file | optional path; the nightly refuses to run while it exists (a backup tripwire, a manual pause) |
| GitHub token | fine-grained, Contents + Pull requests read/write on that repo; not echoed |
| Work token | from `claude setup-token` on a Team/Enterprise account; Enter to run work on the personal login |

Config lands in `/etc/librarian/env` (root-owned, readable by `librarian`),
secrets in `/etc/librarian/*-token`. The installer never sources the config
as root; it parses it as data. Re-running it is safe: it deploys the current
code, re-pins the Claude Code binary, and prompts only for what is missing.

The vault is laid out by `librarian-vault-init` if `personal/CLAUDE.md` is
absent: realm folders, rule files, indexes, `templates/daily.md`, a git repo
on `main`. It never moves or overwrites anything, so an existing vault you
arranged like `docs/vault-structure.md` is fine. If the vault is a synced
folder, exclude `.git` from the sync (the installer adds it to a Syncthing
`.stignore` if one exists).

## 2. Log the librarian user in

```bash
sudo -u librarian -H bash -c 'cd && claude'     # prints a URL; approve it in a browser; then /exit
```

## 3. Prove the boundary

```bash
sudo -u librarian -H librarian-boundary-test    # ~3 minutes; must end in PASS
```

One real model call in a throwaway worktree, told to break every rule.
`FAIL` means the boundary does not hold on this machine and version: do not
arm the nightly. The output names the step that failed.

## 4. A first night by hand

Write a line under `### To file` in today's note, then:

```bash
sudo -u librarian -H librarian-nightly --date $(date +%F) --dry-run     # shows the rendered prompt, changes nothing
sudo -u librarian -H librarian-nightly --date $(date +%F)               # the real thing; --no-github to stay local
tail -40 /var/log/librarian/nightly-$(date +%F).log
```

Expect `history point 2: …/pull/1 (merged)` and a `## Filed` section in the note.

## 5. Arm the timer

```bash
sudo systemctl enable --now librarian-nightly.timer
systemctl list-timers 'librarian-*' --no-pager      # newday at 00:05, nightly at 03:00
```

`Persistent=true`: if today's 03:00 already passed, enabling fires a catch-up
run at once. That is harmless.

## Upgrading

```bash
cd libr-ai-rian && git pull && sudo bash ./install.sh     # disarms the nightly timer
sudo -u librarian -H librarian-boundary-test           # PASS, then
sudo systemctl enable --now librarian-nightly.timer
```

Same cycle after `sudo -u librarian -H bash -c 'cd && claude update'`: the
installer re-pins `CLAUDE_BIN` to the new binary. `docs/operations.md` has
the day-to-day commands and playbooks.
