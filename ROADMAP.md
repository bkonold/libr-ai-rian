# Roadmap

Top is next. Move items to "Done" with the commit that closed them.

## Now

1. **OS-level write boundary**: run the model as a separate `agent` user with
   per-run ACLs on the realm's kind folders; journal/daily/templates never
   writable (see `docs/boundaries.md`). Until then the guard plus
   `verify_run` are the boundary.
2. **Boundary test negative control**: a flag that drops `--restricted` and the
   guard so the out-of-vault probes must FAIL, proving the checks can fail.

## Later

- Weekly realm-wide sweep in the tidy run (index accuracy, orphans, missing
  frontmatter); the diff-driven tidy covers what the owner touched for now.
- Comments on older PRs: the run only reads comments on the *previous*
  night's filing PR. Consider a window of N PRs.
- Tidy PR auto-close on merge conflict with `main` (today: closed only by age).
- `### Clippings` section with create-only handling for pasted third-party text.
- More capture lanes (chat bot, phone shortcut, email-to-self), each an
  "append to today's note" operation; playbook in `docs/operations.md`.
- Deny rules for the non-realm root entries, closing the Edit substring
  oracle described in `SECURITY.md`.
- Realms as a config list instead of the fixed `personal` + `work/<co>` pair.

## Done

- v0.1: one PR a night, `## Filed` as links, guard follows dangling symlinks,
  daily-note heading tripwire, work realm on a work account via `work-token`.
