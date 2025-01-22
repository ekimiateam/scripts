param(
    [switch]$Force = $false,
    [switch]$Revert = $false,
    [switch]$NoDownload = $false
)

function Write-Log($Message, [string]$Color = "White") {
    $timeStampedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host $timeStampedMessage -ForegroundColor $Color
    Add-Content -Path (Join-Path $PSScriptRoot "latest.log") -Value $timeStampedMessage
}

# Ensure the script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "This script must be run as Administrator. Please restart PowerShell as Administrator and try again." "Red"
    exit 1
}

# Check if rEFInd is already the default bootloader (unless -Force is used)
if (-not $Force) {
    $currentBootloader = bcdedit /enum firmware | Select-String "path.*\\EFI\\refind\\refind_x64\.efi"
    if ($currentBootloader) {
        Write-Log "rEFInd is already installed as the default bootloader." "Yellow"
        Write-Log "Use -Force parameter to reinstall anyway (e.g., '.\script.ps1 -Force')" "Yellow"
        exit 0
    }
}

# Define variables
$refindUrl = "https://freefr.dl.sourceforge.net/project/refind/0.14.2/refind-bin-0.14.2.zip"
$downloadPath = Join-Path $PSScriptRoot "refind.zip"
$extractPath = Join-Path $PSScriptRoot "refind"
$efiPartition = "Z:"  # Temporary mount point for EFI System Partition
$efiRefindPath = "$efiPartition\EFI\refind"

# Download rEFInd
if (-not $NoDownload) {
    Write-Log "Downloading rEFInd..." "Cyan"
    try {
        Invoke-WebRequest -Uri $refindUrl -OutFile $downloadPath -ErrorAction Stop
    } catch {
        Write-Log "Error downloading rEFInd: $_" "Red"
        exit 1
    }
}

# Extract the ZIP file
Write-Log "Extracting rEFInd..." "Cyan"
try {
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force -ErrorAction Stop
} catch {
    Write-Log "Error extracting rEFInd: $_" "Red"
    exit 1
}

# Locate rEFInd folder
$refindFolder = Get-ChildItem -Path $extractPath -Directory | Where-Object { $_.Name -like "refind*" } | Select-Object -First 1
if (-not $refindFolder) {
    Write-Log "Error: Could not locate rEFInd folder in the extracted files." "Red"
    exit 1
}

# Disable fast startup
Write-Log "Disabling Windows Fast Startup..." "Cyan"
try {
    powercfg /h off
} catch {
    Write-Log "Warning: Could not disable Fast Startup: $_" "Yellow"
}

# Mount the EFI partition using diskpart
Write-Log "Mounting EFI partition using diskpart..." "Cyan"

# First, try to remove existing Z: drive letter if it exists
if (Test-Path -Path "Z:\") {
    $removeDiskpartScript = @"
select volume Z
remove letter=Z
exit
"@
    $removeDiskpartFile = [System.IO.Path]::GetTempFileName()
    $removeDiskpartScript | Out-File -FilePath $removeDiskpartFile -Encoding ASCII
    diskpart /s $removeDiskpartFile
    Remove-Item -Path $removeDiskpartFile -Force
    Start-Sleep -Seconds 2  # Give Windows time to process the change
}

# Now mount the EFI partition
$diskpartScript = @"
select disk 0
list partition
select partition 1
assign letter=Z
exit
"@

# Create a temporary file for diskpart commands
$diskpartFile = [System.IO.Path]::GetTempFileName()
$diskpartScript | Out-File -FilePath $diskpartFile -Encoding ASCII
diskpart /s $diskpartFile
Remove-Item -Path $diskpartFile -Force

# Verify the mount was successful
$retryCount = 0
$maxRetries = 3
while (-not (Test-Path -Path "Z:\") -and $retryCount -lt $maxRetries) {
    Start-Sleep -Seconds 2
    $retryCount++
}

if (-not (Test-Path -Path "Z:\")) {
    Write-Log "Error: Failed to mount EFI partition after multiple attempts." "Red"
    exit 1
}

# Copy rEFInd to EFI partition
Write-Log "Copying rEFInd files to EFI partition..." "Cyan"
try {
    if (-not (Test-Path -Path $efiRefindPath)) {
        New-Item -ItemType Directory -Path $efiRefindPath -Force | Out-Null
    }
    Copy-Item -Path "$($refindFolder.FullName)\refind\*" -Destination $efiRefindPath -Recurse -Force -ErrorAction Stop
} catch {
    Write-Log "Error copying rEFInd files: $_" "Red"
    exit 1
}

# Rename configuration file
Write-Log "Setting up rEFInd configuration..." "Cyan"
try {
    $configPath = "$efiRefindPath\refind.conf-sample"
    if (Test-Path $configPath) {
        $targetPath = "$efiRefindPath\refind.conf"
        Copy-Item -Path $configPath -Destination $targetPath -Force
        Write-Log "Configuration file copied from refind.conf-sample" "Green"
    } else {
        Write-Log "Error: Could not find refind.conf-sample" "Red"
        exit 1
    }
} catch {
    Write-Log "Error setting up configuration file: $_" "Red"
    exit 1
}

# Set rEFInd as default boot manager
Write-Log "Setting rEFInd as default boot manager..." "Cyan"
try {
    bcdedit /set "{bootmgr}" path \EFI\refind\refind_x64.efi
    bcdedit /set "{bootmgr}" description "rEFInd Boot Manager"
} catch {
    Write-Log "Error setting rEFInd as default boot manager: $_" "Red"
    exit 1
}

# Cleanup
Write-Log "Cleaning up temporary files..." "Cyan"
if (-not $NoDownload) {
    Remove-Item -Path $downloadPath -Force
}
Remove-Item -Path $extractPath -Recurse -Force

# Remove the temporary drive letter
Write-Log "Removing temporary drive letter..." "Cyan"
$cleanupDiskpartScript = @"
select volume Z
remove letter=Z
exit
"@
$cleanupDiskpartFile = [System.IO.Path]::GetTempFileName()
$cleanupDiskpartScript | Out-File -FilePath $cleanupDiskpartFile -Encoding ASCII
diskpart /s $cleanupDiskpartFile
Remove-Item -Path $cleanupDiskpartFile -Force

Write-Log "rEFInd installation complete! Please reboot your system to test it." "Green"