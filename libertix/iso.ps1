[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$IsoUrl = "https://mirrors.ircam.fr/pub/zorinos-isos/17/Zorin-OS-17.2-Core-64-bit.iso",
    [switch]$Revert
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Status($Message) {
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

function Invoke-Revert {
    Write-Status "Starting revert process..."
    
    try {
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
        Write-Status "Failed to create partition: $_"
        Write-Status "Attempting to restore C: drive..."
        try {
            $supportedSize = Get-PartitionSupportedSize -DriveLetter C
            if ($windowsPartition.Size -lt $supportedSize.SizeMax) {
                Resize-Partition -DriveLetter C -Size $supportedSize.SizeMax
            }
        } catch {
            Write-Status "Warning: Failed to restore C: drive size"
        }
        throw
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

# Main execution block
try {
    if ($Revert) {
        Invoke-Revert
        exit 0
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

    $outFile = Join-Path $PSScriptRoot "libertix.iso"
    Get-IsoFile -Url $url -OutFile $outFile -ExpectedSize $fileSize

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

        $efiPath = Join-Path $destPath "EFI\BOOT"
        if (-not (Test-Path $efiPath)) {
            New-Item -ItemType Directory -Path $efiPath -Force | Out-Null
        }

        if (Test-Path "${isoDrive}:\EFI\BOOT\bootx64.efi") {
            Copy-Item "${isoDrive}:\EFI\BOOT\bootx64.efi" -Destination $efiPath -Force
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