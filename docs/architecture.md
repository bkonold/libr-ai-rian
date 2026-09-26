# How a night runs

`bin/librarian-nightly`, as user `librarian`, from `librarian-nightly.timer`
(03:00 ±5 min, `Persistent=true`), processing yesterday. Anchors below are the
script's section comments (`# ---- 0. sync + you` … `# ---- 3. tidy`) and
function names; `grep -n` for them. Enforcement: `boundaries.md`. Three history
points a night, in order: `you: DATE` (the owner's day, one commit on `main`),
the filing PR `librarian: DATE` (merged immediately), the tidy PR `tidy: DATE`
(optional, left open, expires after two nights).

```mermaid
sequenceDiagram
  participant V as vault ($VAULT_DIR)
  participant W as wrapper (bash)
  participant T as worktree (next to the vault)
  participant M as claude -p (per realm)
  participant G as GitHub
  W->>V: preflight: stop file? lock, note exists, login, no synced config files
  W->>V: git pull --ff-only; git add -A; commit "you: DATE"; push
  W->>G: read owner comments on last night's PR (last-pr)
  W->>T: worktree add -B librarian/DATE from main
  loop each realm
    W->>W: dailynote.py extract "To file"; feedback for this realm; touched files from you-commit
    W->>M: render prompts/file.md; claude -p (5 tools, guard, restricted)
    M->>T: reads CLAUDE.md, realm CLAUDE.md, lessons.md, index.md; writes under realm dir
    W->>T: verify_run (REVERTED / HELD); git add realm dir; commit "librarian(realm): DATE"
  end
  W->>G: push branch; gh pr create "librarian: DATE" (Notes per realm, Files, sync conflicts)
  W->>T: dailynote.py clear "To file"; filed (PR link + wikilinks); commit "librarian: DATE daily note"; push
  W->>G: gh pr merge (retry 6×5 s) unless REVERTED/HELD
  W->>V: git pull --ff-only  (the only way the vault's files change)
  W->>T: tidy: worktree librarian/tidy/DATE; claude -p per touched realm; PR "tidy: DATE" left open
  W->>W: prune runs/ >30 d; healthchecks ping (ok, or /fail if WARNED)
```

## Phases

- **Preflight** (above `# ---- 0.`): `/etc/librarian/env` sourced; `gh()` reads
  the token per call, never exported; output tee'd to `/var/log/librarian/`.
  Exit 0 on the `STOP_FLAG` file if one is configured, a held `flock`, or no daily note. Unless
  `--dry-run`: fail without a Claude login or with `.claude/settings*.json`,
  `.mcp.json` or `CLAUDE.local.md` in the vault (synced settings could carry hooks).
- **0. sync + you**: vault must be on `main`; `git pull --ff-only` (picks up a
  merged tidy PR); `git add -A`; if staged, commit as the owner (`you: DATE`),
  push. `YOU_COMMIT` is that hash or empty. `hc /start`.
- **1. per realm**: owner comments on `last-pr` (`pr_comments`; only the repo
  owner's count) → `runs/DATE/feedback.md`; `worktree_open` branch `librarian/DATE`.
  Per realm into `runs/DATE/<realm>/`: `material.md` (`dailynote.py extract`;
  exit 3 → `WARN`, `WARNED=1`, run continues), `feedback.md` (this realm's dir
  plus general lines), `touched.txt` + `you-diff.patch` (the realm's files in
  the `you:` commit, `journal/` excluded). All three empty → skip. Else `render`
  `prompts/file.md`, `make_settings` (`--dry-run` prints the prompt and stops),
  `run_claude` (a failed run is fatal), `verify_run`, commit `librarian(<realm>): DATE`.
- **2. the PR**: nothing committed → drop the worktree, `clear` To file and add
  `- **<Realm>** nothing to file` on `main`. Else push; `pr-body.md` =
  REVERTED/HELD banners, per realm the model's `## Notes` via `section_after`
  (or `- nothing to note`), diffstat, `*.sync-conflict-*` files, log path;
  `gh pr create`. Per realm `clear` To file, then `filed` with
  `- **<Realm>** [PR #N](url)` and `  - [[path|name]]` per `.md` in
  `git diff --name-only main` (minus `index.md`/`lessons.md`), or `nothing to
  file`; commit `librarian: DATE daily note`, push, save `last-pr`, `worktree_close`.
  Unless REVERTED/HELD (PR left open, `/fail`): `gh pr merge` retried six times
  five seconds apart (GitHub recomputes mergeability after a push), delete the
  branch, `git pull --ff-only origin main` in the vault: **the only way the
  vault's files change**. `--no-github`: a local `git merge --ff-only` instead.
- **3. tidy** (`--no-tidy` skips): an open tidy PR (`tidy-pr`) under two days
  old → skip; older → closed with a comment. Else worktree `librarian/tidy/DATE`;
  per realm with touched files `render` `prompts/tidy.md` (`DIFF` = first 60 kB
  of `you-diff.patch`), run, `verify_run`, commit; PR `tidy: DATE` with
  `## Proposed` per realm, left open.
- **End**: prune `runs/` older than 30 days (note text); healthchecks ok, or `/fail` if `WARNED`.
- **Reruns**: a realm's model runs only if material, feedback or touched files
  are non-empty. Filing resets To file to `- `, so rerunning a date with no new
  comments skips both realms and adds a second `nothing to file` line under
  `## Filed`; after the owner commented, it runs on the comments alone and
  opens a new PR. No loop.

## verify_run

Every changed path in `git status` after a model run is sorted against the
guard's log of allowed writes: logged and under the realm dir (not `journal/`,
a dot-path, `CLAUDE.md`/`CLAUDE.local.md`/`AGENTS.md`) → ok; anything else, an
unlogged change, or a `.git` inside the realm → reverted; a deletion under the
realm dir → restored. Either sets **REVERTED**: should be impossible (the guard
denies it), so run the boundary test. Added lines of ok paths are grepped for
remote embeds (`![](http…)`, `<img>`, `<iframe>`, `<script>`, …); a hit sets
**HELD**: kept for the owner to look at. Both leave the PR unmerged, `/fail`.

## Files on the server

| Path | Owner:mode | What |
|---|---|---|
| `/etc/librarian/env` | root:librarian 640 | `KEY='value'` lines (`VAULT_DIR`, `WORK_CO`, `YOU_NAME`, `YOU_EMAIL`, `GITHUB_REPO`, `HC_URL`, `STOP_FLAG`, `CLAUDE_BIN`); the installer parses it as data, the wrapper sources it |
| `/etc/librarian/github-token`, `git-credentials` | librarian 600 | fine-grained PAT (Contents + Pull requests), read per `gh` call; same token in git's store format |
| `/etc/librarian/work-token` | librarian 600 | Team token from `claude setup-token`; empty = asked and skipped |
| `/var/lib/librarian/{lock,last-pr,tidy-pr,runs/DATE/}`, `/var/log/librarian/nightly-DATE.log` | librarian (750 for runs, logs) | `flock` target; PR numbers the next night reads comments from / checks the age of; run artifacts (`feedback.md`, `pr-body.md`, `tidy-pr-body.md`; per realm `material.md feedback.md touched.txt you-diff.patch prompt.md settings.json output.{md,json,denials,writes,guard,err} tidy-*`); the log is everything the run printed |
| `<vault's parent>/librarian/worktree`, `boundary-worktree` | librarian | exist only during a run / the boundary test |
| `STOP_FLAG` (optional) | anyone but librarian | e.g. a backup tripwire; the nightly refuses to run while it exists |
| `/home/librarian/.claude/.credentials.json` | librarian | the personal Claude login |
| `/usr/local/bin/librarian-{nightly,newday,boundary-test}`, `/usr/local/lib/librarian/{settings.sh,guard,dailynote.py,prompts/}` | root | deployed copies; `cmp` against the repo |
