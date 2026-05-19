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
