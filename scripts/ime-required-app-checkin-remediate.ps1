# =====================================================================
#  Vendored third-party script — credit travels with this file.
#  Source : https://github.com/call4cloud-code/Required-App-Checkin-public
#           Remediations/IME_RequiredAppCheckin_Intune_Remediation_Hidden.ps1 @ 9e1341c
#  Author : Rudy Ooms  (@Mister_MDM · https://call4cloud.nl)
#  License: MIT — Copyright (c) 2026 Rudy Ooms
#           Full notice: scripts/THIRD_PARTY_NOTICES.md
#  Vendored verbatim by THE Intune Dashboard. Update from upstream;
#  do not hand-edit the logic below.
# =====================================================================

<#
IME required app check-in remediation script

Purpose:
  Trigger the same IME app check-in path used by the Company Portal Settings Sync IME part.

Primary call:
  net.pipe://localhost/IntuneManagementExtension/StatusService/
  IStatusService.CheckInAsync(Guid)

Intune Remediations settings:
  Run this script using the logged-on credentials: Yes
  Run script in 64-bit PowerShell: No

Notes:
  This does not restart the IntuneManagementExtension service.
  This does not call intunemanagementextension://syncapp.
  This triggers the required plus available apps check-in path.
  By default the console window is hidden. Use -ShowWindow for manual debugging.
#>

[CmdletBinding()]
param(
    [int]$WaitSeconds = 60,
    [string]$StatusServiceLibraryPath,
    [switch]$ShowWindow
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Hide-CurrentConsoleWindow {
    try {
        if (-not ('ImeRequiredAppCheckin.ConsoleWindow' -as [type])) {
            Add-Type -Namespace ImeRequiredAppCheckin -Name ConsoleWindow -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();

[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
        }

        $handle = [ImeRequiredAppCheckin.ConsoleWindow]::GetConsoleWindow()
        if ($handle -ne [System.IntPtr]::Zero) {
            [void][ImeRequiredAppCheckin.ConsoleWindow]::ShowWindow($handle, 0)
            return $true
        }
    }
    catch {
    }

    return $false
}

if (-not $ShowWindow) {
    [void](Hide-CurrentConsoleWindow)
}


$script:LogRoot = Join-Path $env:LOCALAPPDATA 'IMERequiredAppCheckinRemediation\Logs'
$script:LogFile = Join-Path $script:LogRoot ('IMERequiredAppCheckin_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$script:ImeAssemblyResolveRegistered = $false
$script:ImeAssemblyResolveFolder = $null

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR','DEBUG')]
        [string]$Level = 'INFO'
    )

    if (-not (Test-Path $script:LogRoot)) {
        New-Item -Path $script:LogRoot -ItemType Directory -Force | Out-Null
    }

    $line = '{0} {1,-5} {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
    Write-Output $line
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
}

function Test-IsWindowsPowerShell {
    return ($PSVersionTable.PSEdition -eq 'Desktop')
}

function Test-IsSystemContext {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ($identity.User.Value -eq 'S-1-5-18')
}

function Invoke-SelfIn32BitWindowsPowerShell {
    if (-not [Environment]::Is64BitProcess) {
        return $false
    }

    $wowPowerShell = Join-Path $env:WINDIR 'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path $wowPowerShell)) {
        return $false
    }

    if (-not $PSCommandPath) {
        return $false
    }

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath),
        '-WaitSeconds', $WaitSeconds
    )

    if ($StatusServiceLibraryPath) {
        $arguments += @('-StatusServiceLibraryPath', ('"{0}"' -f $StatusServiceLibraryPath))
    }

    if ($ShowWindow) {
        $arguments += '-ShowWindow'
    }

    $windowStyle = if ($ShowWindow) { 'Normal' } else { 'Hidden' }

    Write-Log "Relaunching in 32-bit Windows PowerShell: $wowPowerShell" 'INFO'
    $process = Start-Process -FilePath $wowPowerShell -ArgumentList ($arguments -join ' ') -WindowStyle $windowStyle -Wait -PassThru
    exit $process.ExitCode
}

