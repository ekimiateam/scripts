$url = "https://mirrors.gandi.net/archlinux/iso/2025.01.01/archlinux-2025.01.01-x86_64.iso"
$response = Invoke-WebRequest -Uri $url -Method Head
$fileSize = $response.Headers["Content-Length"]
Write-Output "File size: $fileSize bytes"
$requiredSpaceMB = [math]::Ceiling($fileSize / 1MB) + 500
$windowsPartition = Get-Partition -DriveLetter C
$newSizeBytes = $windowsPartition.Size - ($requiredSpaceMB * 1MB)
Resize-Partition -DriveLetter C -Size $newSizeBytes

Write-Output "Partition resized. Reserved space: $requiredSpaceMB MB"

# Create the new partition in the freed space
$disk = Get-Disk | Where-Object { $_.Path -eq $windowsPartition.DiskPath }
$newPartition = New-Partition -DiskNumber $disk.Number -Size ($requiredSpaceMB * 1MB) -AssignDriveLetter
$driveLetter = $newPartition.DriveLetter

# Change partition type to ESP
$partitionGUID = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" # EFI System Partition GUID
$newPartition | Set-Partition -GptType $partitionGUID

# Format as FAT32 instead of NTFS
Format-Volume -DriveLetter $driveLetter -FileSystem FAT32 -Force
Write-Output "Formatted partition ${driveLetter} as FAT32 EFI System Partition"

$outFile = Join-Path $PSScriptRoot "archlinux.iso"
if (Test-Path $outFile) {
    $existingFile = Get-Item $outFile
    if ($existingFile.Length -eq $fileSize) {
        Write-Output "ISO file already exists and size matches. Skipping download..."
    } else {
        Write-Output "Existing ISO has wrong size. Downloading..."
        Write-Output "Downloading ISO..."
        $job = Start-BitsTransfer -Source $url -Destination $outFile -DisplayName "Arch Linux ISO" -Asynchronous
        do {
            $progress = [math]::Round(($job.BytesTransferred / $job.BytesTotal) * 100, 2)
            Write-Progress -Activity "Downloading Arch Linux ISO" -Status "$progress% Complete" -PercentComplete $progress
            Start-Sleep -Seconds 1
        } while ($job.JobState -eq "Transferring" -or $job.JobState -eq "Connecting")

        Complete-BitsTransfer -BitsJob $job
        Write-Output "Download complete"
    }
} else {
    Write-Output "Downloading ISO..."
    $job = Start-BitsTransfer -Source $url -Destination $outFile -DisplayName "Arch Linux ISO" -Asynchronous
    do {
        $progress = [math]::Round(($job.BytesTransferred / $job.BytesTotal) * 100, 2)
        Write-Progress -Activity "Downloading Arch Linux ISO" -Status "$progress% Complete" -PercentComplete $progress
        Start-Sleep -Seconds 1
    } while ($job.JobState -eq "Transferring" -or $job.JobState -eq "Connecting")

    Complete-BitsTransfer -BitsJob $job
    Write-Output "Download complete"
}

Write-Output "Writing ISO to partition ${driveLetter}..."

# Download and extract dd if not present
$ddPath = Join-Path $PSScriptRoot "dd.exe"
if (-not (Test-Path $ddPath)) {
    $ddZipUrl = "http://www.chrysocome.net/downloads/bf8163783362fa7d5f9b5a2bd0e3a2de/dd-0.5.zip"
    $ddZipPath = Join-Path $PSScriptRoot "dd.zip"
    Invoke-WebRequest -Uri $ddZipUrl -OutFile $ddZipPath
    Expand-Archive -Path $ddZipPath -DestinationPath $PSScriptRoot
    Remove-Item $ddZipPath
}

# Write ISO to partition using dd
$volumePath = "\\.\${driveLetter}:"
& $ddPath if="$outFile" of="$volumePath" bs=4M --progress

if ($LASTEXITCODE -eq 0) {
    Write-Output "ISO successfully written to partition ${driveLetter}"
    Write-Output "Process completed. The system can now be booted from partition ${driveLetter}"
    Set-Volume -DriveLetter $driveLetter -NewFileSystemLabel "ARCHISO"
    Write-Output "Partition labeled as ARCHISO for rEFInd detection"

    $refindConf = "C:\EFI\refind\refind.conf"
    if (Test-Path $refindConf) {
        Add-Content $refindConf @"
menuentry "Arch ISO (ARCHISO)" {
    volume  "ARCHISO"
    loader  \EFI\boot\bootx64.efi
    icon    \EFI\refind\icons\os_arch.png
}
"@
        Write-Output "Added Arch ISO entry to rEFInd config."
    } else {
        Write-Output "rEFInd config not found. Please add an entry manually."
    }
} else {
    throw "Failed to write ISO to partition. dd exit code: $LASTEXITCODE"
}