---
"mattpocock-skills": patch
---

improve-codebase-architecture: merge onto the main flow after grilling, instead of leaving the session dangling (fixes #664).

- New `### 4. Merge onto the main flow` section. When the grilling's frontier is empty and the user confirms the shared understanding, the skill closes out with a handoff packet (chosen candidate, confirmed shape and seam constraints, test strategy, validation path, `CONTEXT.md`/ADR paths, open questions) and names the next command by size: `/implement` in the same window for a single-session deepening, or `/to-spec` → `/to-tickets` → `/implement` per ticket for multi-session work, with the `/handoff` → `/prototype` → `/handoff` detour for questions that need a runnable answer.
- The skill still never edits production code and never files implementation issues; ticket splitting stays with `/to-tickets`.
- `ask-matt`'s Codebase health entry now routes settled candidates in at the size branch instead of back through `/grill-with-docs`, which would re-run an interview the skill already ran internally.
- Re-synced the `improve-codebase-architecture` docs page: the after-you-pick section, the many-candidates answer (the workflow is documented now), It's working if, and Where it fits.
