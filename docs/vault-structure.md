# Vault structure (v1)

The daily note is the inbox: capture is typing under a heading, the heading is
the realm, filing is a nightly PR read over coffee (`architecture.md`, `daily-note.md`).

```
vault/
├── CLAUDE.md                 global: realm list, shared conventions
├── templates/daily.md
├── daily/YYYY/YYYY-MM-DD.md  one note per day, all realms; the capture surface
├── personal/
│   ├── CLAUDE.md             filing rules (never written by the agent)
│   ├── lessons.md            rules grown from PR feedback (the one instruction-like file it may write)
│   ├── index.md              map of the realm; read first, maintained by the librarian
│   ├── projects/             things with an end; status: active|done
│   ├── areas/                never finish: Health, House, Food… one hub note each
│   ├── trips/                one note per trip: the plan, then the log
│   └── attachments/
└── work/
    └── <co>/                 the employer (WORK_CO in /etc/librarian/env); a previous one can sit beside it as an archive
        ├── CLAUDE.md · lessons.md · index.md
        ├── people/           First Last.md
        ├── meetings/         YYYY-MM-DD Title.md; 1-1s/<Name>/
        └── projects/  areas/ (teams, systems)  reference/ (true regardless of you)  attachments/
```

A realm is self-contained; nothing crosses realms; leaving a job is one `mv`.
Areas vs reference: "still worth keeping if I stopped caring?" → reference.

## Conventions

- Frontmatter on every non-daily note: `type` (matches the folder), `tags: []`,
  `created: YYYY-MM-DD`; `status` on projects. Names: Title Case; people
  `First Last`; dated notes `YYYY-MM-DD <Title>`.
- Links over folders: the librarian links both ways and adds `(from [[YYYY-MM-DD]])`.
  A fact about an existing note is merged into it; a standalone thought becomes
  its own note in the nearest kind folder, linked from the hub note.
- `To file` is the owner's own words (pasting others' text is vouching for it).
  `Happened` is never read.

## Deferred

Until the workflow asks: more capture lanes (each "append under the right
heading"), a `### Clippings` section, PR gating, `journal/` handling beyond
"never written". Playbooks: `operations.md`; priorities: `ROADMAP.md`.
