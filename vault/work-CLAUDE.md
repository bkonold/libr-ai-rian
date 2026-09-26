# work/{{WORK_CO}}/ filing rules

Kinds in this realm:

| Folder | Holds | Test |
|---|---|---|
| `people/` | one note per person: `First Last.md`, `Role:` line, `### Personal` / `### Professional` | a name |
| `meetings/` | one note per meeting, `YYYY-MM-DD Title.md`; 1-1s under `meetings/1-1s/<Name>/` | happened at a time with people |
| `projects/` | initiatives with an end; `status: active|done` | "when is it shipped?" has an answer |
| `areas/` | teams, systems, guilds, recurring responsibilities | never finishes |
| `reference/` | true regardless of the owner: acronyms, SQL snippets, tool setups, how-tos | still useful if the owner changed teams |

Rules:
- A person mentioned for the first time gets a `people/` note with what is
  known (role, team, context), linked from wherever they came up.
- Meeting content goes in a meeting note, not a person note; the person
  note gets a link.
- Decisions and status go into the project note under a dated line;
  open questions under `## Open questions` in the project.
- System and team knowledge accumulates in the `areas/` hub for that
  system or team. Snippets and procedures go to `reference/`.

## Lessons

Rules learned from the owner's PR comments live in `lessons.md` next to
this file (appended by the nightly run; this file is never written by it).
