# Getting started on a Mac

You don't have to run anything to follow the project: Claude attaches screenshots at each
milestone. This page is for when you want to try the game yourself.

The game is now called **Meritus** (it was Anachronism). If you have an older
**Anachronism.app**, you can drag it to the Bin: the new app keeps your saves and settings.

## Playing the 3D game on your Mac (no setup)

Every time new work is pushed, GitHub builds a Mac app automatically.

1. Open the project's **Actions** page on GitHub:
   <https://github.com/Lilmagpy/Anachronism/actions>, click the newest run with a green
   tick, scroll to **Artifacts** and click **Meritus-mac** to download it.
2. Double-click the downloaded file to unzip it; inside is **Meritus-mac.zip** —
   double-click that too. You now have **Meritus.app**. Drag it into **Applications**.
3. **The first time only**, macOS will refuse to open it because it is not from the App
   Store or a registered developer (the app isn't signed with a paid Apple account yet).
   Double-click it once and press **Done** when the warning appears. Then open
   **System Settings → Privacy & Security**, scroll down to the line saying Meritus was
   blocked, and click **Open Anyway** (enter your Mac password if asked).
4. The first launch shows *Starting the game engine…* for about a minute while it downloads
   Python (it needs the internet this once). After that it starts in a few seconds.

How to play: pick a **moment** on the timeline (nine, from Egypt and the Hittites in
1275 BC to Japan's Warring States in 1560), any of its states, and a difficulty (Easy is
gentler on a first game). Where a moment has a chronicle (Rome against Carthage, from
264 BC), choose **Follow history** to live through it chapter by chapter: each turning
point is told as it happened, you choose (history's way, another, or a way only your
ideas make possible), then read what really happened and whether you are ahead of history
or behind it. **Free play** is the open game. A short guided tour
walks you through the screen the first time (Settings can replay it). Then:

- **Map**: drag to move, scroll (or pinch) to zoom, click a province to see who holds it,
  how hard it is to take, and what you can do about its owner. Click your emblem (top
  left) to fly to your capital, where your ideas appear as buildings.
- **War**: every state has armies, drawn on the map in its colours with their strength
  above them. Click one of your provinces to see the armies there: **March…** then click
  the province to march to (they fight any enemy army they meet and besiege enemy cities
  until the walls fall), **Hold**, **Defend** (march on any invader of your land), or
  **Disband**. **Raise a levy here** calls up a small, medium or large levy with the mix of
  soldiers you choose: spears stop horsemen, horsemen ride down archers, archers shred
  infantry, chariots are deadly on plains and useless in hills. Armies cost food and wealth
  every turn and waste away far from home, fastest in deserts and mountains.
- **Battle plans**: each of your armies has a **Battle plan** (hover each choice to see
  what it beats and what beats it); rival armies show their likely plan. Leave it to the
  general, or outwit the enemy yourself.
- **The sea**: click a sea to see who commands it and the fleets on it. Your coastal
  provinces can **Build a fleet**; a fleet can **Sail…** (then click a sea, or a coastal
  province for the sea on its shore) and fights enemy fleets it meets. An army can only
  cross a sea where no stronger enemy fleet holds it, and enemy fleets that command the
  seas around a province blockade it, cutting its trade.
- **Buildings**: click one of your provinces and open **Build** to raise a market,
  granary, temple, school, harbour and more (hover each for its cost and what it does).
  Each needs its ideas, takes a turn or two, and makes that province richer, better fed,
  more learned or calmer. Bigger cities hold more buildings, and you can watch your cities
  spread out and fill with them as they grow.
- **Ideas**: whisper any idea in the box, or **Begin** one from the list ("ahead of their
  time" first). Each costs labour, materials, knowledge and wealth every turn until it
  works; ideas far ahead of their time cost more and make neighbours suspicious. Set a
  project to **Low** priority to make it steady work: it uses only spare hands, so it goes
  slower but can never starve your people. A rich realm can **Hasten** a project once a
  turn, paying from its stores to push the work on; stores far beyond what you use
  slowly waste away, so spend them.
- **Spies**: on the World tab each court shows what is said of its plans, and how reliable
  that is. **Send spies** to learn its true plans, its scholars' work and its armies, and
  perhaps steal one of its secrets; spies may be caught.
- **World**: the paths to victory (by the sword, through trade, by the pen) with what each
  still needs; royal decrees (a festival, mercenaries); and every state you know, with
  envoys, alliances, missionaries, war and peace.
- **End turn** (or Enter) lets ten years pass. Characters pop up to tell you what happened; the
  chronicle at the bottom lists the rest.
- **If your state falls**, it is not the end: a collapse brings a new dynasty to the throne,
  and if conquerors take everything, your people may rise where no garrison holds them and
  restore your state. You lose only when no one remembers it any more.
- **Esc** opens the menu: save, load, the full chronicle, charts, the tech tree and
  settings (sound, music, offline mode).

Your games and the engine live in
`~/Library/Application Support/Godot/app_userdata/Anachronism` (delete that folder to
start completely fresh).

## The text version: one-time setup (about 5 minutes)

1. **Install uv**, the tool that installs Python and the game's libraries for you.
   Open the **Terminal** app (press ⌘ Space, type `Terminal`, press Return), paste this line
   and press Return:

   ```
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

   When it finishes, **quit Terminal (⌘ Q) and open it again** so it notices uv.

2. **Get the code with GitHub Desktop** (free, no typing needed):
   download it from <https://desktop.github.com>, sign in with your GitHub account, then
   choose **File → Clone Repository**, pick **Lilmagpy/Anachronism** and click **Clone**.
   (It is a private repository, so sign in to GitHub Desktop as **Lilmagpy**.)

3. **Run it.** In GitHub Desktop choose **Repository → Open in Terminal**, then type:

   ```
   uv run anachronism
   ```

   The first run downloads Python 3.12 and the libraries (a minute or two), then the text
   version of the game starts:

   ```
   ANACHRONISM (working title) — Test world: Bronze Dawn, seed 123456
   ─── Kingdom of Veyra ── 1200 BC ── turn 1 ───
   People 370,000 →   literacy 3.0% →   unrest 8.0% →   legitimacy 60.0% →
   ...
   >
   ```

## Playing the text version

You guide the Kingdom of Veyra, a river kingdom in 1200 BC with full granaries but no iron.
Type a command and press Return:

- `ideas` — what your scholars could try now, with costs per turn
- `about paper` — everything about one idea (what it needs, what it does)
- `start paper` — begin experimenting; it costs labour, materials, knowledge and wealth
  every turn until it is adopted
- `end` — let ten years pass and see what happened
- `help` — every command; `quit` to leave

Try starting everything at once and watch what happens to your kingdom. Then try a
careful game. `save mygame` and `load mygame` keep your progress in the `saves` folder.
The same `--seed` and the same moves always give the same game:
`uv run anachronism --seed 42`.

## Getting the latest version

In GitHub Desktop click **Fetch origin**, then **Pull origin**, and run `uv run anachronism`
again.

## Trying a phase before approving it

Each finished phase arrives as a *pull request*. To try it before approving: in GitHub Desktop
click **Current Branch → Pull Requests**, pick the phase, and run the game as above. Switch back
to the `main` branch afterwards.

## Running the automated checks (optional)

```
scripts/check.sh
```

This runs the code-style checks, type checks and every test, and ends with
`All checks passed.` The same checks run automatically on GitHub (on a Mac and on Linux)
every time new work is pushed.

## If something goes wrong

- `command not found: uv` — quit and reopen Terminal; if it still happens, repeat step 1.
- Anything else — copy everything Terminal printed into the Claude chat.

## The Anthropic API key (optional: "Free Thought" mode)

Without a key the game plays in offline "Historical Advisors" mode: type any idea in the
box above the Ideas list and your court matches it against the library of ideas.

To let a language model rule on anything you type:
1. Get an API key at https://console.anthropic.com.
2. Pick a model name from https://docs.claude.com (the models overview page).
3. Make a plain text file called `.env` in the game's data folder. On a Mac that is
   `~/Library/Application Support/Godot/app_userdata/Anachronism/` (in Finder: Go → Go to
   Folder…, paste that path). Put these lines in it:
   ```
   ANTHROPIC_API_KEY=your-key-here
   ANACHRONISM_MODEL=the-model-name
   ```
4. Restart the game. The hint under the idea box says "a language model rules".

The `.env` file never leaves your computer: it is git-ignored, and a test fails if that ever
stops being true. A monthly cap (2 million tokens by default, `ANACHRONISM_MONTHLY_TOKENS`)
stops calls once reached; see `.env.example` for every setting.
