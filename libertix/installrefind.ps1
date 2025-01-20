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

# Handle revert operation
if ($Revert) {
    Write-Log "Reverting to Windows Boot Manager..." "Cyan"
    try {
        # Set Windows Boot Manager as default
        bcdedit /set "{bootmgr}" path \EFI\Microsoft\Boot\bootmgfw.efi
        
        # Mount EFI partition to remove rEFInd files
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
            Start-Sleep -Seconds 2
        }

        $diskpartScript = @"
select disk 0
list partition
select partition 1
assign letter=Z
exit
"@
        $diskpartFile = [System.IO.Path]::GetTempFileName()
        $diskpartScript | Out-File -FilePath $diskpartFile -Encoding ASCII
        diskpart /s $diskpartFile
        Remove-Item -Path $diskpartFile -Force
        Start-Sleep -Seconds 2

        # Remove rEFInd directory if it exists
        if (Test-Path -Path "Z:\EFI\refind") {
            Remove-Item -Path "Z:\EFI\refind" -Recurse -Force
        }

        # Cleanup mounted partition
        $cleanupDiskpartScript = @"
select volume Z
remove letter=Z
exit
"@
        $cleanupDiskpartFile = [System.IO.Path]::GetTempFileName()
        $cleanupDiskpartScript | Out-File -FilePath $cleanupDiskpartFile -Encoding ASCII
        diskpart /s $cleanupDiskpartFile
        Remove-Item -Path $cleanupDiskpartFile -Force

        Write-Log "Successfully reverted to Windows Boot Manager. Please reboot your system." "Green"
        exit 0
    }
    catch {
        Write-Log "Error reverting to Windows Boot Manager: $_" "Red"
        exit 1
    }
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
    # Try to find existing config file first
    $possibleConfigs = @(
        "$efiRefindPath\refind.conf-sample",
        "$efiRefindPath\config\refind.conf-sample",
        "$efiRefindPath\refind-sample.conf"
    )

    $configFound = $false
    foreach ($configPath in $possibleConfigs) {
        if (Test-Path $configPath) {
            $targetPath = "$efiRefindPath\refind.conf"
            Copy-Item -Path $configPath -Destination $targetPath -Force
            $configFound = $true
            Write-Log "Configuration file copied from $configPath" "Green"
            break
        }
    }

    if (-not $configFound) {
        Write-Log "Creating basic rEFInd configuration file..." "Yellow"
        $basicConfig = @"
# Basic rEFInd configuration file

# Timeout in seconds for the main menu screen
timeout 20

# Set the default selection to be the first detected OS
default_selection 1

# Reduce mouse polling rate to avoid interference with some USB 3.0 devices
mouse_speed 4

# Scan for bootloaders
scanfor manual,external,optical,internal

# Enable loading drivers
scan_driver_dirs EFI/refind/drivers_x64

# Boot screen preferences
resolution 1920 1080
use_graphics_for linux,windows
"@
        $basicConfig | Out-File -FilePath "$efiRefindPath\refind.conf" -Encoding ASCII -Force
        Write-Log "Created basic configuration file" "Green"
    }
} catch {
    Write-Log "Warning: Could not set up configuration file: $_" "Yellow"
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