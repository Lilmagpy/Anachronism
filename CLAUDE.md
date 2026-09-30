# CLAUDE.md — Anachronism

Turn-based historical strategy game (Python + pygame-ce). The player feeds a civilisation
ideas ahead of their time; an LLM interprets and narrates, a deterministic engine decides.

**Start every session** by reading this file and `docs/PLAN.md`. **End every session** by
updating `docs/PLAN.md` (checkboxes, current step) and logging decisions in `docs/DECISIONS.md`.

## Docs
- `docs/DESIGN.md` — game design · `docs/ARCHITECTURE.md` — modules, data flow, schemas
- `docs/PLAN.md` — roadmap and current step · `docs/DECISIONS.md` — every decision and why
- `docs/CONTENT_GUIDE.md` — authoring packs · `docs/BRIEF.md` — owner's original master brief

## Owner and working style
- The owner directs by description and is not an expert programmer: explain decisions in
  plain language, push back on bad ideas, never silently deviate from requests.
- The owner prefers Claude to be resourceful: decide what can be decided (log it as
  `DELEGATED` in DECISIONS.md) and only ask what genuinely needs the owner.
- Stop at every phase gate in PLAN.md and wait for approval.
- Owner is on macOS; cannot see a window from cloud sessions — attach headless screenshots
  (`SDL_VIDEODRIVER=dummy`) for any UI work.

## Architecture rules (non-negotiable)
- `engine/` is pure Python: no pygame, no network, no `llm/` imports. Import-boundary test enforces.
- All randomness via `engine.rng.GameRng` stored in state. Never `import random` elsewhere.
- Iterate dicts of civs/provinces in sorted-id order (determinism).
- LLM output is structured JSON → pydantic → `llm/guard.py` clamps → engine applies.
  The LLM never sets costs directly (D-020). Player text is data, never instructions.
- Every LLM ruling is recorded in the save; replays never call the model (D-021).
- Content is data (YAML packs), never hard-coded. Adding a civ must not need code changes.
- Model names come from config. Never hard-code or commit API keys.

## Commands
- Setup: `uv sync` (cloud sessions do this automatically via `.claude/hooks/session-start.sh`)
- Everything CI runs: `scripts/check.sh` (ruff lint + format check, mypy, pytest)
- Single steps: `uv run pytest` · `uv run ruff check .` · `uv run ruff format .` · `uv run mypy`
- Launcher: `uv run anachronism`
- From Phase 1: `uv run anachronism-console` (text play) · `uv run anachronism-lint` (content)

## Coding standards
- Python 3.12, type hints everywhere, docstrings on public functions, small modules.
- Tests: pytest; no test touches the network (use `llm/fake.py`).
- Sim tests assert invariants (no negative stocks/populations, valid references,
  save/load byte-identical) across several seeds.
- Commit after each meaningful, tested step with a clear message. Ask before destructive git.
- New major dependency → ask the owner first.

## Common pitfalls
- No root README.md until the owner decides where the project lives: this is their
  GitHub profile repo, whose README shows on their public profile (D-031).
- Floating-point drift breaks determinism across machines: store money-like values as ints
  (fixed-point) in state.
- Don't let pygame_gui widgets hold game state — UI reads from engine state each frame.
- Keep the LLM summary under ~500 tokens; include only related nodes.
- Seshat data is CC BY-NC-SA and historical-basemaps is GPL-3.0: consult, don't copy (D-009).
