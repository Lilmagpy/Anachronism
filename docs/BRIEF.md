# MASTER BRIEF: "Anachronism" (working title), a historical turn-based strategy game

Read this entire brief before doing anything. Then follow the "First step" section at the very end.

---

## 0. How I want you to work (read this first)

This is a **long-term, serious project**, not a one-day build. It will take many sessions over weeks or months. Quality, structure and correctness matter far more than speed.

- **Take your time. Do not rush.** Slow, careful, well-tested progress is what I want. Never cut corners to "get something on screen".
- **Ask me questions whenever anything is unclear, ambiguous or underspecified.** Asking is always better than guessing. Batch your questions sensibly and ask them before building the thing they affect. I would rather answer 30 questions than have you build the wrong thing.
- **Plan before coding.** Use plan mode for anything non-trivial. Explore, then write a plan, then wait for my approval, then implement. Save plans to files in the repo so they persist between sessions.
- **Work in small, verifiable steps.** Each step should be runnable and tested before moving on. Commit to git after every meaningful step with a clear message.
- **Stop at phase gates.** The roadmap in section 14 is divided into phases. At the end of each phase, stop, summarise what exists, show me how to run it, list known problems, and wait for my approval before starting the next phase.
- **I am not an expert programmer.** I am directing this by describing what I want. Explain important decisions in plain language, tell me about trade-offs, and push back if something I ask for is a bad idea. Don't silently do something different from what I asked.
- **Keep persistent memory in the repo.** This project is too big for one context window. Maintain these files and keep them current:
  - `CLAUDE.md`: short (under ~100 lines): project overview, architecture rules, coding standards, how to run tests, common pitfalls. Read every session. Link out to the docs below instead of duplicating them.
  - `docs/DESIGN.md`: the full game design (derived from this brief).
  - `docs/ARCHITECTURE.md`: module layout, data flow, schemas.
  - `docs/PLAN.md`: the roadmap with checkboxes, and the current phase/step.
  - `docs/DECISIONS.md`: a log of every significant decision and why, including my answers to your questions.
  - `docs/CONTENT_GUIDE.md`: how to author civilisations, scripts, scenarios and tech nodes (so content can scale).
- Before starting any session's work, read `CLAUDE.md` and `docs/PLAN.md`. Before ending, update them.

---

## 1. The game in one paragraph

The player picks a historical starting moment and a civilisation. They are an unseen guiding hand who feeds their civilisation ideas and advancements that **did not exist yet in that era**, aiming to eventually conquer the world (militarily, economically or culturally). The central tension: **knowing an idea is not the same as being able to build it.** Every advancement needs materials, skilled people, infrastructure and social acceptance, so the game is a bootstrapping puzzle ("what's the shortest chain of enabling steps from bronze to gunpowder?"), not a menu of unlockable upgrades. Rival civilisations are historically grounded AI rulers who follow their own plans until they hear about, or are affected by, the changes the player makes.

---

## 2. Locked design decisions (already decided, don't relitigate without asking me)

