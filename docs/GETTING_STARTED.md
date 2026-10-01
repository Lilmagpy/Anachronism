# Getting started on a Mac

You don't have to run anything to follow the project: Claude attaches screenshots at each
milestone. This page is for when you want to try the game yourself.

## Playing the 3D game on your Mac (no setup)

Every time new work is pushed, GitHub builds a Mac app automatically.

1. Open the project's **Actions** page on GitHub:
   <https://github.com/Lilmagpy/Anachronism/actions>, click the newest run with a green
   tick, scroll to **Artifacts** and click **Anachronism-mac** to download it.
2. Double-click the downloaded file to unzip it; inside is **Anachronism-mac.zip** —
   double-click that too. You now have **Anachronism.app**. Drag it into **Applications**.
3. **The first time only**, macOS will refuse to open it because it is not from the App
   Store or a registered developer (the app isn't signed with a paid Apple account yet).
   Double-click it once and press **Done** when the warning appears. Then open
   **System Settings → Privacy & Security**, scroll down to the line saying Anachronism was
   blocked, and click **Open Anyway** (enter your Mac password if asked).
4. The first launch shows *Starting the game engine…* for about a minute while it downloads
   Python (it needs the internet this once). After that it starts in a few seconds.

How to play: pick a **moment** on the timeline (nine, from Egypt and the Hittites in
1275 BC to Japan's Warring States in 1560), any of its states, and a difficulty (Easy is
gentler on a first game). A short guided tour
walks you through the screen the first time (Settings can replay it). Then:

- **Map**: drag to move, scroll (or pinch) to zoom, click a province to see who holds it,
  how hard it is to take, and what you can do about its owner. Click your emblem (top
  left) to fly to your capital, where your ideas appear as buildings.
- **Ideas**: whisper any idea in the box, or **Begin** one from the list ("ahead of their
  time" first). Each costs labour, materials, knowledge and wealth every turn until it
  works; ideas far ahead of their time cost more and make neighbours suspicious.
- **World**: the paths to victory (by the sword, through trade, by the pen) with what each
  still needs; royal decrees (a festival, mercenaries); and every state you know, with
  envoys, alliances, missionaries, war and peace.
- **End turn** (or Enter) lets ten years pass. Characters pop up to tell you what happened; the
  chronicle at the bottom lists the rest.
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
