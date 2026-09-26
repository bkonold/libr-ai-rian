# The daily note: a contract

`daily/YYYY/YYYY-MM-DD.md` is the capture surface and the only note the
wrapper edits. Four headings are parsed by machine; everything else is the
owner's and ignored. `vault/daily.md`, installed as `templates/daily.md`:

```markdown
---
type: daily
date: {{date:YYYY-MM-DD}}
---
## Personal
### Happened
- 
### To file
- 
## Work
### Happened
- 
### To file
- 
## Filed
```

| Heading | Who writes | What the wrapper does |
|---|---|---|
| `## Personal`, `## Work` | template | the realm; `realm_heading` in the nightly maps `personal`→`Personal`, `work`→`Work`; exact match on the stripped line |
| `### To file` (under each) | owner | `extract` at 03:00 → the model's material; then `clear` to `- ` |
| `### Happened` | owner | never read, never written |
| `## Filed` | wrapper | `filed` appends `- **Realm** [PR #N](url)` and `  - [[path|name]]` per note changed, or `- **Realm** nothing to file` |

## dailynote.py: the only program that edits the note (atomic writes)

| Command | Does | Exit |
|---|---|---|
| `extract NOTE H2 H3` | prints the non-blank, non-`-` lines under `### H3` inside `## H2` | 0; **3 if the heading pair is missing** (empty section: 0) |
| `clear NOTE H2 H3 [TEXT]` | replaces that section's body with TEXT (the nightly passes `- `) | 0 |
| `filed NOTE LINE...` | appends LINEs at the end of `## Filed`, creating it if absent | 0 |
| `new TEMPLATE NOTE DATE` | creates NOTE from TEMPLATE, filling `{{date:YYYY-MM-DD}}` (Obsidian's own variable, so a phone-created note is identical); no-op if it exists | 0 |

**Tripwire.** If `extract` exits 3, the nightly prints `WARN: no '### To file'
under '## <Realm>' … (template changed?)`, still runs the realm on feedback and
touched notes, and pings `/fail` at the end: an email, not a week of silence.

## Changing the layout

1. `vault/daily.md` and the live `templates/daily.md` (an owner commit; `librarian-vault-init` installs it only when absent).
2. `bin/librarian-nightly`: `realm_heading` and every `dailynote.py` call
   (`grep -n dailynote.py`: `extract` under `# ---- 1. per realm`, `clear` and
   `filed` under `# ---- 2. the PR`). A new realm also needs `realm_dir`, `REALMS`.
3. `bin/dailynote.py` only if the nesting changes (`##` realm, `###` section).
4. `prompts/file.md` where it says "under the daily note's To file heading";
   `bin/librarian-boundary-test` step 2 only if the note path changes; this
   file and `vault-structure.md`.

Old notes are not migrated; `extract` finds nothing in them. Test in the
offline simulator (`operations.md`): `--dry-run` shows the material, `--no-github`
shows `## Filed`. A new section fits as long as it is never named `To file`.