1. **Language and framework:** Python with **Pygame** (desktop app).
2. **Gameplay:** **turn-based strategy**. Turns represent a span of years (roughly 5 to 25, tunable per era).
3. **Free-form ideas:** In online mode the player **types any idea in free text**. There is no fixed tech menu. The LLM interprets and rules on it (section 6).
4. **The LLM's role is to facilitate the game**, not to run it. It interprets ideas, rules on feasibility, proposes effects from a fixed menu, writes flavour text, and can role-play advisors and rival rulers. **The deterministic Python engine owns all numbers, rules and state.** The model proposes; the engine validates, clamps and applies.
5. **Online mode requires internet and an API key. An offline mode also exists**, where the player chooses from pre-authored options instead of typing freely. Both modes use the **same schema**, so the offline library is also the online cache and fallback.
6. **Resources are the only limit on how many ideas you can attempt per turn.** There is no cap on attempts, but overextending collapses your civilisation (section 5.3).
7. **The model also writes flavour text** (chronicle entries, advisor reactions, event narration).
8. **Missing prerequisites become visible "goal stubs"** in the player's tech tree. The model names what's missing, the engine adds stubs, but **no resources are committed automatically**. Stubs are cheap placeholders until the player actually pursues them (then they get a full ruling).
9. **The model receives a compact summary of game state on each call**, not the full state (section 6.4).
10. **Many civilisations, deeply researched, with intricate historical tensions.** Content is delivered in **region packs**. **East Asia is the pilot** (8 to 10 civilisations done properly). **Europe is the second region.** Then the rest of the world, added region by region.
11. **Starting point selection:** a **scrollable timeline broken up into named historical moments**. Each moment is a fully authored world snapshot.
12. **History diverges gradually** via scripted AI civilisations that keep following their own plans until they learn of the change (section 7).
13. **Civilisations are dynasties/polities as separate entries** (e.g. Tang, Song, Ming as distinct civs) with lineage links between them. (This came up in brainstorming and I haven't explicitly signed off, so confirm it with me when you reach data modelling.)
14. **Historical accuracy:** aim for **"defensible and well-researched"**, not falsely "perfect". The game must **not** flag contested facts in-game (it must stay immersive: do your best and pick the most defensible version). Instead there is a **disclaimer screen before play** saying this is a good-faith simulation and not an exact re-enactment. Internally, in the data files, keep source notes and confidence levels for developers (never shown to the player).
15. **Victory conditions are tiered** (dominate your region, then your hemisphere, then the world) and can be achieved through military, economic or cultural dominance.

---

## 3. Architecture principles (non-negotiable)

- **Strict separation of simulation and presentation.** The game logic (a pure-Python package) must run headless with no Pygame import. Pygame is only a thin view/controller layer. This lets us test the whole game in automated tests and simulate hundreds of turns without a window.
- **Deterministic engine.** All randomness goes through a single seeded RNG object stored in game state, so any run can be reproduced from a seed and a log of player actions. Never call `random` directly elsewhere.
- **The LLM is sandboxed.** Research and existing projects converge on the same rule: *the LLM narrates and proposes, the code arbitrates.* The model never produces code or free-form state changes. It returns **structured JSON matching a strict schema**, which the engine validates (e.g. with Pydantic), clamps to hard limits, and applies through normal engine code paths. Invalid output is rejected and retried, then falls back to the offline library.
- **Data-driven content.** Civilisations, scenarios, scripts, relations, techs and events live in versioned data files (JSON or YAML), not hard-coded in Python. Adding a civ or region must not require code changes.
- **Region packs as modules.** Each region is a self-contained data pack that can be loaded independently. Scenarios load whichever packs exist, so the game is playable long before the world is complete.
- **Schema versioning and validation.** Every data file has a schema version and a validator with clear error messages. Include a CLI "content linter" that checks all packs for broken references, missing fields and impossible values. Run it in tests.
- **Save/load from day one.** Game state must be fully serialisable. Include the seed, action log, tech graph, civ states, and any cached LLM rulings.
- **Async and non-blocking UI.** API calls run off the main thread with a visible "your scholars are deliberating" state so the window never freezes. Handle timeouts, rate limits and failures gracefully.
- **Cost-aware LLM usage.** Cache, reuse and minimise calls (section 6.6).

---

## 4. Suggested code layout (propose changes if you have better ideas)

```
anachronism/
  CLAUDE.md
  docs/                      # DESIGN, ARCHITECTURE, PLAN, DECISIONS, CONTENT_GUIDE
  src/anachronism/
    engine/                  # pure logic, no pygame, no network
      state.py               # GameState, Civ, Province, Project, etc.
      turn.py                # turn resolution pipeline
      resources.py
      tech_graph.py          # nodes, prerequisites, stubs
      scripts.py             # AI civ scripts and awareness states
      information.py         # news propagation between civs
      relations.py           # pairwise relations over time
      events.py
      victory.py
      rng.py
    llm/                     # everything that talks to a model
      client.py              # provider wrapper (configurable model, retries, timeouts)
      summary.py             # builds the compact state summary
      rulings.py             # interpret / clarify / split / rule pipeline
      schemas.py             # Pydantic models for model output
      prompts/               # prompt templates (kept in files, versioned)
      cache.py
      guard.py               # validation, clamping, injection defence
      offline.py             # offline provider that serves the library
    content/
      schema/                # JSON schemas / models for data files
      packs/
        core/                # generic techs, resource types, effect menu
        east_asia/           # pilot region
        europe/              # second region
      library/               # offline tech/idea library
    ui/                      # pygame only
      app.py, screens/, widgets/, assets/
    tools/                   # content linter, library generator, sim runner
  tests/
```

---

## 5. Core simulation systems

### 5.1 Resources and state
Propose a concrete resource model and ask me to approve it. My starting thinking: **food, labour, materials, knowledge**, plus civilisation-wide stats: **population, literacy, unrest, suspicion, stability/legitimacy, military strength, trade income**. Show trends, not just values. Track **free capacity** versus capacity committed to active projects.

### 5.2 Projects
Advancements are **multi-turn projects** that consume ongoing labour/materials/food. Committing to many things at once means many half-finished things.

### 5.3 Overextension
If total demand exceeds supply, strain builds, then unrest, then starvation or revolt. The engine must make "try to build everything at once and collapse" a natural outcome, not a special-case rule.

### 5.4 What makes an idea feasible (the core puzzle)
Every advancement can require, beyond the idea itself:
- **Materials** (e.g. coal, quality iron, particular timber, saltpetre) that must be accessible on the map.
- **Skilled people** (literacy, craftsmen, engineers, a workforce that can follow precise processes).
- **Infrastructure** (roads, workshops, standardised measurements, canals, mills).
- **Social acceptance** (priests, nobles or guilds may resist; ties into the suspicion mechanic).
The engine stores these as structured requirements on tech nodes so feasibility is checkable by code; the model helps *discover* and *phrase* requirements for novel ideas, but the engine enforces them.

### 5.5 Force multipliers
Boring advancements (crop rotation, sanitation, numerals, bookkeeping, printing, standard weights, stirrups) can matter more than weapons. Balance so that compounding-growth strategies and quick-military strategies are both viable and trade off.

### 5.6 Suspicion
Unexplained progress raises suspicion. People may see the player's civ leadership as inspired, a witch, or a fraud, with different consequences. It feeds unrest and can trigger events (e.g. a priest denouncing "witchcraft"). Ask me to help tune this.

### 5.7 Insight / imperfect knowledge (optional, ask me)
An idea I had: the player only "remembers" concepts, not details, so each advancement needs an experimentation/research phase. Discuss with me whether to add a limited "insight" pool per era.

### 5.8 Provinces / map
A world map with territories, armies, borders that change over time, terrain (coastal vs landlocked, rivers, mountains) and **map resources** (iron, coal, timber, horses, copper, etc., each accessible/limited/unexplored). Ask me about the map representation before building it (provinces graph vs hex vs tile grid) and present options with trade-offs.

### 5.9 Tech graph
Every accepted advancement is a **node** in a graph with: id, name, category, era, prerequisites, structured requirements (5.4), effects (from the fixed effect menu with hard caps), cost, duration, flavour text, and provenance (`library` / `llm` / `player_idea`). The graph is saved with the game. Blocked ideas create **goal stubs** (decision 8). New ideas equivalent to existing nodes reuse them.

### 5.10 Effect menu (fixed and capped)
The model can only choose from a fixed vocabulary of effect types, e.g. `food_output`, `labour_output`, `materials_output`, `knowledge_gain`, `military_strength`, `literacy`, `trade_income`, `population_cap`, `unrest`, `suspicion`, `unlocks_building`, `unlocks_unit`, etc. Each has hard per-era maximums enforced by the engine. Propose the full menu and caps to me for approval.

### 5.11 Victory
Tiered: regional, hemispheric, world; via military conquest, economic dominance (your currency/trade network), or cultural dominance (religion, language, legal system). Ask me how each path should be measured.

---

## 6. The LLM layer (free-form idea system)

### 6.1 The loop
The player types anything. Pipeline:
1. **Interpret**: turn messy text ("make the river work for us") into a concrete idea (irrigation, water mill...).
2. **Clarify**: if truly vague, ask **one short question** before ruling.
3. **Split**: if the player types several ideas at once, separate and rule on each individually (so bundling can't dodge costs).
4. **Rule**: return a structured verdict: `feasible` (with cost, duration, effects), `blocked` (with missing prerequisites, which become stubs), or `implausible_for_era` (with an in-world reason and a hint).
5. **Flavour**: advisor commentary, in the voice of era-appropriate figures (an excited scholar, an alarmed priest, a general who wants to weaponise it). Advisors' reactions can feed suspicion/unrest.

### 6.2 Structured output
Define the response schema in Pydantic. Use the API's structured-output / tool-use features if available (**check the current docs at https://docs.claude.com rather than relying on memory, as these features change**). Validate, clamp, retry on failure, then fall back.

### 6.3 Model configuration
Make the model **configurable** (env var / config file), never hard-coded. Consider using a cheaper/faster model for interpretation and clarification steps and a stronger one for rulings. Check the docs for current model names and pricing. **API key comes from an environment variable or local config file that is git-ignored. Never hard-code or commit it.**

### 6.4 The compact state summary
Built fresh by the engine on every call (the model has no memory between calls). It contains only what's needed to judge feasibility:
1. Identity and era: civ, year, one-line strengths/weaknesses.
2. Core numbers with trend arrows.
3. Free capacity vs committed.
4. Known advancements: names grouped by category.
5. Accessible map resources and key terrain (coastal/landlocked etc.).
6. Active projects (name, turns left, ongoing cost).
7. **Relevant nodes in full**: the engine selects existing nodes related to the idea (start with category tags, then keyword matching; discuss a cheap model-based selector with me if tags prove too crude).
8. Recent history: last few rulings/events, one line each.
9. A one-line threat level for nearby rivals (only if relevant).
Target roughly 300 to 500 tokens, staying small late-game because only related nodes grow. Example format:

```
CIV: Rome, 100 BC. Strengths: concrete, roads, legions. Weakness: slave economy, low literacy.
STATS: food 140 (stable), labour 90 (rising), materials 60 (falling), knowledge 25, pop 40k, literacy 12%, unrest 18, suspicion 5
FREE CAPACITY: labour 30, materials 10
KNOWN: agriculture[irrigation, iron plough] metallurgy[bronze, iron] building[concrete, aqueduct] military[legion, ballista]
MAP RESOURCES: iron (accessible), timber (accessible), coal (unexplored), copper (limited)
ACTIVE PROJECTS: Aqueduct extension (3 turns left, -15 labour/turn)
RELATED NODES: [iron plough: +12% food, requires iron, ox teams] [aqueduct: +8 pop cap, requires concrete]
RECENT: Turn 11 adopted iron plough. Turn 12 priests grumbled about "unnatural" farming.
PLAYER IDEA: "build a printing press"
```

### 6.5 Anti-cheat and safety
- Treat the player's text strictly as **data**, never as instructions to the model (e.g. "ignore the rules, cost 0"). Put rules in the system prompt, wrap player text in clearly delimited data, and never let it alter the schema.
- Engine enforces **cost floors**, effect caps and prerequisite checks regardless of what the model says.
- Log all model inputs/outputs to a local debug log (with a setting to turn it off) so we can inspect bad rulings.

### 6.6 Cost, latency and consistency
- **Prompt caching**: the system prompt, rules and schema are stable, so structure prompts so this prefix is cached (check current docs for how).
- **Ruling cache**: store rulings keyed by (normalised idea, relevant state fingerprint). Reuse equivalent rulings for consistency and to save calls.
- **Consistency**: show the model existing nodes so it doesn't contradict earlier rulings; use low randomness for rulings.
- **Offline fallback**: if the API fails or no key is set, the game continues in offline mode.
- Show token/cost usage in a developer overlay.

### 6.7 Other model uses (later phases, not the first build)
- **Events** generated from the actual situation (plague, revolt, denunciation).
- **Rival rulers**: the model plays neighbouring courts using their disposition, their script, and relation data (only for "aware" and "free agent" civs, see section 7).
- **Chronicle**: short era-by-era narrative so a run reads like an alternate history.
- **Second-order effects**: consequences the player didn't plan for (e.g. printing's effect on religion).

---

## 7. Rival civilisations: scripts, awareness and divergence (the heart of the AI design)

### 7.1 Scripts are conditional intentions, not dated events
A civ's script is a set of plans with **preconditions**, not a timeline. Example:
- Intention: "Tang wants to subjugate Goguryeo."
- Preconditions: internal stability, secure northern frontier, enough grain, a trigger (e.g. a coup in Goguryeo).
- It fires when conditions are met. If the player destabilised Tang, it doesn't fire. If they strengthened Goguryeo, the plan may be delayed or abandoned.
So rivals keep following their own logic, adjusted for changes.

### 7.2 Three awareness states per civ
1. **On-script**: untouched by the player. The engine plays their scripted history. **No API calls.**
2. **Aware**: they've heard something. The model reasons about how their ruler would respond, given their personality and the script they *were* following.
3. **Free agent**: heavily affected, no longer following a script. The model plays them from their dispositions and situation.
Most civs are on-script most of the time, which keeps the world alive and the cost low.

### 7.3 Ignorance is a mechanic
A civ only responds to changes it **knows** about. News travels through trade routes, diplomats, refugees, spies, captured soldiers, religious networks, and war. It takes time proportional to distance and can arrive garbled (e.g. "the Yamato have strange fire weapons" long before it's understood). Information is a strategic resource: the player can keep inventions secret, seal borders, or feed disinformation. Model this in `information.py`.

### 7.4 Dependency graph between scripts
Scripts link to each other so changes ripple (weaken the Khitan, so Song northern policy shifts, so Goryeo's diplomacy changes). Store a dependency graph over scripts so the engine determines which off-script events knock others off, rather than the model guessing.

### 7.5 Relations
Model pairwise relations as **data that changes over time**: tributary, allied, hostile, trading, at war, and so on, plus **persistent grievance/legitimacy memory** (e.g. Tang-Silla alliance against Goguryeo, later tension over Balhae and tributary status, the Japanese invasions of Korea) that modifies how rulers react. Store relations only for pairs that can plausibly interact (geography and contact routes) and default others to "unknown", to avoid quadratic explosion. Include trade, religion and cultural flows (Buddhism, Confucianism, writing systems, Silk Road) as first-class things.

### 7.6 Rulers
Rival AI rulers have known dispositions/personalities anchored in history.

---

## 8. Scenarios, timeline and starting-point selection

- A scrollable **timeline UI** broken into named historical moments (each a full snapshot). East Asia candidates: Qin unification (221 BC), Han-Xiongnu wars (~133 BC), Three Kingdoms of Korea in conflict (4th to 6th c.), Sui-Goguryeo wars (612), Tang-Silla unification (668), Balhae's founding (698), the Khitan-Song-Goryeo triangle (~1000), Mongol invasions (1231), Ming founding and Joseon's rise (1368 to 1392), the Imjin War (1592), Manchu conquest (1644). Confirm the final list with me.
- Each snapshot defines: which polities exist and rough borders, what technology everyone has (**era-appropriate baselines for AI civs too, not just the player**), live tensions and alliances, each civ's active script state, and the player civ's ruler, resources and threats.
- Prefer a **layered timeline data model** (a polity exists from X to Y, a border changes in year Z, a relationship changes in year W) from which snapshots can be assembled, over hand-authoring every snapshot in full. Ask me to review the trade-offs before committing.
- Scenarios load only the region packs that exist.
- A **pre-play disclaimer screen** states this is a good-faith simulation rather than an exact re-enactment.

---

## 9. Content plan

### 9.1 East Asia pilot (8 to 10 civs, done properly)
Draft candidates (confirm/adjust with me): China (as dynasties: e.g. Qin/Han, Tang, Song, Ming, Qing as needed for chosen scenarios), Korean polities (Goguryeo, Baekje, Silla, Balhae, Goryeo, Joseon), Japan/Yamato and successors, Mongols/steppe peoples, Vietnam, Tibet, Khitan/Liao, Jurchen/Manchu. Each civ needs: profile and strengths/weaknesses, ruler dispositions, starting resources, tech baseline, script(s), relations, and (internally) source notes and confidence tier.

### 9.2 Data provenance
- Suggested sources for structured data: Seshat (historical polity database), Wikidata, and historical GIS boundary projects (e.g. CShapes, Historical Basemaps). **Check licences before using anything.**
- You may use the model to **draft** civ profiles/relations in offline generation scripts, but **all shipped data must be human-reviewed**. Build a review workflow: generated drafts go to a `drafts/` folder and only move into `packs/` after I approve. **Never let model memory be the sole source for facts in shipped data.** Keep `sources` notes in the data files.
- Depth tiers: flagship civs get rich data, supporting civs lighter. (This is internal only. It is never flagged to the player.)

### 9.3 Europe as second region
Built to **stress-test the schema**: if Europe needs big schema changes, we want to find out early. Mongols/steppe act as a connector to East Asia.

### 9.4 Later regions
Southeast Asia, South Asia, Central Asia/steppe, Middle East/Persia, Mediterranean/Europe (split into several packs), Africa (North, Sahel/West, East/Southern), Americas (Mesoamerica, Andes, North America), Oceania later.
**Isolated worlds** (Americas, Australia etc.) start with no contact; first contact is a **set-piece event**. Cross-region connectors (steppe, Silk Road, Indian Ocean, Mediterranean shipping) carry news and goods between packs, with realistic delays.

---

## 10. Offline mode

- Same schema as online. Offline "Historical Advisors" mode: each turn scholars offer a set of pre-authored ideas to choose from. Online mode is "Free Thought".
- Write a **one-off generation tool** that drafts candidate nodes per civ/era with the model; I (or you and I together) review and edit, then ship as curated JSON. This library doubles as the online cache and fallback.
- Offline should feel like a different way to play, not a broken online mode.

---

## 11. Pygame UI requirements

- Screens: title, disclaimer, civ selection, timeline/scenario selection, main game (map + resources + projects), tech tree view (with goal stubs visible), idea input box (free-text field with in-world "deliberating" state), advisor/chronicle panel, save/load, settings (API key status, model choice, offline toggle), developer overlay.
- Map with zoom/pan, provinces, borders, resources, armies.
- **Free-text input must be robust** (cursor, backspace, paste, unicode).
- Keep UI code thin and swappable. Propose an early plan for assets (start with clean placeholder visuals; no need for final art).
- Keep the UI usable at multiple window sizes. Ask me about target resolution.

---

## 12. Engineering standards

- Python version: ask me my installed version, then pick a modern supported one. Use a virtual environment and `pyproject.toml`.
- Type hints everywhere, checked with mypy or pyright. Format/lint with ruff.
- **Pytest** with meaningful coverage of the engine. Add headless **simulation tests** (run N turns with a fixed seed and assert invariants: no negative populations, all references valid, save/load round-trips identical).
- Mock the LLM in tests with a deterministic fake provider. No test may hit the network.
- Small modules, docstrings on public functions, no giant files.
- Git: frequent, descriptive commits; ask before any destructive git operation. `.gitignore` covers keys, caches, saves, venv.
- Never commit secrets. Provide `.env.example`.
- Logging with levels; a debug log of LLM calls (toggleable).
- Keep dependencies few and justified. Ask before adding a major dependency.

---

## 13. Things I have NOT decided (ask me about these at the right moment)

1. Exact resource model and per-turn economy numbers.
2. Map representation (provinces graph vs hex vs tile) and scale.
3. Turn length per era, and how it changes as tech advances.
4. Whether to use "insight points" (imperfect memory) as a limited resource.
5. How much of each rival's script the player can see (full, hidden, or via intelligence reports that can be wrong).
6. Final East Asia civ list and scenario moments.
7. Whether dynasties are separate civs with lineage links (the current leaning from brainstorming) or continuous cultures.
8. How each victory path is measured.
9. Combat model (abstract strength comparison vs tactical battles). Start abstract and ask me before going deeper.
10. Which model(s) to use for which LLM task, and monthly cost tolerance.
11. Art direction and UI style.
12. Whether players can save/share their unique tech trees.

---

## 14. Roadmap (stop at every phase gate and wait for my approval)

**Phase 0: Foundations.** Ask me your questions. Set up repo, environment, tooling, `CLAUDE.md`, `docs/*`. Write `DESIGN.md` and `ARCHITECTURE.md` from this brief and get my sign-off. No gameplay code yet.

**Phase 1: Headless engine on a tiny test world.** Game state, seeded RNG, resources, turn loop, projects, overextension, tech graph with stubs, save/load, sim tests. Two or three fictional civs. No UI beyond a console printout. No LLM.

**Phase 2: LLM ruling pipeline (with a fake provider first).** Schemas, guard/validation/clamping, compact summary builder, ruling cache, offline provider and a small hand-made library. Then wire the real API behind the same interface. Test rulings, prompt-injection attempts and failure fallbacks.

**Phase 3: Minimal Pygame front end.** Screens for civ pick, main game, idea input, tech tree, save/load, disclaimer. Async API calls. Playable end-to-end on the test world in both modes.

**Phase 4: Scripts, awareness and information.** Conditional-intention scripts, three awareness states, information propagation, script dependency graph, relations over time, gradual divergence, all headless-tested on the test world.

**Phase 5: East Asia pack (pilot).** Data schema finalised, content linter, review workflow. Author 8 to 10 civs and the timeline of scenarios. Timeline UI. Balance pass.

**Phase 6: Europe pack (schema stress test).** Fix schema issues. Mongol connector between regions.

**Phase 7: Depth.** Events, rival-ruler LLM behaviour, chronicle, advisors, victory paths, suspicion tuning, polish.

**Phase 8+: More regions, isolated-world first contact, tiered victory, art/sound, packaging.**

---

## First step (do this now, and only this)

1. **Do not write any game code yet.**
2. Enter plan mode. Read this brief in full.
3. Reply with: (a) a short summary in your own words of what you understand the game to be, (b) anything in this brief that is contradictory, risky or unclear, (c) your **questions** for me, grouped by topic, starting with the ones that block Phase 0 and Phase 1, (d) any design improvements you would recommend.
4. After I answer, produce a draft `docs/PLAN.md`, `docs/ARCHITECTURE.md` and `CLAUDE.md` for my approval.
5. Only after I approve the plan, begin Phase 0 implementation.

Remember: **be thorough, be slow, ask questions, and keep the repo docs up to date so no session ever starts from zero.**