function Get-IMEInstallCandidates {
    $roots = @()

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $roots += (Join-Path $programFilesX86 'Microsoft Intune Management Extension')
    }

    if ($env:ProgramFiles) {
        $roots += (Join-Path $env:ProgramFiles 'Microsoft Intune Management Extension')
    }

    $roots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
}

function Resolve-StatusServiceLibrary {
    param([string]$ExplicitPath)

    if ($ExplicitPath -and $ExplicitPath.Trim()) {
        if (Test-Path $ExplicitPath) {
            return (Resolve-Path $ExplicitPath).Path
        }
        throw "StatusServiceLibraryPath was provided but does not exist: $ExplicitPath"
    }

    $fileName = 'Microsoft.Management.Clients.IntuneManagementExtension.StatusServiceLibrary.dll'
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($root in Get-IMEInstallCandidates) {
        $candidate = Join-Path $root $fileName
        if (Test-Path $candidate) {
            [void]$candidates.Add($candidate)
        }

        Get-ChildItem -Path $root -Filter $fileName -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$candidates.Add($_.FullName)
        }
    }

    $selected = $candidates | Select-Object -Unique | Sort-Object | Select-Object -First 1
    if (-not $selected) {
        throw "Could not find $fileName."
    }

    return $selected
}

function Get-IMEServiceInfo {
    try {
        $svc = Get-Service -Name 'IntuneManagementExtension' -ErrorAction Stop
        $svcWmi = $null
        try {
            $svcWmi = Get-CimInstance -ClassName Win32_Service -Filter "Name='IntuneManagementExtension'" -ErrorAction Stop
        }
        catch {
        }

        [pscustomobject]@{
            Found = $true
            Status = $svc.Status
            Path = if ($svcWmi) { $svcWmi.PathName } else { $null }
        }
    }
    catch {
        [pscustomobject]@{
            Found = $false
            Status = $null
            Path = $null
        }
    }
}

function Initialize-IMEStatusServiceAssemblies {
    param([string]$StatusDll)

    $folder = Split-Path -Parent $StatusDll
    Write-Log "Preparing IME assembly resolver for: $folder" 'DEBUG'

    if (-not $script:ImeAssemblyResolveRegistered) {
        $script:ImeAssemblyResolveRegistered = $true
        $script:ImeAssemblyResolveFolder = $folder

        [System.AppDomain]::CurrentDomain.add_AssemblyResolve({
            param($sender, $args)

            try {
                $assemblyName = New-Object System.Reflection.AssemblyName($args.Name)
                $candidate = Join-Path $script:ImeAssemblyResolveFolder ($assemblyName.Name + '.dll')
                if (Test-Path $candidate) {
                    return [System.Reflection.Assembly]::LoadFrom($candidate)
                }
            }
            catch {
            }

            return $null
        })

        Write-Log 'Registered IME assembly resolver.' 'DEBUG'
    }

    [void][System.Reflection.Assembly]::LoadFrom($StatusDll)
    Write-Log "Loaded StatusService assembly: $StatusDll" 'DEBUG'
}

function Get-ExceptionTreeText {
    param([System.Exception]$Exception)

    $lines = New-Object System.Collections.Generic.List[string]
    $current = $Exception
    $index = 0

    while ($current) {
        [void]$lines.Add("Exception[$index] $($current.GetType().FullName): $($current.Message)")

        $rtl = $current -as [System.Reflection.ReflectionTypeLoadException]
        if ($rtl -and $rtl.LoaderExceptions) {
            $loaderIndex = 0
            foreach ($loader in $rtl.LoaderExceptions) {
                if ($loader) {
                    [void]$lines.Add("  LoaderException[$loaderIndex] $($loader.GetType().FullName): $($loader.Message)")
                    if ($loader -is [System.IO.FileNotFoundException]) {
                        [void]$lines.Add("    FileName: $($loader.FileName)")
                    }
                }
                $loaderIndex++
            }
        }

        $current = $current.InnerException
        $index++
    }

    return ($lines -join [Environment]::NewLine)
}

