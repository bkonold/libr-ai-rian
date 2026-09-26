# Operations: commands and playbooks

## Commands (the owner runs them on the server; an agent hands them over)

```bash
# a night by hand (default date: yesterday)
sudo -u librarian -H librarian-nightly --date 2026-01-31 --dry-run     # prompts only, nothing changes
sudo -u librarian -H librarian-nightly --date 2026-01-31 [--no-tidy] [--realm work] [--no-github]
# read what a night did
tail -40 /var/log/librarian/nightly-2026-01-31.log
ls /var/lib/librarian/runs/2026-01-31/work/       # prompt.md output.md output.denials output.writes …
# undo a night: revert the "Merge pull request #N" commit; never git reset a pushed history
sudo -u librarian -H git -C <VAULT_DIR> revert -m 1 <merge-commit> && sudo -u librarian -H git -C <VAULT_DIR> push origin main
# timers
systemctl list-timers 'librarian-*' --no-pager
sudo systemctl disable --now librarian-nightly.timer   # pause
sudo systemctl enable --now librarian-nightly.timer    # arm; Persistent=true fires a catch-up run at once if today's 03:00 passed
# stop file (STOP_FLAG in env, optional): whatever wrote it had a reason; look before removing it
# boundary test (~3 min, ends in PASS or FAIL; FAIL = keep the nightly timer disabled)
sudo -u librarian -H librarian-boundary-test
# deploy (idempotent: re-pins claude, reinstalls /usr/local, rewrites units, prompts only for missing secrets, DISARMS the nightly timer), then verify
cd <clone> && git checkout main && git pull && sudo bash ./install.sh
for f in bin/librarian-nightly bin/librarian-boundary-test bin/librarian-newday bin/librarian-vault-init; do cmp $f /usr/local/bin/$(basename $f) && echo ok $f; done
for f in lib/guard lib/settings.sh bin/dailynote.py; do cmp $f /usr/local/lib/librarian/$(basename $f) && echo ok $f; done
# logins and config
sudo -u librarian -H bash -c 'cd && claude'      # personal Claude login for the librarian user; /exit when done
ls -l /etc/librarian/                            # env, github-token, git-credentials, work-token (never cat a token into a chat)
```

A run ends with `history point 2: …/pull/N (merged)` and `=== … done`; "nothing
to file, no feedback, nothing touched; skipping" is normal. The `fatal: unable to get
credential storage lock` line on every push is harmless (git's store helper cannot lock the root-owned config dir); leave it.

**Feedback.** Comment on the night's PR: a review comment on a file line goes
to that file's realm, a plain PR comment to both; only the repo owner's count.
Applied at the next run (or rerun the date); a stated rule lands in `<realm>/lessons.md`.

**Healthchecks.** `/start` after the `you:` commit, success at the end; `/fail`
on any failure, a PR left open (REVERTED/HELD), or a missing heading (WARN). After
a deploy, re-arm the timer after the boundary test if guard, settings or binary changed.

**Offline simulator** (agents; no model, no GitHub): a scratch dir with
`conf/env` pointing `VAULT_DIR` at a throwaway git repo laid out like the vault,
`CLAUDE_BIN` at a fake `claude` that writes a note under the realm dir and
prints `{"result": "## Notes\n- …", "permission_denials": []}`, copies of `lib/`
and `prompts/`, and `bin/librarian-nightly` with `CONF`, `STOPFLAG`, `LIB`, `STATE`,
`LOGDIR` sed-redirected into it and the login check stubbed. Run with `--no-github`.

## Playbooks

**Capture lane.** A lane appends one line under the right `### To file` in
today's note and nothing else: no other vault writes, no model, no routing
decision (the heading is the realm). Either through the sync tool from a device or
a script on the server as `librarian` appending to `$VAULT/daily/$(date +%Y)/$(date +%F).md`
(add an `append` subcommand to `dailynote.py`). Secrets: `/etc/librarian/`, via the installer.

**Prompt change.** `render` fills `{{REALM_DIR}}`, `{{DATE}}`, `{{FEEDBACK}}`,
`{{MATERIAL}}`, `{{TOUCHED}}` and, for tidy, `{{DIFF}}` (values escaped so material
cannot close a tag). Output contract: filing ends with one `## Notes`, tidy with
one `## Proposed`; `section_after` takes the text after the *last* such heading
for the PR body; `## Filed` links come from git, never from the model. A "Limits"
line saves turns and enforces nothing. Test: `--dry-run`.

**Guard rule.** Add the check in `lib/guard` (every error path ends in `deny`;
keep its docstring's rule list current); a numbered step in
`bin/librarian-boundary-test` with a `check` in part (a) and an on-disk check
in part (b): a model that politely refuses without trying is a FAIL, because
no lock fired; the `case` in `verify_run` if the wrapper should also catch it;
`boundaries.md`. PASS before re-arming. The deny list in `make_settings` never grows.

**Claude upgrade.** `sudo -u librarian -H bash -c 'cd && claude update'`, then
the installer (re-pins `CLAUDE_BIN`, disarms the nightly), the boundary test,
re-arm. The harness depends on `--restricted`, `--strict-mcp-config`, `--permission-prompts
none`, `--tools`, `--allowedTools`, `--settings`, `--output-format json` with
`permission_denials`, and PreToolUse exit 2 = deny.

**Token rotation.** GitHub: `sudo rm /etc/librarian/{github-token,git-credentials}`,
rerun the installer, paste the new token. Work: `sudo rm /etc/librarian/work-token`,
rerun, paste `claude setup-token` output (Enter = none; work runs on the personal login).

**Realm add or rename.** `REALMS`, `realm_heading`, `realm_dir` in the nightly;
a `### To file` under its `## Heading` in the template; a `vault/<realm>-CLAUDE.md`
and index plus the installer's `sub` lines and "lessons files" loop; the boundary
test's other-realm steps. The guard needs nothing. Renaming `WORK_CO`: a folder
move the owner commits, `WORK_CO` in `/etc/librarian/env`, the realm `CLAUDE.md`.

**Don't**: add a tool to `CLAUDE_TOOLS` (Bash and WebFetch are out for good);
put a rule only in a prompt or a vault `CLAUDE.md`; add config keys the installer
does not prompt for; source config as root (the installer parses `env` as data on
purpose); write into the synced vault outside the `you:`/ff-pull path.
