[CmdletBinding()]
param(
    [switch]$Force = $false,
    [switch]$Revert = $false,
    [switch]$NoDownload = $false,
    [string]$IsoUrl = "https://mirrors.ircam.fr/pub/zorinos-isos/17/Zorin-OS-17.2-Core-64-bit.iso",
    [string]$LocalIso
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Invoke-Revert {
    Write-Log "Starting revert process..." "Cyan"
    
    try {
        $isoFile = Join-Path $PSScriptRoot "libertix.iso"
        if (Test-Path $isoFile) {
            Write-Log "Removing leftover ISO file..." "Cyan"
            Remove-Item -Path $isoFile -Force
        }

        $libertixPartition = Get-Partition | Where-Object { 
            try {
                $volume = $_ | Get-Volume -ErrorAction SilentlyContinue
                return $volume -and $volume.FileSystemLabel -eq "LIBERTIX"
            } catch {
                return $false
            }
        }

        if (-not $libertixPartition) {
            Write-Log "No LIBERTIX partition found. Nothing to revert." "Yellow"
            return
        }

        $diskNumber = $libertixPartition.DiskNumber
        Remove-Partition -DiskNumber $diskNumber -PartitionNumber $libertixPartition.PartitionNumber -Confirm:$false

        $maxSize = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
        Resize-Partition -DriveLetter C -Size $maxSize

        Write-Log "Revert completed successfully. LIBERTIX partition removed and C: drive extended." "Green"
    }
    catch {
        Write-Log "Failed to revert changes: $_" "Red"
        throw
    }
}

function Get-IsoFile {
    param($Url, $OutFile, $ExpectedSize)
    try {
        if (Test-Path $OutFile) {
            $existingFile = Get-Item $OutFile
            if ($existingFile.Length -eq $ExpectedSize) {
                Write-Log "ISO file already exists and size matches. Skipping download..." "Cyan"
                return
            }
            Write-Log "Existing ISO has wrong size. Downloading..." "Cyan"
        }

        Write-Log "Starting download from $Url" "Cyan"
        $job = Start-BitsTransfer -Source $Url -Destination $OutFile -DisplayName "ISO" -Asynchronous

        do {
            $progress = [math]::Round(($job.BytesTransferred / $job.BytesTotal) * 100, 2)
            Write-Progress -Activity "Downloading ISO" -Status "$progress% Complete" -PercentComplete $progress
            Start-Sleep -Seconds 1
        } while ($job.JobState -eq "Transferring" -or $job.JobState -eq "Connecting")

        if ($job.JobState -eq "Transferred") {
            Complete-BitsTransfer -BitsJob $job
            $downloadedFile = Get-Item $OutFile
            if ($downloadedFile.Length -ne $ExpectedSize) {
                throw "Download completed but file size mismatch. Expected: $ExpectedSize, Got: $($downloadedFile.Length)"
            }
        } else {
            $job | Remove-BitsTransfer
            throw "Download failed with status: $($job.JobState)"
        }
    }
    catch {
        if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
        throw
    }
}

function New-LibertixPartition {
    param($RequiredSpaceMB)
    try {
        $windowsPartition = Get-Partition -DriveLetter C
        $supportedSize = Get-PartitionSupportedSize -DriveLetter C
        $currentSize = $windowsPartition.Size
        $availableSpace = $currentSize - $supportedSize.SizeMin
        
        if ($availableSpace -lt ($RequiredSpaceMB * 1MB)) {
            throw "Not enough available space. Required: $RequiredSpaceMB MB, Available: $([math]::Floor($availableSpace / 1MB)) MB"
        }

        $newSizeBytes = $currentSize - ($RequiredSpaceMB * 1MB)
        if ($newSizeBytes -lt $supportedSize.SizeMin) {
            throw "Reducing partition would make it smaller than minimum size"
        }

        Resize-Partition -DriveLetter C -Size $newSizeBytes
        
        $disk = Get-Disk | Where-Object { $_.Path -eq $windowsPartition.DiskPath }
        $newPartition = New-Partition -DiskNumber $disk.Number -Size ($RequiredSpaceMB * 1MB) -AssignDriveLetter
        
        if (-not $newPartition) {
            throw "Failed to create new partition"
        }

        Start-Sleep -Seconds 2
        $volume = $newPartition | Get-Volume
        if (-not $volume.DriveLetter) {
            throw "New partition has no drive letter assigned"
        }
        
        Format-Volume -DriveLetter $volume.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "LIBERTIX" -Force
        return $volume.DriveLetter
    }
    catch {
        Write-Log "Initial attempt to create partition failed. Retrying..." "Yellow"
        Start-Sleep -Seconds 5

        try {
            $windowsPartition = Get-Partition -DriveLetter C
            $supportedSize = Get-PartitionSupportedSize -DriveLetter C
            $currentSize = $windowsPartition.Size
            $availableSpace = $currentSize - $supportedSize.SizeMin
            
            if ($availableSpace -lt ($RequiredSpaceMB * 1MB)) {
                throw "Not enough available space. Required: $RequiredSpaceMB MB, Available: $([math]::Floor($availableSpace / 1MB)) MB"
            }

            $newSizeBytes = $currentSize - ($RequiredSpaceMB * 1MB)
            if ($newSizeBytes -lt $supportedSize.SizeMin) {
                throw "Reducing partition would make it smaller than minimum size"
            }

            Resize-Partition -DriveLetter C -Size $newSizeBytes
            
            $disk = Get-Disk | Where-Object { $_.Path -eq $windowsPartition.DiskPath }
            $newPartition = New-Partition -DiskNumber $disk.Number -Size ($RequiredSpaceMB * 1MB) -AssignDriveLetter
            
            if (-not $newPartition) {
                throw "Failed to create new partition"
            }

            Start-Sleep -Seconds 2
            $volume = $newPartition | Get-Volume
            if (-not $volume.DriveLetter) {
                throw "New partition has no drive letter assigned"
            }
            
            Format-Volume -DriveLetter $volume.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "LIBERTIX" -Force
            return $volume.DriveLetter
        }
        catch {
            Write-Log "Second attempt also failed. Reverting changes..." "Red"
            Invoke-Revert
            throw
        }
    }
}

function Get-DriveLetter {
    param($Volume)
    $attempts = 0
    $maxAttempts = 10
    
    while ($attempts -lt $maxAttempts) {
        try {
            $letter = ($Volume | Get-Volume).DriveLetter
            if ($letter -and $letter -match '^[A-Z]$') {
                return $letter
            }
        } catch {
            Write-Log "Retrying drive letter detection..." "Yellow"
        }
        Start-Sleep -Seconds 1
        $attempts++
    }
    throw "Failed to get valid drive letter after $maxAttempts attempts"
}

function Test-EfiBootSupport {
    param($IsoDriveLetter)
    $efiPath = "${IsoDriveLetter}:\EFI\BOOT\bootx64.efi"
    return Test-Path $efiPath
}

function Copy-LegacyBootFiles {
    param($IsoDriveLetter, $DestDriveLetter)
    $bootPaths = @(
        "isolinux\isolinux.bin",
        "isolinux\",
        "syslinux\syslinux.bin",
        "syslinux\"
    )
    
    $foundBootFile = $false
    foreach ($path in $bootPaths) {
        $sourcePath = "${IsoDriveLetter}:\$path"
        if (Test-Path $sourcePath) {
            $destPath = "${DestDriveLetter}:\$path"
            
            if (-not (Test-Path (Split-Path $destPath))) {
                New-Item -ItemType Directory -Path (Split-Path $destPath) -Force | Out-Null
            }
            
            Copy-Item -Path $sourcePath -Destination $destPath -Force -Recurse
            $foundBootFile = $true
        }
    }
    
    return $foundBootFile
}

# Main execution flow
try {
    if ($Revert) {
        Invoke-Revert
        exit 0
    }

    # rEFInd Installation
    if (-not $Force) {
        $currentBootloader = bcdedit /enum firmware | Select-String "path.*\\EFI\\refind\\refind_x64\.efi"
        if ($currentBootloader) {
            Write-Log "rEFInd is already installed as the default bootloader." "Yellow"
            Write-Log "Use -Force parameter to reinstall anyway (e.g., '.\script.ps1 -Force')" "Yellow"
            exit 0
        }
    }

    $refindUrl = "https://freefr.dl.sourceforge.net/project/refind/0.14.2/refind-bin-0.14.2.zip"
    $downloadPath = Join-Path $PSScriptRoot "refind.zip"
    $extractPath = Join-Path $PSScriptRoot "refind"
    $efiPartition = "Z:"
    $efiRefindPath = "$efiPartition\EFI\refind"

    if (-not $NoDownload) {
        Write-Log "Downloading rEFInd..." "Cyan"
        try {
            Invoke-WebRequest -Uri $refindUrl -OutFile $downloadPath -ErrorAction Stop
        } catch {
            Write-Log "Error downloading rEFInd: $_" "Red"
            exit 1
        }
    }

    Write-Log "Extracting rEFInd..." "Cyan"
    try {
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force -ErrorAction Stop
    } catch {
        Write-Log "Error extracting rEFInd: $_" "Red"
        exit 1
    }

    $refindFolder = Get-ChildItem -Path $extractPath -Directory | Where-Object { $_.Name -like "refind*" } | Select-Object -First 1
    if (-not $refindFolder) {
        Write-Log "Error: Could not locate rEFInd folder in the extracted files." "Red"
        exit 1
    }

    Write-Log "Disabling Windows Fast Startup..." "Cyan"
    try {
        powercfg /h off
    } catch {
        Write-Log "Warning: Could not disable Fast Startup: $_" "Yellow"
    }

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

    Write-Log "Setting rEFInd as default boot manager..." "Cyan"
    try {
        bcdedit /set "{bootmgr}" path \EFI\refind\refind_x64.efi
        bcdedit /set "{bootmgr}" description "rEFInd Boot Manager"
    } catch {
        Write-Log "Error setting rEFInd as default boot manager: $_" "Red"
        exit 1
    }

    Write-Log "Cleaning up temporary files..." "Cyan"
    if (-not $NoDownload) {
        Remove-Item -Path $downloadPath -Force
    }
    Remove-Item -Path $extractPath -Recurse -Force

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

    Write-Log "rEFInd installation complete!" "Green"

    # ISO Setup
    $outFile = Join-Path $PSScriptRoot "libertix.iso"
    if ((Test-Path $outFile) -and (-not $IsoUrl)) {
        Write-Log "Removing leftover ISO file from previous run..." "Cyan"
        Remove-Item -Path $outFile -Force
    }

    $url = $IsoUrl
    $response = Invoke-WebRequest -Uri $url -Method Head
    $fileSize = [long]$response.Headers["Content-Length"]
    $requiredSpaceMB = [math]::Ceiling($fileSize / 1MB) + 500
    
    Write-Log "Required space: $requiredSpaceMB MB" "Cyan"
    
    $driveLetter = New-LibertixPartition -RequiredSpaceMB $requiredSpaceMB
    if (-not $driveLetter) {
        throw "Failed to get valid drive letter for new partition"
    }
    Write-Log "Created and formatted partition ${driveLetter}" "Green"

    if (-not $LocalIso) {
        Get-IsoFile -Url $url -OutFile $outFile -ExpectedSize $fileSize
    } else {
        Write-Log "Using local ISO file: $LocalIso" "Cyan"
        $outFile = $LocalIso
    }

    Write-Log "Mounting ISO and copying contents..." "Cyan"
    $mountResult = Mount-DiskImage -ImagePath $outFile -PassThru
    Start-Sleep -Seconds 2
    
    try {
        $isoDrive = Get-DriveLetter -Volume ($mountResult | Get-Volume)
        if (-not $isoDrive) {
            throw "Failed to get ISO drive letter"
        }
        Write-Log "ISO mounted at ${isoDrive}:" "Green"

        $libertixVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "LIBERTIX" }
        if (-not $libertixVolume) {
            throw "Cannot find LIBERTIX volume"
        }
        
        $destDrive = $libertixVolume.DriveLetter
        if (-not $destDrive -or -not ($destDrive -match '^[A-Z]$')) {
            throw "Invalid destination drive letter: $destDrive"
        }
        Write-Log "Copying files to ${destDrive}:" "Cyan"

        $destPath = "${destDrive}:"
        if (-not (Test-Path "${isoDrive}:\")) {
            throw "Cannot access mounted ISO at ${isoDrive}:"
        }

        Copy-Item -Path "${isoDrive}:\*" -Destination $destPath -Recurse -Force -ErrorAction Stop
        Write-Log "Files copied successfully" "Green"

        $isEfiBoot = Test-EfiBootSupport -IsoDriveLetter $isoDrive
        if ($isEfiBoot) {
            Write-Log "Detected EFI boot support" "Green"
            $efiPath = Join-Path $destPath "EFI\BOOT"
            if (-not (Test-Path $efiPath)) {
                New-Item -ItemType Directory -Path $efiPath -Force | Out-Null
            }
            Copy-Item "${isoDrive}:\EFI\BOOT\bootx64.efi" -Destination $efiPath -Force
        } else {
            Write-Log "No EFI boot support detected, attempting legacy boot" "Yellow"
            $hasLegacyBoot = Copy-LegacyBootFiles -IsoDriveLetter $isoDrive -DestDriveLetter $destDrive
            if (-not $hasLegacyBoot) {
                Write-Log "No boot files found. The partition might not be bootable." "Yellow"
            }
        }

        Write-Log "Process completed successfully. The system can now be booted from partition ${destDrive}" "Green"
    }
    finally {
        Write-Log "Dismounting ISO..." "Cyan"
        Dismount-DiskImage -ImagePath $outFile
    }
}
catch {
    Write-Log "Script failed: $_" "Red"
    exit 1
}