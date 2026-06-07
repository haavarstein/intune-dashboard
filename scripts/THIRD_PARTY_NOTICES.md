# Third-party notices & credits

THE Intune Dashboard ships some PowerShell scripts that are **vendored from other
people's public GitHub repositories** so the dashboard can one-click deploy them.
The original authors keep all credit and copyright. This file is the ledger of
every such script.

## How we credit vendored scripts (the convention — follow this every time)

When we add a script sourced from someone else's repo, **all five** of these apply:

1. **Attribution header in the file.** Prepend a comment block to the vendored
   `.ps1` naming the source repo + path, the upstream commit SHA, the author, and
   the license. Because the dashboard base64-encodes the script straight into the
   tenant's Proactive Remediation, this header travels all the way into Intune —
   the credit can't be separated from the artifact.
2. **An entry in this file** (the table below) with author, source, pinned commit,
   license, and which dashboard feature uses it.
3. **Preserve the upstream license.** If the license requires the notice to ship
   with copies (MIT, BSD, Apache-2.0, …), reproduce the full text in the
   "License texts" section below so the repository as a whole stays compliant.
4. **In-product credit.** Wherever the dashboard surfaces the deploy UI, link to
   the author / source repo (e.g. the Remediation tab's deploy card and modal).
5. **Pin to a commit, vendor verbatim.** Don't hand-edit vendored logic. To pick
   up upstream fixes, re-download at a new commit and bump the SHA in the header
   and the table. Keep our own changes to the attribution header only.

> We only vendor scripts under licenses that permit redistribution (MIT, BSD,
> Apache-2.0, etc.). If a script is unlicensed or its terms forbid redistribution,
> we link to it and ask the user to upload it themselves instead of bundling it.

## Vendored scripts

| Script(s) | Feature | Author | Source (pinned) | License |
| --- | --- | --- | --- | --- |
| `ime-required-app-checkin-detect.ps1`, `ime-required-app-checkin-remediate.ps1` | Remediation tab → **IME Required App Check-in** deploy + per-device **⚡ Check-in** | **Rudy Ooms** ([@Mister_MDM](https://twitter.com/Mister_MDM) · [call4cloud.nl](https://call4cloud.nl)) | [call4cloud-code/Required-App-Checkin-public](https://github.com/call4cloud-code/Required-App-Checkin-public) @ `9e1341c` | MIT |

Scripts authored by THE Intune Dashboard itself (e.g. `software-metering-detect.ps1`)
are covered by the repository's own [LICENSE](../LICENSE) and are not listed here.

## License texts

### IME Required App Check-in — Rudy Ooms

```
MIT License

Copyright (c) 2026 Rudy Ooms

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
