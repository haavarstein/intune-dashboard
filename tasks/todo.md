# Autopilot sub-tab (new)

## Goal
Surface orphaned Autopilot device records and hybrid-join duplicate Entra objects — the cleanup MSPs currently script themselves. New sub-tab "Autopilot", positioned right after Hardware. Bumps canonical sub-tab count from 13 → 14.

## Scope decisions
- Dedicated sub-tab (user-confirmed) rather than extending Hardware. Future-proofs adding deployment-profile assignment / ESP-stuck-state without overloading Hardware.
- No new MSAL scope — `DeviceManagementServiceConfig.Read.All` is needed for `windowsAutopilotDeviceIdentities`. Verify whether the dashboard already has it or needs to add it (likely add). If a customer denies the new scope, the tab shows a single "Grant DeviceManagementServiceConfig.Read.All to audit Autopilot" empty state.
- Hybrid duplicates: include a default-ON "Hide hybrid-by-design duplicates" toggle. Heuristic = same serial → 2+ Entra records where at least one has a hybrid join trust type.

## Tiles
1. **Autopilot devices** (total, in scope) — clickable → show all (`""`)
2. **Orphan**: in Autopilot, no `managedDevice` (after retirement / reimage)
3. **No profile**: Autopilot device with no deployment profile assigned
4. **Duplicate Entra**: same serial → 2+ Entra device objects (subject to hybrid toggle)

## Table columns
Serial, Model, Manufacturer, Group Tag, Purchase Order, Profile (link to Intune blade), Last contact, Status badge (Orphan / No profile / Duplicate / OK). Serial deep-links to the Autopilot device blade in `intune.microsoft.com`. Profile name deep-links to its blade.

## Tasks
- [ ] Add `DeviceManagementServiceConfig.Read.All` to `SCOPES` if not present + visible scope strip
- [ ] HTML: `<button class="subtab" data-subtab="autopilot">Autopilot</button>` after Hardware
- [ ] HTML: `intuneSubAutopilot` container with 4 tiles, state filter dropdown, hybrid-duplicates toggle, search input, Clear KPI / Export / Refresh
- [ ] Sub-tab show/hide wired in the tab switcher; load on first reveal
- [ ] `loadAutopilot()` fetches `/deviceManagement/windowsAutopilotDeviceIdentities` + `/deviceManagement/managedDevices?$select=id,serialNumber,...` + Entra `/devices?$select=...,trustType,physicalIds` in parallel
- [ ] Join on serial number (case-insensitive, trim) → `autopilotRows`
- [ ] `autopilotStateOf(r)` returns orphan / noProfile / duplicate / ok
- [ ] `apTileMap` + `syncAutopilotTileUi()` — toggle behavior + `.tile.active` highlight (pre-publish checklist)
- [ ] Deep-link serial cell + profile cell (pre-publish checklist)
- [ ] CSV export
- [ ] README: add "Autopilot" to the sub-tab list (canonical count 13 → 14), add Autopilot endpoint line, add new scope line if added
- [ ] Canonical-facts grep: confirm "13" → "14", verify no other stale counts
- [ ] **Live verification before commit**: click each tile → table filters; click an active tile → toggles off; serial deep-links open the Autopilot device blade; hybrid toggle changes the Duplicate count

