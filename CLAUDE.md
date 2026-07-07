# THE Intune Dashboard — Claude Code Instructions

## Repo sync (MANDATORY at session start)

Before any work, verify the local branch is current with `origin/main`:

```
git fetch origin
git status
git log origin/main..HEAD --oneline   # commits we have that origin doesn't
git log HEAD..origin/main --oneline   # commits origin has that we don't
```

If the local branch is **behind** origin, pull before doing anything:

```
git pull origin main
```

If the local branch is **ahead** with unpushed commits that look intentional, push:

```
git push origin main
```

Never start editing on a stale checkout — diverged branches create merge conflicts that waste time.

## Commit & push policy

- Push to `origin/main` automatically after every commit (no confirmation needed).
- Bundle README updates into the same commit as the feature that warrants them.
- Check `gh issue list --repo haavarstein/intune-dashboard --state open` (or the GitHub MCP equivalent) before committing and fix anything actionable in the same change.

## Code style

- No comments unless the WHY is non-obvious.
- No trailing summaries at end of responses — user can read the diff.
- Surgical changes only — don't refactor or add abstractions beyond the task.
- No error handling for impossible scenarios; trust internal guarantees.
- All sub-tab labels must be Title Case.

## Email template

All MAA emails go through `buildMaaEmailHtml()` in `index.html`. It produces a full nested-table HTML document (not a div layout) copied from a real PIM notification so it survives Outlook's Word renderer. Never rewrite it as divs, and never add a second template. Body/table text is 16px Segoe UI; heading 28px Segoe UI Semibold; button is a border-padded anchor inside a black table cell.

## UI design

Use the KPI stoplight CSS classes (`tile-good`, `tile-watch`, `tile-warn`, `tile-bad`) for all status colouring. Small SVG-ring gauge tiles are welcome on sub-tabs that have a meaningful summary rate.

## Example / placeholder data

Any placeholder text, `e.g. …` hints, tooltips, README examples, and test/preview data must use clearly fictional values only:

- Customer codes: `ACME`, `FAB`, `CONTOSO` — never real codes
- Names: `Alex Admin`, `Jane IT` — never real colleague/customer names  
- Emails: `alex@contoso.com`, `admin@fabrikam.com` — never real UPNs
- GUIDs: `11111111-2222-3333-4444-555555555555` pattern — never real tenant/object IDs

Real customer identifiers leaking into UI text or docs is a hard no — the whole customer-code system exists to keep names off screenshots and recordings.

## Files to never commit

- `email/` — may contain exported real emails with tenant data (git-ignored)
- `.claude/` — local Claude Code state (git-ignored)
