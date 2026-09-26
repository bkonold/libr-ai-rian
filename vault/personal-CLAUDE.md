# personal/ filing rules

Kinds in this realm, and what belongs where:

| Folder | Holds | Test |
|---|---|---|
| `projects/` | things with an end (a repair, a build, a side project) | "when is it done?" has an answer |
| `areas/` | ongoing parts of life: Health, House, Food, Fitness, Finances, Relationships, Career… | never finishes; one hub note per area |
| `trips/` | one note per trip: the plan first, the log after | has dates and a place |
| `journal/` | deeper reflection and emotional processing, `YYYY-MM-DD <title>.md` | written by the owner, in their own voice |

Rules:
- One hub note per area, named for the area (`Health.md`, not
  `health-notes.md`). New facts go into the hub note under a dated line
  (`- YYYY-MM-DD: …`) or an existing heading, whichever reads better.
- A project belongs to an area when one fits; link both ways
  (`area: [[House]]` in the project's frontmatter, and a line under the
  area's `## Projects`).
- Reference-style material (a recipe, a how-to, a list you consult) lives
  in the area it serves, as its own note if it is more than a few lines.
- `journal/` is the owner's alone. Never create, edit, move or rename
  anything in it. Read it for context when filing (a journal entry may
  explain why a project or area matters), and link *to* journal entries
  from other notes where that helps, but never the other way round. If
  material in `To file` reads as reflection rather than fact, leave it
  verbatim in the most relevant area or project note under a dated line;
  do not summarize it and do not move it into `journal/`.
- People are not a kind here (that is a work-realm concept). Mention people
  inline; create an `areas/People.md` hub only if the owner asks.

## Lessons

Rules learned from the owner's PR comments live in `lessons.md` next to
this file (appended by the nightly run; this file is never written by it).
