# Getting started on a Mac

You don't have to run anything to follow the project: Claude attaches screenshots at each
milestone. This page is for when you want to try the game yourself.

## One-time setup (about 5 minutes)

1. **Install uv**, the tool that installs Python and the game's libraries for you.
   Open the **Terminal** app (press ⌘ Space, type `Terminal`, press Return), paste this line
   and press Return:

   ```
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

   When it finishes, **quit Terminal (⌘ Q) and open it again** so it notices uv.

2. **Get the code with GitHub Desktop** (free, no typing needed):
   download it from <https://desktop.github.com>, sign in with your GitHub account, then
   choose **File → Clone Repository**, pick this repository and click **Clone**.

3. **Run it.** In GitHub Desktop choose **Repository → Open in Terminal**, then type:

   ```
   uv run anachronism
   ```

   The first run downloads Python 3.12 and the libraries (a minute or two). You should see:

   ```
   Anachronism 0.0.1
   Python 3.12.x on macOS 26.x (arm64)
   Setup works. There is nothing to play yet: the game engine arrives in Phase 1.
   ```

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

## The Anthropic API key

Not needed yet. From Phase 2 the online "Free Thought" mode needs a key; the game will explain
where to put it. The key file (`.env`) is never uploaded: it is git-ignored, and a test fails
if that ever stops being true.
