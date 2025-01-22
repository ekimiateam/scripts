[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$IsoUrl = "https://mirrors.ircam.fr/pub/zorinos-isos/17/Zorin-OS-17.2-Core-64-bit.iso",
    [switch]$Revert,
    [string]$LocalIso
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Status($Message) {
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

function Invoke-Revert {
    Write-Status "Starting revert process..."
    
    try {
        # Remove ISO file if it exists
        $isoFile = Join-Path $PSScriptRoot "libertix.iso"
        if (Test-Path $isoFile) {
            Write-Status "Removing leftover ISO file..."
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
            Write-Status "No LIBERTIX partition found. Nothing to revert."
            return
        }

        $diskNumber = $libertixPartition.DiskNumber
        Remove-Partition -DiskNumber $diskNumber -PartitionNumber $libertixPartition.PartitionNumber -Confirm:$false

        $maxSize = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
        Resize-Partition -DriveLetter C -Size $maxSize

        Write-Status "Revert completed successfully. LIBERTIX partition removed and C: drive extended."
    }
    catch {
        Write-Error "Failed to revert changes: $_"
        throw
    }
}

function Get-IsoFile {
    param($Url, $OutFile, $ExpectedSize)

    try {
        if (Test-Path $OutFile) {
            $existingFile = Get-Item $OutFile
            if ($existingFile.Length -eq $ExpectedSize) {
                Write-Status "ISO file already exists and size matches. Skipping download..."
                return
            }
            Write-Status "Existing ISO has wrong size. Downloading..."
        }

        Write-Status "Starting download from $Url"
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

        Start-Sleep -Seconds 2  # Wait for drive letter assignment
        $volume = $newPartition | Get-Volume
        if (-not $volume.DriveLetter) {
            throw "New partition has no drive letter assigned"
        }
        
        Format-Volume -DriveLetter $volume.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "LIBERTIX" -Force
        return $volume.DriveLetter
    }
    catch {
        Write-Status "Initial attempt to create partition failed. Retrying..."
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

            Start-Sleep -Seconds 2  # Wait for drive letter assignment
            $volume = $newPartition | Get-Volume
            if (-not $volume.DriveLetter) {
                throw "New partition has no drive letter assigned"
            }
            
            Format-Volume -DriveLetter $volume.DriveLetter -FileSystem FAT32 -NewFileSystemLabel "LIBERTIX" -Force
            return $volume.DriveLetter
        }
        catch {
            Write-Status "Second attempt also failed. Reverting changes..."
            Invoke-Revert
            throw
        }
    }
}

function Get-DriveLetter {
    param($Volume)
    
    # Wait for drive letter assignment
    $attempts = 0
    $maxAttempts = 10
    
    while ($attempts -lt $maxAttempts) {
        try {
            $letter = ($Volume | Get-Volume).DriveLetter
            if ($letter -and $letter -match '^[A-Z]$') {
                return $letter
            }
        } catch {
            Write-Status "Retrying drive letter detection..."
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

# Main execution block
try {
    if ($Revert) {
        Invoke-Revert
        exit 0
    }

    # Check for and handle leftover ISO file
    $outFile = Join-Path $PSScriptRoot "libertix.iso"
    if ((Test-Path $outFile) -and (-not $IsoUrl)) {
        Write-Status "Removing leftover ISO file from previous run..."
        Remove-Item -Path $outFile -Force
    }

    $url = $IsoUrl
    $response = Invoke-WebRequest -Uri $url -Method Head
    $fileSize = [long]$response.Headers["Content-Length"]
    $requiredSpaceMB = [math]::Ceiling($fileSize / 1MB) + 500
    
    Write-Status "Required space: $requiredSpaceMB MB"
    
    $driveLetter = New-LibertixPartition -RequiredSpaceMB $requiredSpaceMB
    if (-not $driveLetter) {
        throw "Failed to get valid drive letter for new partition"
    }
    Write-Status "Created and formatted partition ${driveLetter}"

    if (-not $LocalIso) {
        Get-IsoFile -Url $url -OutFile $outFile -ExpectedSize $fileSize
    } else {
        Write-Status "Using local ISO file: $LocalIso"
        $outFile = $LocalIso
    }

    Write-Status "Mounting ISO and copying contents..."
    $mountResult = Mount-DiskImage -ImagePath $outFile -PassThru
    Start-Sleep -Seconds 2  # Give Windows time to register the mount
    
    try {
        $isoDrive = Get-DriveLetter -Volume ($mountResult | Get-Volume)
        if (-not $isoDrive) {
            throw "Failed to get ISO drive letter"
        }
        Write-Status "ISO mounted at ${isoDrive}:"

        # Get the LIBERTIX volume directly
        $libertixVolume = Get-Volume | Where-Object { $_.FileSystemLabel -eq "LIBERTIX" }
        if (-not $libertixVolume) {
            throw "Cannot find LIBERTIX volume"
        }
        
        $destDrive = $libertixVolume.DriveLetter
        if (-not $destDrive -or -not ($destDrive -match '^[A-Z]$')) {
            throw "Invalid destination drive letter: $destDrive"
        }
        Write-Status "Copying files to ${destDrive}:"

        $destPath = "${destDrive}:"
        if (-not (Test-Path "${isoDrive}:\")) {
            throw "Cannot access mounted ISO at ${isoDrive}:"
        }

        Copy-Item -Path "${isoDrive}:\*" -Destination $destPath -Recurse -Force -ErrorAction Stop
        Write-Status "Files copied successfully"

        $isEfiBoot = Test-EfiBootSupport -IsoDriveLetter $isoDrive
        if ($isEfiBoot) {
            Write-Status "Detected EFI boot support"
            $efiPath = Join-Path $destPath "EFI\BOOT"
            if (-not (Test-Path $efiPath)) {
                New-Item -ItemType Directory -Path $efiPath -Force | Out-Null
            }
            Copy-Item "${isoDrive}:\EFI\BOOT\bootx64.efi" -Destination $efiPath -Force
        } else {
            Write-Status "No EFI boot support detected, attempting legacy boot"
            $hasLegacyBoot = Copy-LegacyBootFiles -IsoDriveLetter $isoDrive -DestDriveLetter $destDrive
            if (-not $hasLegacyBoot) {
                Write-Warning "No boot files found. The partition might not be bootable."
            }
        }

        Write-Status "Process completed successfully. The system can now be booted from partition ${destDrive}"
    }
    finally {
        Write-Status "Dismounting ISO..."
        Dismount-DiskImage -ImagePath $outFile
    }
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}