# Content Guide

How to author civilisations, scripts, scenarios and tech nodes. **Skeleton** — filled in as
schemas are built (Phase 1 for tech nodes and provinces, Phase 4 for scripts/relations,
Phase 5 for civs and scenarios).

## Principles
- All content is YAML in `src/anachronism/content/packs/<pack>/`, with `schema_version`.
- Run `uv run anachronism-lint` after every change; it must report zero errors.
- Every factual claim in shipped data has a `sources:` entry and a `confidence:` tier
  (`high` / `medium` / `low`). These are never shown to players.
- LLM-drafted content goes to `drafts/` and moves into `packs/` only after owner review.
  Model memory is never the sole source for a shipped fact (D-009 covers licences).
- Contested facts: pick the most defensible version, note alternatives in `sources`.

## Sections to come
1. Tech nodes (requirements, effects, complexity, era)
2. Provinces and map resources
3. Civilisations/polities and lineage links
4. Rulers and dispositions
5. Scripts (intentions, preconditions, triggers, dependencies)
6. Relations and memory
7. Timeline layers and scenarios
8. Offline library entries
