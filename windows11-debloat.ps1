# =====================================================================
# Windows 11 Complete Debloat Script
# Compatible: PowerShell 5 & 7
# Fully Non-Interactive
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

Write-Host ""
Write-Host "==============================================="
Write-Host "        Windows 11 Complete Debloat"
Write-Host "==============================================="
Write-Host ""

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
    Write-Host "Attempting to remove $Id via winget source..."

    winget uninstall -e --id $Id --source winget --silent `
        --accept-source-agreements `
        --accept-package-agreements 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Retrying with msstore source..."
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

# Bing / News / Weather
"Microsoft.BingNews",
"Microsoft.BingWeather",
"Microsoft.BingSearch",

# Xbox & Gaming
"Microsoft.GamingApp",
"Microsoft.Xbox.TCUI",
"Microsoft.XboxIdentityProvider",
"Microsoft.XboxSpeechToTextOverlay",
"Microsoft.XboxGamingOverlay",

# Microsoft Apps
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
"MicrosoftWindows.CrossDevice"

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
# Remove OneDrive
# --------------------------------------------------

Write-Host "Removing OneDrive..."

Remove-WingetApp "Microsoft.OneDrive"

if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" "/uninstall" -NoNewWindow -Wait
}

if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
    Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" "/uninstall" -NoNewWindow -Wait
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
        $Path = $Task.Substring(0,$Task.LastIndexOf("\")+1)
        $Name = $Task.Split("\")[-1]
        Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue
    } catch {}
}

# --------------------------------------------------
# Disable Telemetry Service
# --------------------------------------------------

Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue
Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue

# --------------------------------------------------
# Disable Widgets
# --------------------------------------------------

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" `
    -Name "AllowNewsAndInterests" -Value 0 -Type DWord

# --------------------------------------------------
# Disable Windows Copilot
# --------------------------------------------------

New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
    -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
    -Name "SetCopilotHardwareKey" -Value 0 -Type DWord

# --------------------------------------------------
# Disable Bing Search (NEW)
# --------------------------------------------------

Write-Host "Disabling Bing Search integration..."

New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "BingSearchEnabled" -Value 0 -Type DWord

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "CortanaConsent" -Value 0 -Type DWord

# Also disable search box web suggestions
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
# Apply Policy Changes
# --------------------------------------------------

Write-Host "Updating Group Policy..."
gpupdate /force | Out-Null

Write-Host ""
Write-Host "==============================================="
Write-Host " Debloat Completed Successfully"
Write-Host " Reboot Recommended"
Write-Host "==============================================="
Write-Host ""