function Add-IMEStatusServiceClientType {
    param([string]$StatusDll)

    if ('ImeStatusServiceRemediationInvoker' -as [type]) {
        return
    }

    Initialize-IMEStatusServiceAssemblies -StatusDll $StatusDll

    $source = @'
using System;
using System.Collections.Generic;
using System.ServiceModel;
using System.Threading;
using System.Security.Principal;
using Microsoft.Management.Clients.IntuneManagementExtension.StatusServiceLibrary;

[CallbackBehavior(UseSynchronizationContext = false, ConcurrencyMode = ConcurrencyMode.Multiple)]
public sealed class ImeStatusServiceRemediationCallback : IStatusServiceCallback
{
    public static readonly List<string> Lines = new List<string>();
    public static ManualResetEventSlim SyncCompleted = new ManualResetEventSlim(false);
    public static bool? LastSuccess = null;
    public static string LastErrorCode = "<none>";

    private static void AddLine(string line)
    {
        lock (Lines)
        {
            Lines.Add(line);
        }
    }

    public void SyncComplete(SyncResult result)
    {
        if (result == null)
        {
            AddLine("Callback SyncComplete: result was null");
            LastSuccess = false;
            LastErrorCode = "NullResult";
            SyncCompleted.Set();
            return;
        }

        LastSuccess = result.Success;
        LastErrorCode = result.ErrorCode.ToString();
        AddLine("Callback SyncComplete: SessionId=" + result.SessionId + ", Success=" + result.Success + ", ErrorCode=" + result.ErrorCode);

        if (result.Success)
        {
            AddLine("Validation=CallbackCompletedSuccess");
        }
        else
        {
            AddLine("Validation=CallbackCompletedWithError:" + result.ErrorCode);
        }

        SyncCompleted.Set();
    }

    public void AppStatusUpdate(AppInstallStatusReport report)
    {
        if (report == null)
        {
            AddLine("Callback AppStatusUpdate: report was null");
            return;
        }

        AddLine("Callback AppStatusUpdate: AppId=" + report.AppId + ", Required=" + report.Required + ", Status=" + report.Status + ", Status2=" + report.Status2 + ", ErrorCode=" + report.ErrorCode);
    }

    public void DownloadProgressUpdate(DownloadProgressReport report)
    {
        if (report == null)
        {
            AddLine("Callback DownloadProgressUpdate: report was null");
            return;
        }

        AddLine("Callback DownloadProgressUpdate: AppId=" + report.AppId + ", BytesDownloaded=" + report.BytesDownloaded + ", TotalSizeInBytes=" + report.TotalSizeInBytes);
    }
}

public static class ImeStatusServiceRemediationInvoker
{
    public static string InvokeFullCheckIn(int waitSeconds)
    {
        lock (ImeStatusServiceRemediationCallback.Lines)
        {
            ImeStatusServiceRemediationCallback.Lines.Clear();
        }

        ImeStatusServiceRemediationCallback.SyncCompleted.Reset();
        ImeStatusServiceRemediationCallback.LastSuccess = null;
        ImeStatusServiceRemediationCallback.LastErrorCode = "<none>";

        Guid sessionId = Guid.NewGuid();
        ImeStatusServiceRemediationCallback.Lines.Add("SessionId=" + sessionId);

        WindowsIdentity currentIdentity = WindowsIdentity.GetCurrent();
        ImeStatusServiceRemediationCallback.Lines.Add("ClientIdentity Name=" + currentIdentity.Name);
        ImeStatusServiceRemediationCallback.Lines.Add("ClientIdentity User=" + (currentIdentity.User == null ? "<null>" : currentIdentity.User.Value));
        ImeStatusServiceRemediationCallback.Lines.Add("ClientIdentity IsAuthenticated=" + currentIdentity.IsAuthenticated + ", ImpersonationLevel=" + currentIdentity.ImpersonationLevel);

        NetNamedPipeBinding binding = new NetNamedPipeBinding(NetNamedPipeSecurityMode.Transport);
        binding.OpenTimeout = TimeSpan.FromSeconds(10);
        binding.SendTimeout = TimeSpan.FromSeconds(30);
        binding.ReceiveTimeout = TimeSpan.FromMinutes(3);
        binding.CloseTimeout = TimeSpan.FromSeconds(10);
        binding.MaxReceivedMessageSize = 10485760;

        InstanceContext callbackContext = new InstanceContext(new ImeStatusServiceRemediationCallback());
        DuplexChannelFactory<IStatusService> factory = null;
        IStatusService channel = null;
        ICommunicationObject communicationObject = null;

        try
        {
            factory = new DuplexChannelFactory<IStatusService>(callbackContext, binding, new EndpointAddress(StatusServiceConstants.ServiceAddress));
            factory.Credentials.Windows.AllowedImpersonationLevel = TokenImpersonationLevel.Impersonation;
            ImeStatusServiceRemediationCallback.Lines.Add("AllowedImpersonationLevel=" + factory.Credentials.Windows.AllowedImpersonationLevel);

            channel = factory.CreateChannel();
            communicationObject = (ICommunicationObject)channel;
            communicationObject.Open();
            ImeStatusServiceRemediationCallback.Lines.Add("Opened StatusService channel: " + StatusServiceConstants.ServiceAddress);

            uint version = channel.GetVersionAsync().GetAwaiter().GetResult();
            ImeStatusServiceRemediationCallback.Lines.Add("StatusService version=" + version);

            Guid currentBefore = SafeGetCurrentCheckInId(channel, "before request");

            ImeStatusServiceRemediationCallback.Lines.Add("Calling CheckInAsync for required plus available apps.");
            channel.CheckInAsync(sessionId).GetAwaiter().GetResult();

            ImeStatusServiceRemediationCallback.Lines.Add("StatusService request accepted.");
            ImeStatusServiceRemediationCallback.Lines.Add("Validation=RequestAccepted");

            Guid currentAfter = SafeGetCurrentCheckInId(channel, "after request");
            if (currentAfter.Equals(sessionId))
            {
                ImeStatusServiceRemediationCallback.Lines.Add("Validation=RunningConfirmedByCurrentCheckInId");
            }
            else if (currentAfter.Equals(Guid.Empty))
            {
                ImeStatusServiceRemediationCallback.Lines.Add("Validation=CurrentCheckInIdEmptyAfterAccept");
            }
            else
            {
                ImeStatusServiceRemediationCallback.Lines.Add("Validation=DifferentCurrentCheckInId:" + currentAfter);
            }

            if (waitSeconds > 0)
            {
                bool completed = false;
                DateTime deadline = DateTime.UtcNow.AddSeconds(waitSeconds);
                Guid lastSeen = currentAfter;
                bool sawOurSession = currentAfter.Equals(sessionId);

                while (DateTime.UtcNow < deadline)
                {
                    if (ImeStatusServiceRemediationCallback.SyncCompleted.Wait(TimeSpan.FromSeconds(1)))
                    {
                        completed = true;
                        break;
                    }

                    Guid currentDuringWait = SafeGetCurrentCheckInId(channel, null);
                    if (!currentDuringWait.Equals(lastSeen))
                    {
                        ImeStatusServiceRemediationCallback.Lines.Add("CurrentCheckInId during wait=" + FormatGuid(currentDuringWait));
                        lastSeen = currentDuringWait;
                    }

                    if (currentDuringWait.Equals(sessionId))
                    {
                        sawOurSession = true;
                    }
                    else if (sawOurSession && currentDuringWait.Equals(Guid.Empty))
                    {
                        ImeStatusServiceRemediationCallback.Lines.Add("CurrentCheckInId cleared after matching our session.");
                        completed = true;
                        break;
                    }
                }

                ImeStatusServiceRemediationCallback.Lines.Add("WaitForSyncComplete=" + completed);
                Guid currentFinal = SafeGetCurrentCheckInId(channel, "final");

                if (completed)
                {
                    if (ImeStatusServiceRemediationCallback.LastSuccess == true)
                    {
                        ImeStatusServiceRemediationCallback.Lines.Add("Validation=CompletedAndSuccessful");
                    }
                    else if (ImeStatusServiceRemediationCallback.LastSuccess == false)
                    {
                        ImeStatusServiceRemediationCallback.Lines.Add("Validation=CompletedButFailed:" + ImeStatusServiceRemediationCallback.LastErrorCode);
                    }
                    else if (sawOurSession && currentFinal.Equals(Guid.Empty))
                    {
                        ImeStatusServiceRemediationCallback.Lines.Add("Validation=CompletedByCurrentCheckInIdCleared");
                    }
                    else
                    {
                        ImeStatusServiceRemediationCallback.Lines.Add("Validation=CompletedObservableButNoCallbackResult");
                    }
                }
                else
                {
                    ImeStatusServiceRemediationCallback.Lines.Add("Validation=AcceptedButNotCompletedWithinWaitWindow");
                }
            }
            else
            {
                ImeStatusServiceRemediationCallback.Lines.Add("WaitForSyncComplete=skipped");
                ImeStatusServiceRemediationCallback.Lines.Add("Validation=AcceptedOnlyNoWait");
            }

            SafeClose(communicationObject, factory);
            return JoinLines();
        }
        catch (Exception ex)
        {
            ImeStatusServiceRemediationCallback.Lines.Add("Exception=" + ex.GetType().FullName + ": " + ex.Message);
            try { if (communicationObject != null) communicationObject.Abort(); } catch { }
            try { if (factory != null) factory.Abort(); } catch { }
            return JoinLines();
        }
    }

    private static Guid SafeGetCurrentCheckInId(IStatusService channel, string label)
    {
        try
        {
            Guid current = channel.GetCurrentCheckInIdAsync().GetAwaiter().GetResult();
            if (label != null)
            {
                ImeStatusServiceRemediationCallback.Lines.Add("CurrentCheckInId " + label + "=" + FormatGuid(current));
            }
            return current;
        }
        catch (Exception ex)
        {
            if (label != null)
            {
                ImeStatusServiceRemediationCallback.Lines.Add("CurrentCheckInId " + label + " query failed: " + ex.GetType().FullName + ": " + ex.Message);
            }
            return Guid.Empty;
        }
    }

    private static string FormatGuid(Guid value)
    {
        if (value.Equals(Guid.Empty)) return "<empty>";
        return value.ToString();
    }

    private static void SafeClose(ICommunicationObject communicationObject, DuplexChannelFactory<IStatusService> factory)
    {
        try
        {
            if (communicationObject != null && communicationObject.State == CommunicationState.Opened)
            {
                communicationObject.Close();
            }
        }
        catch
        {
            try { if (communicationObject != null) communicationObject.Abort(); } catch { }
        }

        try
        {
            if (factory != null && factory.State == CommunicationState.Opened)
            {
                factory.Close();
            }
        }
        catch
        {
            try { if (factory != null) factory.Abort(); } catch { }
        }
    }

    private static string JoinLines()
    {
        lock (ImeStatusServiceRemediationCallback.Lines)
        {
            return String.Join(Environment.NewLine, ImeStatusServiceRemediationCallback.Lines.ToArray());
        }
    }
}
'@

    $refs = @(
        'System.dll',
        'System.Core.dll',
        'System.ServiceModel.dll',
        'System.Runtime.Serialization.dll',
        $StatusDll
    )

    Write-Log "Compiling StatusService client helper against: $StatusDll" 'DEBUG'

    try {
        Add-Type -ReferencedAssemblies $refs -TypeDefinition $source -Language CSharp
        Write-Log 'StatusService client helper compiled.' 'OK'
    }
    catch {
        $detail = Get-ExceptionTreeText -Exception $_.Exception
        Write-Log "StatusService helper compile failed:$([Environment]::NewLine)$detail" 'ERROR'
        throw
    }
}

