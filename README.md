# Zen Word Puzzle

A relaxing word-connect puzzle game for mobile, built with **Godot 4.3**, in the style of
*Zen Word*. Swipe across the letters on the wheel to spell words and fill the board. There
are **3,000 handcrafted-by-algorithm levels**, a new **daily puzzle** every day, and
150 themed chapters with their own scenery.

## Features

- **3,000 levels** with a smooth difficulty curve (3-letter wheels with 2 words at the start,
  up to 8-letter wheels with 20+ words at the end). After level 3,000 the late-game
  levels keep cycling, so the game never ends.
- **Letter wheel**: drag across letters, drag back to undo, pentatonic notes rise with every
  letter you add. Shuffle button to see the letters in a new order.
- **Bonus words**: valid words that aren't on the board go into the bonus jar. Every 10
  bonus words gives 25 coins.
- **Hints** (paid with coins):
  - Light bulb (25): reveals the next letter of the shortest unsolved word.
  - Spotlight (50): tap any empty tile to reveal it.
  - Lightning (90): reveals 5 random letters.
- **Combos**: find words quickly in a row for "Great!", "Excellent!", "Amazing!"...
- **Rewards**: coins for every level, a no-hint bonus, a big chapter-complete bonus, a 7-day
  login reward calendar and a daily puzzle with a streak counter.
- **150 chapters / 10 landscapes** (dawn, lake, forest, sunset, snowy peaks, desert, night,
  aurora, sakura, autumn). Each one is painted procedurally with its own mountains, trees,
  sun or moon, clouds and particles (snow, petals, fireflies, leaves). Each theme has its
  own tile color.
- **Ranks** from *Seedling* to *Enlightened* as you progress.
- **Tutorial**: a finger shows how to swipe on level 1, and tips introduce hints and bonus
  words.
- Ambient music loop and sound effects, plus vibration on supported phones (all can be
  turned off in Settings).
- Progress is saved automatically, including a level you're halfway through.

## Running the game

1. Install [Godot 4.3](https://godotengine.org/download) (the standard build; C# is not needed).
2. Open Godot, click **Import**, and select `project.godot` in this folder.
3. Press **F5** (Run Project). The desktop window is portrait (450×800) to look like a phone.
   Use the mouse to drag across the letters.

## Exporting to Android

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. Set up the Android SDK and a debug keystore under **Editor → Editor Settings → Export →
   Android** (see the [Godot Android export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)).
3. **Project → Export…** already has an *Android* preset (portrait, immersive, vibrate
   permission, package `com.zenword.puzzle`). Click **Export Project** to build an APK, or
   use **Remote Debug / one-click deploy** to run it on a phone connected over USB.

An iOS preset is also included (you need a Mac with Xcode and an Apple developer team ID).

## Difficulty curve

| Levels      | Wheel letters | Words per level | Word rarity            |
|-------------|---------------|-----------------|------------------------|
| 1–5         | 3             | 2–3             | very common            |
| 6–40        | 4 (some 5)    | 3–6             | very common            |
| 41–250      | 5–6           | 4–9             | common                 |
| 251–900     | 6–7           | 6–13            | common / everyday      |
| 901–1500    | 7             | 8–15            | wider vocabulary       |
| 1501–2700   | 7–8           | 9–19            | wider vocabulary       |
| 2701–3000   | 7–8           | 11–21           | hardest                |

Within each stage the levels are ordered from easiest to hardest. Each 20-level chapter
starts gently and ends with a bigger "challenge" level that pays a chapter bonus.

## Project layout

```
project.godot              Godot project (portrait 720×1280, canvas_items stretch, GL Compatibility)
scenes/main_menu.tscn      Home screen
scenes/game.tscn           Puzzle screen
scripts/autoload/
  game_state.gd            Save data, coins, settings, daily rewards, level progress
  level_db.gd              Loads data/levels.json
  sfx.gd                   Sound effects and music
scripts/game.gd            Gameplay: word checking, hints, bonus jar, combos, level complete
scripts/main_menu.gd       Menu, daily reward, chapter journey, settings
scripts/themes.gd          The 10 landscape themes and chapter names
scripts/ui/                Letter wheel, word grid, tiles, background painter, buttons
data/levels.json           3,000 levels + 400 daily puzzles
assets/fonts/              Fredoka (SIL Open Font License)
assets/audio/              Synthesized sound effects and music
tools/generate_levels.py   Rebuilds data/levels.json
tools/generate_audio.py    Rebuilds assets/audio/*.wav
tests/                     Dev-only scenes for screenshots and an automated play-through
```

## Regenerating content

```bash
pip install wordfreq numpy
python3 tools/generate_levels.py --levels 3000 --daily 400   # downloads word lists into tools/.cache
python3 tools/generate_audio.py
```

The level generator uses SCOWL (size 35) as the answer vocabulary, ENABLE + SCOWL 50
for bonus words, and `wordfreq` frequencies to choose well-known words and grade
difficulty. Offensive words are filtered out.

To check the game without the editor UI (headless play-through of many levels):

```bash
godot --headless --path . res://tests/stress.tscn
```

## Credits

- Font: [Fredoka](https://github.com/hafontia/Fredoka-One), SIL Open Font License (`assets/fonts/OFL.txt`).
- Word lists: [SCOWL](http://wordlist.aspell.net/) and ENABLE (public domain); frequencies
  from [wordfreq](https://github.com/rspeer/wordfreq).
- All graphics are drawn in code; all audio is synthesized by `tools/generate_audio.py`.
