// MSAL public-client config + sign-in scopes for THE Intune Dashboard.
// Loaded as a classic script before the main page script.
// Write scopes are requested just-in-time via ensureScopeToken() in the main script.

const MSAL_CONFIG = {
  auth: {
    clientId: '10c9e900-db54-4aa1-979e-1351338a8c9b',
    authority: 'https://login.microsoftonline.com/common',
    redirectUri: window.location.origin + window.location.pathname
  },
  cache: { cacheLocation: 'sessionStorage' }
};

// Read-only scopes only — write scopes (DeviceManagementApps.ReadWrite.All,
// DeviceManagementScripts.ReadWrite.All, Mail.Send, …) are requested
// just-in-time via ensureScopeToken() the first time a write action runs,
// so read-only sessions never carry write permissions.
// Optional: Policy.Read.All is NOT listed here — Posture CA section requests
// it on demand (Grant button) so tenants that deny it still get Compliance.
const SCOPES = [
  'DeviceManagementManagedDevices.Read.All',
  'DeviceManagementApps.Read.All',
  'DeviceManagementScripts.Read.All',
  'DeviceManagementConfiguration.Read.All',
  'DeviceManagementServiceConfig.Read.All',
  'Group.Read.All',
  'User.Read',
  'User.Read.All',
  'AuditLog.Read.All',
  'ThreatHunting.Read.All',
  'BitlockerKey.ReadBasic.All',
  'Device.Read.All'
];
