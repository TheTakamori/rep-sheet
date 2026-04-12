# Rep Sheet

`Rep Sheet` is a World of Warcraft addon for browsing reputation progress
across your characters in one place. It helps answer a simple question:
which character has the reputation you need right now?

## Features

- Shows the best progress for each faction in a single list.
- Compares all known characters for a selected faction.
- Handles warband reputations and per-character reputations.
- Preserves faction hierarchy where Blizzard exposes real parent-child data.
- Adds a movable minimap icon for quick access.
- Shows version information directly in the main window.

## Slash Commands

- `/reps`: Toggle the main window.
- `/reps scan`: Run a manual scan for the current character.

## Installing

1. Close World of Warcraft.
2. Extract the `RepSheet` folder into
   `_retail_/Interface/AddOns/`.
3. Start the game and enable `Rep Sheet` from the addon list if needed.

## Updating From Alt Rep Tracker

`Rep Sheet` is a renamed release of the addon previously developed as
`AltRepTracker`. This public rename starts with a fresh saved-variable name,
so prior local test data from `AltRepTracker` does not carry over
automatically.

## Notes

- A character must log in with the addon installed before that character can
  appear in comparisons.
- Public release builds do not expose the local developer debug entry points
  that are available in the source install.

## License

This project is released as `All Rights Reserved`.

## Project Metadata

The source metadata and release notes in this tree are current through
`2.0.3`.

The following public listing assets still need final values when the
CurseForge project page is refreshed:

- Project page links for source, issues, and support
- Project logo and screenshots
