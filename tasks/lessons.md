# Lessons

## README drift on code changes (2026-05-18)

**Pattern**: After making a code change that affects user-facing behavior, I noticed the README would also need updating — and either asked permission ("want me to update the README?") or moved on without doing it. Result: README accumulated multiple inaccuracies over many commits before the user had to call it out.

**Specific drift caused this session**:
- Commit `47b7166` (Installed sub-tab → only assigned apps) — I explicitly flagged the stale README line but asked instead of fixing. Stale.
- Commit `10d0098` (group search switched `startswith` → `$search`) — README still said `startswith` in two places.
- Subtab count "Six sub-tabs" never updated as Drift, Remediation, and Assignments were added (commits `551ac5f`, `06c9fef`, `effd233`).
- "Failed Install — the default view" stayed in README after Installed became default.

**Rule**: When I make a code change, if any of these change, update README.md **in the same commit** — don't ask:
- A sub-tab is added/removed/renamed
- A sub-tab's data source, default sort, default filter, or column set changes
- A Graph endpoint, scope, or auth behavior changes
- A user-visible flow ("first thing you see is X") changes
- A default value or fallback behavior changes

**Pre-commit check**: grep README.md for references to the thing I changed (endpoint name, sub-tab name, scope, etc.). If matches exist and are now wrong, fix them in the same diff. The check is `Grep` — takes 5 seconds.

**Anti-pattern to stop**: writing "README line X is now stale — want me to update it?" That phrasing means I noticed and chose not to. Just fix it.

---

## README drift, part 2: pre-existing staleness (2026-05-18)

**Pattern**: My v1 rule said "grep for what I changed." That catches forward drift but misses *historical* drift — lines that were already wrong before today's commit. After shipping Assignments v2, the README still said "all four sub-tabs share the same session" — a leftover from when there were genuinely 4 sub-tabs. I'd already fixed "Six sub-tabs" → "Nine sub-tabs" elsewhere but missed this near-duplicate.

**Stronger rule**:
- When the user asks "is X up to date?" — verify **all** of X, including parts I didn't touch this session. Run a fresh grep over the whole doc for the canonical facts (sub-tab count, scope count, default sub-tab name, data source labels). Don't trust that earlier fixes were exhaustive.
- When making any README edit, scan ±10 lines around the edit for related stale claims, *and* grep the rest of the doc for the same fact pattern (e.g. if I'm fixing one "Six sub-tabs", grep for `four|five|six|seven|eight|nine` near "sub-tab" in case the count is repeated elsewhere).

**Canonical facts to recheck whenever a feature ships** (this list lives here so I have something to scan against):
- Number of Intune sub-tabs (currently 9): grep `sub-tab` and verify every count or list.
- Number of MSAL scopes (currently 7): grep `scope` and verify the consent + endpoint sections.
- Default Intune sub-tab on sign-in (currently Installed): grep `default` and verify no "Failed Install — the default view" leftover.
- Data source for each sub-tab (Drift = Defender KQL, Installed = mobileApps with assignments, etc.): grep on the endpoint or technology name.
- "What the dashboard calls" endpoint list — match against actual `graphGet`/`graphPost` calls in `index.html`.

**Process**: when user asks "readme up to date?" → run the canonical-facts scan above before answering "yes." When I'm about to claim something is current, that claim is a falsifiable statement and I owe a 30-second check.

---

## Don't invent flow control around API responses I don't understand (2026-05-21)

**Pattern**: When implementing 🗑 Delete from Intune, the first 412 response said "Approval Required. Request Approval using the request ID returned as part of the x-msft-approval-code response header." I read this as "you need to retry with the approval code after approval lands." Built a Retry button that resent DELETE with `x-msft-approval-code`. User clicked Retry → 409 "An active Approval Request already exists for this entity."

**What was actually happening**: the FIRST DELETE with justification *was* the submission. The 412 response means "request enqueued, here's its tracking code." Multi-admin approval is executed by Intune itself once an approver approves it in the admin center — the requester does NOT retry the DELETE. Retrying caused the 409.

**Why I got it wrong**: I read "Request Approval using the request ID" as imperative for the *client*. It's actually descriptive — the request ID is for the approver to reference. The MAA flow in Microsoft's design is fire-and-forget from the requester's side.

**Rule**: When a Microsoft API returns a non-2xx with what looks like "do X to continue," check whether the response is actually a *confirmation of submission* before adding retry/continuation logic. The dashboard's job often ends at "request accepted into a queue." Adding client-side state machines around approval queues is almost always wrong — the queue *is* the state machine.

**Anti-pattern to stop**: building Retry buttons before confirming with the user that a retry is part of the flow. If the user says "We just need to submit the justification, that's it" — believe them. They know the tenant's policy better than I do.

**Pre-commit check**: when a new feature catches a specific non-2xx response, write down what each status code *means* from the API's perspective, not what it triggers in my UI. 412 = "submitted, awaiting approval." 409 = "already submitted, still awaiting approval." Both are success-shaped from the user's perspective.
