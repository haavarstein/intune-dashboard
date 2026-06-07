# =====================================================================
#  Vendored third-party script — credit travels with this file.
#  Source : https://github.com/call4cloud-code/Required-App-Checkin-public
#           Remediations/IME_RequiredAppCheckin_Intune_Detection_Hidden.ps1 @ 9e1341c
#  Author : Rudy Ooms  (@Mister_MDM · https://call4cloud.nl)
#  License: MIT — Copyright (c) 2026 Rudy Ooms
#           Full notice: scripts/THIRD_PARTY_NOTICES.md
#  Vendored verbatim by THE Intune Dashboard. Update from upstream;
#  do not hand-edit the logic below.
# =====================================================================

# Detection script for Intune Remediations
# This intentionally returns non-compliant so the remediation script runs on the schedule.
# The console is hidden to avoid showing a PowerShell window to the signed-in user.

try {
    if (-not ('ImeRequiredAppCheckinDetection.ConsoleWindow' -as [type])) {
        Add-Type -Namespace ImeRequiredAppCheckinDetection -Name ConsoleWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();

[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
    }

    $handle = [ImeRequiredAppCheckinDetection.ConsoleWindow]::GetConsoleWindow()
    if ($handle -ne [System.IntPtr]::Zero) {
        [void][ImeRequiredAppCheckinDetection.ConsoleWindow]::ShowWindow($handle, 0)
    }
}
catch {
}

Write-Output "Kickstart IME required app check-in remediation requested."
exit 1
