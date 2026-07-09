# Active backlog

Completed designs (Software Metering, Autopilot, MSP switcher, app delete, MAA emails) live in [`tasks/done.md`](done.md). Do not resurrect their unchecked boxes as open work.

**Skipped on purpose (do not re-open without a new request):**
- Session-only Claude API key — operator prefers `localStorage` so the key survives reloads.

---

# Large-tenant hardening (backlog)

## Goal
Keep Hardware, Assignments, Installed, and Overview usable on tenants with thousands of devices/apps — prevent silent hangs and “works in the lab, dies in production” support load.

## Scope
- [x] Document scale behavior in README (Tech → Scale notes)
- [x] Hardware: progress while paging + RAM backfill; progressive table (usable before RAM done); abandon in-flight on refresh/tenant switch; concurrency 25 + token cache
- [x] Graph: default `$top=999` on `graphGetAll`, `mapPool` helper, AbortSignal plumbing
- [x] Installed: slim `$select` + progress while paging apps
- [x] Failed error-cluster: mapPool concurrency 8
- [ ] Explicit **Cancel** button UI on long walks (Assignments multi-endpoint, Hardware RAM)
- [ ] Assignments: per-endpoint progress + optional cancel
- [ ] Optional “slim mode” toggles (e.g. skip Hardware RAM fan-out entirely)
- [ ] Session cache notes in-app (what is cached vs always re-fetched)

## Out of scope for this card
- Backend aggregation / Log Analytics
- Cross-tenant comparison views

---

# Posture sub-tab (new)

## Goal
One-page MSP customer-review of compliance + Conditional Access *posture* — the unsafe defaults and assignment-target patterns auditors flag. Closes the gap that today an MSP has to open three admin-center blades and squint.

## Scope decisions
- Dedicated sub-tab named "Posture" (user-confirmed), positioned after Assignments.
- Two sections in one tab: **Compliance** (always-on, uses existing scopes) and **Conditional Access** (gated on optional new scope `Policy.Read.All`).
- `Policy.Read.All` is optional / graceful degrade (user-confirmed). If denied, the CA section shows an empty state "Grant Policy.Read.All to audit CA posture" and the Compliance section still works.
- Bumps canonical Intune sub-tab count from **20 → 21** when shipped (README lists twenty today).

## Tiles
**Compliance section** (always-on):
- **Unsafe default**: tenant has `secureByDefault: false` (i.e. "no policy = compliant")
- **No grace period**: compliance policies with `scheduledActionsForRule.gracePeriodHours = 0`
- **Device-targeted**: count of compliance policies assigned to device groups instead of user groups
- **No platform split**: count of tenants/policies relying on a single cross-platform policy

**Conditional Access section** (requires `Policy.Read.All`):
- **Report-only stale**: CA policies in `enabledForReportingButNotEnforced` state with `modifiedDateTime` > 30 days
- **Compliant-device gap**: number of CA policies that don't require `compliantDevice` or `domainJoinedDevice` in `grantControls.builtInControls`
- **Legacy auth not blocked**: no CA policy blocking `exchangeActiveSync` + `other` client app types

Each tile clickable → drill-in panel listing the offending items with deep-links.

## Tasks
- [ ] Add `Policy.Read.All` to `SCOPES` as **optional** — request via `acquireTokenSilent` and tolerate denial
- [ ] Helper `hasPolicyReadAll()` checks the active account's granted scopes
- [ ] HTML: `<button class="subtab" data-subtab="posture">Posture</button>` after Assignments
- [ ] HTML: `intuneSubPosture` with two `<section>`s, each with its own tiles row and drill-in panel
- [ ] Sub-tab show/hide wired; load on first reveal
- [ ] `loadPostureCompliance()` fetches `/deviceManagement/settings` + `/deviceManagement/deviceCompliancePolicies?$expand=assignments` and computes the 4 compliance tiles
- [ ] `loadPostureCa()` (only if `Policy.Read.All` granted) fetches `/identity/conditionalAccess/policies` and computes the 3 CA tiles
- [ ] CA section empty state when scope not granted: "Grant Policy.Read.All to audit CA posture" + a "Grant scope" button that calls `loginPopup` with the extra scope
- [ ] Each tile drills to a `<div class="hygiene-detail">`-style panel listing the offending items with deep-links to the matching admin-center blade
- [ ] `pTileMap` + `syncPostureTileUi()` — toggle + active highlight (pre-publish checklist)
- [ ] CSV export per section
- [ ] README: add "Posture" to the sub-tab list (canonical count 20 → 21), add CA endpoint + Policy.Read.All scope line with the "optional" qualifier, bump scope count
- [ ] Canonical-facts grep
- [ ] **Live verification before commit**: each tile filters/drills correctly; CA section degrades gracefully when scope denied; "Grant scope" button works; deep-links open the right admin-center blade

## Out of scope (v1)
- Remediation actions (changing a setting from inside the dashboard — keep read-only stance)
- Security baseline drift (separate feature; baselines have their own Graph surface)
- Custom audit benchmarks / pluggable rulesets (one fixed set of checks in v1)
- Defender for Cloud Apps / session policies
- Per-customer threshold tuning (grace period > 0d is the only "rule", not configurable in v1)

## Verifiable success
1. Sign in with no `Policy.Read.All` consent → Posture tab loads, Compliance section works, CA section shows the empty state.
2. Click "Grant scope" → MSAL popup, consent → CA section loads.
3. Each tile click → drill-in panel populates with the offending items, each linked to its blade.
4. `unsafe default = false` test tenant → "Unsafe default" tile is 0; flipping it back to default makes the tile light up.
5. README sub-tab count grep returns 21; old "twenty" / "20" sub-tab claims updated.