function Invoke-IMERequiredAppCheckIn {
    param(
        [string]$StatusDll,
        [int]$RequestedWaitSeconds
    )

    Add-IMEStatusServiceClientType -StatusDll $StatusDll

    Write-Log 'Opening IME StatusService named pipe.'
    $result = [ImeStatusServiceRemediationInvoker]::InvokeFullCheckIn($RequestedWaitSeconds)

    $hasAccepted = $false
    $hasCompleted = $false
    $hasFailed = $false

    foreach ($line in ($result -split [Environment]::NewLine)) {
        if (-not $line) { continue }

        if ($line -like 'Validation=RequestAccepted*') {
            $hasAccepted = $true
            Write-Log $line 'OK'
        }
        elseif ($line -like 'Validation=CompletedAndSuccessful*' -or $line -like 'Validation=CallbackCompletedSuccess*' -or $line -like 'Validation=CompletedByCurrentCheckInIdCleared*') {
            $hasCompleted = $true
            Write-Log $line 'OK'
        }
        elseif ($line -like 'Validation=RunningConfirmedByCurrentCheckInId*') {
            Write-Log $line 'OK'
        }
        elseif ($line -like 'Validation=AcceptedButNotCompletedWithinWaitWindow*') {
            Write-Log $line 'WARN'
        }
        elseif ($line -like 'Validation=CompletedButFailed*' -or $line -like 'Validation=CallbackCompletedWithError*' -or $line -like 'Exception=*') {
            $hasFailed = $true
            Write-Log $line 'ERROR'
        }
        elseif ($line -like 'Callback SyncComplete:*Success=True*') {
            $hasCompleted = $true
            Write-Log $line 'OK'
        }
        elseif ($line -like 'Callback SyncComplete:*Success=False*') {
            $hasFailed = $true
            Write-Log $line 'ERROR'
        }
        elseif ($line -like 'CurrentCheckInId*' -or $line -like 'WaitForSyncComplete*' -or $line -like 'SessionId=*') {
            Write-Log $line 'INFO'
        }
        else {
            Write-Log $line 'INFO'
        }
    }

    if ($hasFailed) {
        return 1
    }

    if ($hasCompleted) {
        Write-Log 'IME required plus available app check-in completed successfully.' 'OK'
        return 0
    }

    if ($hasAccepted) {
        Write-Log 'IME required plus available app check-in was accepted. Completion was not confirmed inside the wait window.' 'OK'
        return 0
    }

    Write-Log 'IME required plus available app check-in was not accepted.' 'ERROR'
    return 1
}