## Out of scope (v1)
- Bulk delete of orphaned Autopilot records (Graph supports `DELETE /windowsAutopilotDeviceIdentities/{id}` but that's a write action — defer until requested)
- Deployment profile assignment status drill-down (separate feature; this tab focuses on reconciliation, not ESP/profile mechanics)
- Reassigning a Group Tag inline
- Surfacing Autopilot ESP failures (a future Autopilot deployment-health feature)

---

# Posture sub-tab (new)

## Goal
One-page MSP customer-review of compliance + Conditional Access *posture* — the unsafe defaults and assignment-target patterns auditors flag. Closes the gap that today an MSP has to open three admin-center blades and squint.

## Scope decisions
- Dedicated sub-tab named "Posture" (user-confirmed), positioned after Assignments.
- Two sections in one tab: **Compliance** (always-on, uses existing scopes) and **Conditional Access** (gated on optional new scope `Policy.Read.All`).
- `Policy.Read.All` is optional / graceful degrade (user-confirmed). If denied, the CA section shows an empty state "Grant Policy.Read.All to audit CA posture" and the Compliance section still works.
- Bumps canonical sub-tab count from 14 → 15 (assuming Autopilot ships first; if these ship in either order, README math has to track).

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
- [ ] README: add "Posture" to the sub-tab list (canonical count → +1), add CA endpoint + Policy.Read.All scope line with the "optional" qualifier, bump scope count
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
5. README sub-tab count grep returns the new number; old "13" mentions all bumped.

---

# Multi-customer / MSP tenant switcher

## Goal
MSP shortcut: configure a list of customers (code + email, optional label) in Settings, then switch between them from a dropdown in the top-right auth bar. No retyping emails. No persisted refresh tokens. Codes (e.g. "DB", "XB") are short on purpose so screenshots don't disclose customer names.

## Storage
- `localStorage['intuneDashboard:customers']` = JSON array of `{ code, label?, email }`
- Codes are 2–3 letters, unique within the list
- No tokens or secrets stored — MSAL continues to use sessionStorage exactly as today

## UX rules
- **0 or 1 customers configured** → behave exactly like today. No dropdown. Standard sign-in flow.
- **2+ customers configured** → tenant dropdown appears in the auth bar showing only the code (so screenshots don't disclose customer names).
- Switching to a customer:
  - If MSAL has a cached account matching the email *in this session* → `setActiveAccount` + reset state + switch to Overview. Silent.
  - Otherwise → `loginPopup({ scopes, loginHint: email })` → on success, reset state + switch to Overview.
- After every switch, land on Overview (matches sign-in behaviour).

## Tasks
- [x] `loadCustomers()` / `saveCustomers()` helpers
- [x] Settings → Customers section: list + add form (code/label/email)
- [x] Auth bar dropdown, hidden until `customers.length >= 2`
- [x] Dropdown shows only the active code; menu shows code + email + active highlight
- [x] `resetTenantState()` clears every sub-tab's cache + visual state + PMPC + drift chart
- [x] `switchToCustomer(code)` — `setActiveAccount` if cached, else `loginPopup({ loginHint })`, then reset + Overview
- [x] `renderCustomerSwitcher()` called on sign-in + after add/delete
- [x] README: new "Multi-customer (MSP) workflow" section + top-of-file Settings summary update
- [x] Canonical-facts scan run — sub-tab count, scope count, default tab, endpoint list all unchanged

## Out of scope (v1)
- Persisted accounts across browser sessions (would require `localStorage` MSAL cache → security tradeoff we deliberately avoided)
- Per-customer cached dashboard state (switching always re-fetches)
- Auto-fetch tenant display name via `/v1.0/organization` to suggest a label
- Cross-customer comparison views ("show failed installs across all customers")
- Import/export customer list

## Verifiable success
1. Zero customers configured → dashboard works exactly as before, no UI change.
2. One customer configured → still no dropdown, but Settings shows the list.
3. Two customers configured → dropdown appears in the auth bar.
4. First click on a customer → Microsoft popup, account pre-filled (`loginHint`), one click signs in.
5. Second click on the *same* customer → silent switch (no popup), state resets, lands on Overview.
6. Adding a third customer doesn't disrupt the active session.
7. Deleting the active customer in Settings → entry removed from dropdown but the session continues until sign-out.

## Review

**Net diff**: ~180 lines in `index.html` (HTML for Settings + auth-bar dropdown + JS module), ~25 lines in `README.md`. No new Graph endpoints, no new scopes, no changes to existing sub-tab modules beyond what `resetTenantState()` reads/writes.

**Module-scope correctness**: every variable `resetTenantState()` mutates was verified to be declared with `let` at module scope (no `const`, no function-local shadows). Grep'd before writing the reset function.

**Privacy-by-default**: the always-visible dropdown opener shows only the 2–4 letter code. Labels and emails are revealed only when the menu is open. Matches user's explicit screenshot-safety requirement.

**Security tradeoff (intentionally avoided)**: MSAL still uses `sessionStorage` — no refresh tokens persisted across browser sessions. The only thing in `localStorage` is the `{code, label?, email}` mapping, which carries no auth material. Closing the tab still wipes MSAL state.

**Live verification needed**:
1. No customers configured → no dropdown, single-tenant flow works as before.
2. Add 1 customer in Settings → still no dropdown.
3. Add a 2nd customer → dropdown appears in auth bar.
4. Sign in with one customer's account → that code shows as "active" in the dropdown.
5. Click the other customer in the dropdown → Microsoft popup arrives with `loginHint` pre-filled. Confirm. Dashboard resets, lands on Overview, dropdown active code updates.
6. Click back to the first customer → silent switch (no popup) since MSAL still has its account cached. State resets, Overview reloads.
7. Delete a customer in Settings → row disappears, dropdown updates.

---

# Delete app from Intune (Installed sub-tab)

## Goal
From the Installed sub-tab's selected-app view, allow deleting an app from Intune via Graph `DELETE /deviceAppManagement/mobileApps/{id}`. First write action in the dashboard. Typed-confirmation modal (must type exact app name) gates the delete. After success: picker refreshes, sticky green notice confirms.

## Scope decisions
- Hard delete only (chose "Delete app from Intune" over "Remove assignments only" or "Both").
- Button in installedView header, not per-row in the picker.
- Typed app-name confirmation, not native `confirm()`.

## Tasks
- [x] Add `DeviceManagementApps.ReadWrite.All` to `SCOPES` array (single source of truth)
- [x] Add scope to visible scope strip on the signed-out prompt
- [x] Add `--danger` / `--danger-soft` CSS vars + `.btn-danger` class
- [x] Add `.notice-banner` CSS (green sibling of `.error-banner`)
- [x] Add `🗑 Delete from Intune` button to installedView header (middle of three)
- [x] Add `#intuneNotice` div next to `#intuneError`
- [x] Add `#delModal` modal (mirrors `#detModal` shape)
- [x] Add `graphDelete()` helper (treats 2xx and 404 as success; throws on other non-OK)
- [x] Add `showIntuneNotice()` / `clearIntuneNotice()` helpers
- [x] Add `openDeleteModal()` / `closeDeleteModal()` / `confirmDelete()` functions
- [x] Wire button click + backdrop-click-to-close
- [x] Required justification textarea (gates confirm button alongside typed name); sent base64-encoded as `x-msft-approval-justification` header — required by tenants with multi-admin approval / privileged operations, harmless elsewhere
- [x] Multi-admin approval: on HTTP 412 (request submitted) or HTTP 409 "active Approval Request already exists" (already pending), show a success-style "request submitted, an approver needs to act on it in admin center" panel with the approval code (parsed from the response body since CORS hides the response header). No retry button — the dashboard's job ends at submission; Intune executes the delete itself once an approver approves. **Lesson:** initial implementation added a Retry button that caused the user to re-submit and trip the 409 — over-engineering. Submission is success.

---

# MAA approver email notifications

## Goal
Close Intune's #1 documented MAA pain point — *no notifications when a request lands in the queue*. The dashboard already sees the moment a delete is submitted (the 412/409). Email the configured approver list for that customer the instant we see it, from the requester's mailbox via Graph `POST /v1.0/me/sendMail`. No Logic App, no Power Automate, no 15-30 minute audit-log lag (per the Recast warning).

## Design decisions (user-confirmed via AskUserQuestion)
- **Per-customer approvers** — matches the existing MSP model. Each customer entry gets an optional `approvers` array. Empty = no email sent.
- **Fire-and-forget v1** — no polling for approved/rejected status. Static "submitted" panel.
- **Always-on when approvers configured** — no per-submission opt-out checkbox in the modal.

## Tasks
- [x] Add `Mail.Send` to `SCOPES` array (single source of truth, all 4 call sites reuse)
- [x] Add `Mail.Send` to the visible scope strip on the signed-out prompt
- [x] Extend customer schema with optional `approvers: string[]` (lowercase emails)
- [x] Settings UI: add approvers input row to the add-customer form
- [x] Settings UI: render `📧 N approvers — list…` line under each customer row with click-to-edit inline editor
- [x] `addCustomer()` reads + validates approver emails (same regex as the customer email)
- [x] `parseApprovers()` helper (split, trim, lowercase, drop empties)
- [x] `editApprovers(code)` swaps the line to an inline input + Save/Cancel buttons
- [x] `saveApprovers(code)` validates and persists
- [x] `sendApprovalNotification()` helper next to `graphDelete` — POSTs structured HTML email via `/v1.0/me/sendMail`. Uses direct `fetch` (sendMail returns 202 with empty body; `graphPost` would throw on `.json()`).
- [x] `confirmDelete` 412/409 catch: look up active customer, check `customer.approvers`, await `sendApprovalNotification`, capture sent/failed/none into a `notification` object.
- [x] `renderApprovalSubmitted` takes the notification object and renders one of three lines: green ✓ Notified, amber ⚠ failed, or muted "no approvers configured" hint.
- [x] README: scope list with Mail.Send + two-write-scopes framing, Installed bullet extended, Multi-customer Approvers field documented, sendMail endpoint added.

## Out of scope (v1)
- Polling `/operationApprovalRequests` for approved/rejected status updates (would change the panel from static to live).
- Teams channel webhook as an alternative delivery channel (would need per-customer webhook URL config + Power Automate setup; deprecated incoming-webhook story complicates this).
- Catching deletes performed outside this dashboard (admin-center-direct deletes still produce no notification — out of our reach).
- Editing customer email or label inline (still requires delete + re-add for those fields; only the approvers field gets inline editing in v1).
- Custom email subject/body templating per customer (one fixed template; can revisit if requested).

## Verifiable success
1. Sign in → re-consent popup includes `Mail.Send`. Cancel still leaves read scopes usable, but delete submissions will surface the email-failed warning.
2. Settings → Customers: add a new customer with approver emails. Row shows `📧 N approvers — list…`.
3. Click the approvers line on an existing customer → inline editor → Save → list updates.
4. MAA-enabled tenant: trigger a delete → 412 returns → success panel shows the approval code AND a green `✓ Notified <emails>` line. Approver inbox: structured HTML email arrives within seconds (requester · customer · app · publisher · app ID · approval code · timestamp · justification · admin-center pointer).
5. MAA-enabled tenant without approvers configured for that customer: panel shows the muted "No approvers configured…" hint instead of the green line.
6. sendMail failure (e.g. revoked Mail.Send consent): panel shows amber `⚠ Email notification failed: <reason>. Notify <emails> manually.` — delete request is still submitted server-side regardless.
7. Non-MAA tenant: delete completes immediately (green snackbar). No email goes out (we only notify on 412/409).
8. Per-customer isolation: switch to a second customer with a different approvers list → trigger a delete → only that customer's approvers receive the email.
9. `grep read-only README.md` — three legitimate uses (Detection Rule Inspector, "two write actions" framing line 54, "everything else is read-only" line 150). No false claims.

## Review

**Net diff**: ~120 lines added in `index.html` (parseApprovers/EMAIL_RX helpers, renderCustomersList rewrite with approver line + inline editor, editApprovers/saveApprovers functions, sendApprovalNotification helper with HTML template, confirmDelete hook, renderApprovalSubmitted notification block). ~10 lines in `README.md` (Mail.Send scope bullet, two-write-scopes paragraph, Installed bullet extension, Approvers field bullet, sendMail endpoint line).

**Why this closes the gap**: the dashboard fires the email at the exact moment the request enters the queue. Server-side workarounds (Logic Apps, Power Automate) all watch the Intune audit log, which the Recast post warns lags 15-30 min — by the time those notifications go out, an urgent device-wipe approval may already be 30 min stale. Client-side notification from inside the requesting session is the only zero-lag option.

**Security tradeoff**: `Mail.Send` is a privacy-meaningful delegated scope. We use it only from `confirmDelete` after a 412/409 (never preemptively), and only to recipients explicitly listed in the customer's own approver field. Email is from the requester's mailbox (delegated — Graph won't let us spoof anyone), so the audit trail is on the requester, not a shared service account. Empty approver list = no Graph call at all.

**MSP fit**: per-customer approvers is the natural extension of the existing customer-switcher design. Each customer's governance is independent.

- [x] Clear notice on `← Change app` and on drilling into a new app (not in `loadInstalledApps` — would clobber post-delete banner)
- [x] README: soften "read-only" claim, add new scope bullet + admin-consent note, add Installed delete bullet, add DELETE endpoint line
- [x] README: grep `read-only` to confirm no false claims remain

## Out of scope (v1)
- Bulk delete / multi-select
- Undo (Graph DELETE has no soft-delete for mobileApps)
- Per-customer write-scope toggle (e.g. read-only for customer A, write for customer B)
- "Remove assignments only" action — explicitly chosen out
- Abort controllers for in-flight `loadInstalled()`/`loadInstalledAssignments()` requests after delete

## Verifiable success
1. Sign in → re-consent popup appears for the new write scope. Cancel still leaves the dashboard usable for read scopes; consent → proceed.
2. Drill into a test app on Installed → 🗑 Delete from Intune appears in the header, red.
3. Click 🗑 → modal opens with app name in the red callout. Confirm button disabled.
4. Type wrong name → confirm stays disabled. Type exact name (case-sensitive) → confirm enables.
5. Click Delete permanently → button shows "Deleting…", modal closes, view returns to picker, green banner says "Deleted &lt;name> from Intune.", picker refreshes and the app is gone.
6. Re-open Installed sub-tab → the deleted app is not in the picker even after `↻ Reload apps`.
7. Error case (insufficient permissions / re-revoked consent) → modal stays open with red error banner inside; close button still works; success banner not shown.
8. MSP context: switch tenants via multi-customer dropdown → success notice clears on next picker click; delete works against the new tenant.
9. `grep read-only README.md` returns only accurate claims (Detection Rule Inspector + the "only write action" line).

## Review

**Net diff**: ~80 lines added in `index.html` (CSS vars, button class, notice banner, modal HTML, graphDelete + notice helpers, open/close/confirm functions, button wiring, two clearIntuneNotice calls), ~5 lines in `README.md` (scope bullet + admin-consent paragraph + Installed bullet + endpoint line + softened header text).

**Why this is safe**: the first write action is gated by three layers — explicit MSAL consent on the new scope, the typed-confirmation modal (case-sensitive strict-equality match on `displayName`), and the high-friction red button styling. MSP screenshot-safety preserved because the modal only shows the app name (no tenant code or customer label is exposed).

**Re-consent UX**: existing signed-in users will see a one-time popup the first time `acquireTokenSilent` fails due to the new scope. This is the same pattern as previous scope additions (the README note at line 147 already mentions this behavior).

**404 handling**: treating 404 as success means concurrent deletes from two browser windows don't both error — the second one just succeeds and refreshes.

**In-flight requests**: `loadInstalled()` and `loadInstalledAssignments()` may be in flight when the user clicks delete. After delete they 404 against the deleted app id, but since the view is already swapped to the picker, the errors land on a hidden tab. The success notice is set last, so it's not clobbered.
