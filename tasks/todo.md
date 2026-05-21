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
