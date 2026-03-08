# =====================================================================
# Windows 11 Complete Debloat Script - Revised
# Compatible: PowerShell 5 & 7
# Fully Non-Interactive
# Improvements: restore point, logging, more apps, full OneDrive
#               cleanup, dmwappushservice, ad ID, activity history
# =====================================================================

# --------------------------------------------------
# Ensure Running as Administrator
# --------------------------------------------------

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    Write-Host "Restarting as Administrator..."
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --------------------------------------------------
# Start Transcript / Logging
# --------------------------------------------------

$LogPath = "$env:TEMP\debloat-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $LogPath
Write-Host "Logging to: $LogPath"

Write-Host ""
Write-Host "==============================================="
Write-Host "        Windows 11 Complete Debloat"
Write-Host "==============================================="
Write-Host ""

# --------------------------------------------------
# Create Restore Point Before Any Changes
# --------------------------------------------------

Write-Host "Creating system restore point..."
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "Pre-Debloat Restore Point" `
        -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Host "Restore point created successfully."
} catch {
    Write-Host "Warning: Could not create restore point. Continuing anyway..."
}

# --------------------------------------------------
# Function: Remove Appx (Installed + Provisioned)
# --------------------------------------------------

function Remove-Appx($Name) {
    Write-Host "Removing $Name ..."

    Get-AppxPackage -Name $Name -AllUsers -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$Name*" } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# --------------------------------------------------
# Function: Winget Uninstall
# --------------------------------------------------

function Remove-WingetApp($Id) {
    Write-Host "Attempting to remove $Id via winget..."

    winget uninstall -e --id $Id --source winget --silent `
        --accept-source-agreements `
        --accept-package-agreements 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Retrying $Id with msstore source..."
        winget uninstall -e --id $Id --source msstore --silent `
            --accept-source-agreements `
            --accept-package-agreements 2>$null
    }
}

# --------------------------------------------------
# Remove Store / UWP Apps
# --------------------------------------------------

$AppList = @(

    # Copilot / Widgets
    "MicrosoftWindows.Client.WebExperience",
    "Microsoft.Windows.Copilot",

    # Bing / News / Weather / Search
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingSearch",

    # Xbox & Gaming
    "Microsoft.GamingApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.XboxGamingOverlay",

    # Microsoft Productivity / Utilities
    "Microsoft.GetHelp",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.OutlookForWindows",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Todos",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.Windows.DevHome",
    "Microsoft.StartExperiencesApp",
    "MicrosoftCorporationII.QuickAssist",
    "Clipchamp.Clipchamp",

    # Cross Device
    "MicrosoftWindows.CrossDevice",

    # Cortana (standalone)
    "Microsoft.549981C3F5F10",

    # Mixed Reality
    "Microsoft.MixedReality.Portal",

    # People / Maps / Camera / Alarms / Sound Recorder
    "Microsoft.People",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsSoundRecorder",

    # Mail & Calendar
    "microsoft.windowscommunicationsapps"

)

foreach ($App in $AppList) {
    Remove-Appx $App
}

# --------------------------------------------------
# Remove Microsoft Teams
# --------------------------------------------------

Write-Host "Removing Microsoft Teams..."

Get-AppxPackage -Name "*Teams*" -AllUsers -ErrorAction SilentlyContinue |
    Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

Remove-WingetApp "Microsoft.Teams"

# --------------------------------------------------
# Remove OneDrive (Full Cleanup)
# --------------------------------------------------

Write-Host "Removing OneDrive..."

Remove-WingetApp "Microsoft.OneDrive"

# Run built-in uninstallers
foreach ($Installer in @(
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
    "$env:SystemRoot\System32\OneDriveSetup.exe"
)) {
    if (Test-Path $Installer) {
        Start-Process $Installer "/uninstall" -NoNewWindow -Wait
    }
}

# Remove OneDrive shell namespace entries (removes icon from Explorer sidebar)
$OneDriveCLSIDs = @(
    "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
    "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
)
foreach ($CLSID in $OneDriveCLSIDs) {
    Remove-Item $CLSID -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove leftover OneDrive folders
$OneDriveFolders = @(
    "$env:USERPROFILE\OneDrive",
    "$env:LOCALAPPDATA\Microsoft\OneDrive",
    "$env:PROGRAMDATA\Microsoft OneDrive"
)
foreach ($Folder in $OneDriveFolders) {
    if (Test-Path $Folder) {
        Remove-Item $Folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --------------------------------------------------
# Disable Telemetry Scheduled Tasks
# --------------------------------------------------

Write-Host "Disabling telemetry scheduled tasks..."

$Tasks = @(
    "\Microsoft\Windows\Application Experience\MareBackup",
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
)

foreach ($Task in $Tasks) {
    try {
        $Path = $Task.Substring(0, $Task.LastIndexOf("\") + 1)
        $Name = $Task.Split("\")[-1]
        Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue
    } catch {}
}

# --------------------------------------------------
# Disable Telemetry Services
# --------------------------------------------------

Write-Host "Disabling telemetry services..."

$TelemetryServices = @("DiagTrack", "dmwappushservice")

foreach ($Svc in $TelemetryServices) {
    Stop-Service $Svc -Force -ErrorAction SilentlyContinue
    Set-Service $Svc -StartupType Disabled -ErrorAction SilentlyContinue
}

# --------------------------------------------------
# Disable Widgets
# --------------------------------------------------

Write-Host "Disabling Widgets..."

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" `
    -Name "AllowNewsAndInterests" -Value 0 -Type DWord

# --------------------------------------------------
# Disable Windows Copilot
# --------------------------------------------------

Write-Host "Disabling Windows Copilot..."

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
    -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
    -Name "SetCopilotHardwareKey" -Value 0 -Type DWord

# --------------------------------------------------
# Disable Bing Search & Cortana in Start
# --------------------------------------------------

Write-Host "Disabling Bing Search integration..."

New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "BingSearchEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "CortanaConsent" -Value 0 -Type DWord

New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" `
    -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord

# --------------------------------------------------
# Disable Telemetry Policy
# --------------------------------------------------

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" `
    -Name "AllowTelemetry" -Value 0 -Type DWord

# --------------------------------------------------
# Disable Advertising ID
# --------------------------------------------------

Write-Host "Disabling Advertising ID..."

New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
    -Name "Enabled" -Value 0 -Type DWord

# --------------------------------------------------
# Disable Activity History & Timeline
# --------------------------------------------------

Write-Host "Disabling Activity History and Timeline..."

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" `
    -Name "PublishUserActivities" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" `
    -Name "UploadUserActivities" -Value 0 -Type DWord

# --------------------------------------------------
# Apply Policy Changes
# --------------------------------------------------

Write-Host "Updating Group Policy..."
gpupdate /force | Out-Null

# --------------------------------------------------
# Done
# --------------------------------------------------

Stop-Transcript

Write-Host ""
Write-Host "==============================================="
Write-Host " Debloat Completed Successfully"
Write-Host " Log saved to: $LogPath"
Write-Host " Reboot Recommended"
Write-Host "==============================================="
Write-Host ""
