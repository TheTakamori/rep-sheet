# Changelog

## 2.0.3

- Deferred non-immediate reputation refresh attempts during combat and collapsed
  them into a single follow-up scan after combat.
- Paused frame-sliced background reputation refresh batches during combat and
  resumed them only after combat ended.

## 2.0.2

- Split delayed known-reputation refreshes into small batches so quest turn-in
  and `UPDATE_FACTION` follow-up scans do less work per frame.
- Kept immediate and manual scans synchronous while moving background refresh
  work onto a frame-sliced path.

## 2.0.1

- Improved reputation progress and snapshot consistency across standard,
  renown, friendship, and paragon factions.
- Reduced unnecessary background debug work in the public build.

## 2.0.0

- Renamed the addon from `Alt Rep Tracker` to `Rep Sheet`.
- Changed the public slash command to `/reps`.
- Restored the faction hierarchy handling for grouped reputations such as
  `The Severed Threads` and `The Cartels of Undermine`.
- Added an in-game addon-list icon and a movable minimap icon.
- Kept local developer debug access in source installs while removing the
  normal-user debug entry points from the public release build.
- Prepared the addon tree for a first public CurseForge release.
