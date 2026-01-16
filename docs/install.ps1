# CloudMasters Installer (Windows)
# Downloads the binary to ~/.cloudmasters/bin and adds to PATH

$ErrorActionPreference = "Stop"

$Repo = "BrowserBox/CloudMasters-Marketplace"
$InstallDir = "$env:USERPROFILE\.cloudmasters\bin"
$Asset = "cloudmasters_windows_amd64.exe"

# Create install directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Fetch latest release info
Write-Host "Fetching latest release info..."
$ReleaseUrl = "https://api.github.com/repos/$Repo/releases/latest"
try {
    $Release = Invoke-RestMethod -Uri $ReleaseUrl
} catch {
    Write-Error "Failed to fetch release info: $_"
}

$Tag = $Release.tag_name
$DownloadUrl = "https://github.com/$Repo/releases/download/$Tag/$Asset"
$OutputPath = "$InstallDir\cloudmasters.exe"

Write-Host "Downloading CloudMasters $Tag..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutputPath
} catch {
    Write-Error "Failed to download binary: $_"
}

# Add to PATH if not already present
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Write-Host "Adding to PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    $env:Path += ";$InstallDir"
    Write-Host "Added to PATH. You may need to restart your terminal."
}

Write-Host ""
Write-Host "CloudMasters installed successfully!"
Write-Host "Run 'cloudmasters' to start."
