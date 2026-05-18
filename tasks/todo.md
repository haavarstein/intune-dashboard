# Helper hints across tabs

## Goal
Make each tab self-describing at a glance. New users (and returning users on rarely-used tabs) immediately know what the tab is for, what data it pulls, and the distinctive feature/constraint.

## Tasks
- [x] Add `.tab-hint` CSS class
- [x] Hints in `viewLocal`, `viewAnalyze`, `viewSettings`
- [x] Hints in all 9 Intune sub-tabs
- [x] Canonical-facts scan: no README changes triggered (sub-tab count, scope count, default sub-tab, endpoints all unchanged)

## Verification
- All 12 hints render at the top of their respective tabs.
- Hint styling consistent everywhere.
- No layout breakage on the tabs that have pickers/tiles immediately below.

## Review

**Net diff**: 1 CSS rule (~11 lines) + 12 one-line hint insertions in `index.html`. Zero behavior changes, zero data-source changes, zero README impact.

**Design**: `.tab-hint` styled as a subtle accent-tinted info box with a 3px left border and 6px right radius. Sits at the top of each tab content area, before any pickers/tiles/tables.

**Hint coverage**: 3 main tabs (Local, Analyze, Settings) + 9 Intune sub-tabs = 12 total. The Intune main tab itself doesn't get a hint — its sub-tabs each carry their own and a wrapper hint would be redundant.

**Skipped**: no dismissal mechanism in v1. If hints become noisy, add a "Hide hints" toggle in Settings later. Per CLAUDE.md "no features beyond what was asked".

**Live verification**: load each tab and confirm the hint renders at the top, doesn't break layout adjacent to pickers/tiles, and reads cleanly.