try {
    Write-Log 'IME required app check-in remediation started.'
    Write-Log "Log file: $script:LogFile" 'DEBUG'
    Write-Log "PowerShell edition: $($PSVersionTable.PSEdition). Version: $($PSVersionTable.PSVersion)" 'DEBUG'
    Write-Log "Process is 64-bit: $([Environment]::Is64BitProcess)" 'DEBUG'
    Write-Log "ShowWindow override: $ShowWindow" 'DEBUG'

    if (-not (Test-IsWindowsPowerShell)) {
        throw 'This remediation must run in Windows PowerShell 5.1, not PowerShell 7.'
    }

    if (Test-IsSystemContext) {
        throw 'This remediation must run using the logged-on user credentials. Do not run it as SYSTEM.'
    }

    Invoke-SelfIn32BitWindowsPowerShell | Out-Null

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    Write-Log "Running as: $($identity.Name)"
    Write-Log "User SID: $($identity.User.Value)" 'DEBUG'

    $ime = Get-IMEServiceInfo
    if (-not $ime.Found) {
        throw 'IntuneManagementExtension service was not found.'
    }

    Write-Log "IntuneManagementExtension service status: $($ime.Status)" 'OK'
    if ($ime.Path) {
        Write-Log "IntuneManagementExtension service path: $($ime.Path)" 'DEBUG'
    }

    if ($ime.Status -ne 'Running') {
        throw "IntuneManagementExtension service is not running. Current status: $($ime.Status)"
    }

    $statusDll = Resolve-StatusServiceLibrary -ExplicitPath $StatusServiceLibraryPath
    Write-Log "Using StatusService library: $statusDll" 'OK'

    $exitCode = Invoke-IMERequiredAppCheckIn -StatusDll $statusDll -RequestedWaitSeconds $WaitSeconds
    exit $exitCode
}
catch {
    Write-Log $_.Exception.Message 'ERROR'
    Write-Log (Get-ExceptionTreeText -Exception $_.Exception) 'DEBUG'
    exit 1
}
