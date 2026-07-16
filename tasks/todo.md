# Active backlog

Completed designs (Software Metering, Autopilot, MSP switcher, app delete, MAA emails, large-tenant hardening, **Posture**) live in [`tasks/done.md`](done.md) or are marked shipped below. Do not resurrect their unchecked boxes as open work.

**Skipped on purpose (do not re-open without a new request):**
- Session-only Claude API key — operator prefers `localStorage` so the key survives reloads.

---

# Shipped (do not re-open)

- [x] Large-tenant hardening (Cancel, Assignments progress, slim Hardware, cache notes)
- [x] **Posture** sub-tab (Compliance + optional CA via `Policy.Read.All`) — 20 → **21** sub-tabs

---

# Next candidates (from X / community — not started)

Prioritized for Graph-only, MSP review value. Product signals from @MSIntune + community (2026): patch/Autopatch, Secure Boot certs, EPM/Suite→E3/E5, app inventory migration, least-privilege.

## Secure Boot readiness (new)

### Goal
Device-level Secure Boot certificate / trust readiness for the 2026 cert-rollover fire drill — KPI tiles + drill-down that the native report is easy to miss in multi-tenant MSP work.

### Scope (draft)
- [ ] Sub-tab or Hardware/Overview extension: Secure Boot status from Graph / Autopatch reports if available
- [ ] Tiles: ready / at risk / unknown · CSV export · deep-links
- [ ] Document licensing / report API prerequisites

### Out of scope
- Pushing cert updates from the dashboard (remediation stays out of band)

---

## Windows Update / Autopatch posture (new)

### Goal
Fleet update health: rings/profiles coverage, not-just-assignment index — rides Microsoft’s patch-pace messaging.

### Scope (draft)
- [ ] Reuse update profiles already fetched in Assignments where possible
- [ ] Tiles: devices not in any feature/quality profile · stale check-in vs quality freeze · hotpatch coverage if Graph exposes it
- [ ] Per-profile device counts if report APIs allow without Log Analytics

### Out of scope
- Authoring Autopatch policies; Windows 365 DR stories

---

## EPM / elevation inventory (new)

### Goal
“Who can elevate what” after Suite capabilities land in M365 E3/E5 — elevation policy inventory + optional elevation report if Graph exposes it.

### Scope (draft)
- [ ] List Endpoint Privilege Management policies / rules (Graph paths TBD per tenant licensing)
- [ ] Tiles: elevation rules count · shared-device elevation · unassigned EPM policies
- [ ] Graceful empty state when EPM not licensed

### Out of scope
- Building elevation rules; full BeyondTrust-style PAM

---

## Discovered / enhanced app inventory (new)

### Goal
Side-by-side or bridge view while Microsoft migrates “App inventory” vs classic discovered apps — community still runs two dashboards.

### Scope (draft)
- [ ] Graph inventory / discovered apps endpoints (verify current beta surface)
- [ ] Compare to Installed / App versions / metering catalogs
- [ ] Flag apps only in one source

---

## Smaller extensions (backlog)

- [ ] Defender AV exclusion / local-merge drift (PR script or hunting) — security MVP classic
- [ ] VS Code / IDE extension fleet scan — extend `ai-agent-detect.ps1` beyond AI agents
- [ ] LAPS coverage (policy assigned + password age if Graph allows)
- [ ] Primary user / shared-device hygiene deepen (Hardware already has no-primary-user tile)

---

# Posture sub-tab (shipped design reference)

## Goal
One-page MSP customer-review of compliance + Conditional Access *posture*.

## Tasks
- [x] Optional `Policy.Read.All` via Grant / `ensureScopeToken` (not in static SCOPES)
- [x] `hasPolicyReadAll()` + CA empty state
- [x] HTML sub-tab after Assignments; Compliance + CA sections
- [x] `loadPostureCompliance()` / `loadPostureCa()` + tiles + drill-in + CSV
- [x] README / FEATURES 20 → 21; optional scope docs

## Out of scope (v1) — still open if revisited
- Remediation actions from the tab
- Security baseline drift
- Custom audit benchmarks
- Defender for Cloud Apps / session policies
- Per-customer threshold tuning
