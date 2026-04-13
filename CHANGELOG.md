# Changelog

## 2.0.6

- Fixed combat reputation updates that could miss newly encountered factions
  until a manual rescan.
- Unresolved combat reputation messages now fall back to a full scan so new
  factions can be discovered automatically.

## 2.0.5

- Fixed a combat reputation-message taint error caused by WoW protected secret
  strings.
- Improved fallback refresh handling when combat messages cannot expose a safe
  faction name.

## 2.0.4

- Improved reputation progress bars so overall progress and current-rank
  progress are easier to tell apart at a glance.
- Cleaned up layered progress-bar visuals for factions that show more than one
  progress band.

## 2.0.3

- Improved reputation refresh behavior during combat so delayed updates catch
  up more reliably afterward.
- Smoothed out background refresh work to reduce spikes during larger update
  bursts.

## 2.0.2

- Improved follow-up refreshes after quest turn-ins and other reputation
  updates.
- Kept manual scans responsive while background updates do less work at once.

## 2.0.1

- Improved progress tracking across standard reputation, renown, friendship,
  and paragon factions.
- Reduced unnecessary background work in the public release.

## 2.0.0

- Established the first public `Rep Sheet` release.
- Changed the public slash command to `/reps`.
- Restored the faction hierarchy handling for grouped reputations such as
  `The Severed Threads` and `The Cartels of Undermine`.
- Added an in-game addon-list icon and a movable minimap icon.
- Prepared the addon tree for a first public CurseForge release.
