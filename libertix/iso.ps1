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
Write-Output "Created new partition with drive letter: $driveLetter"

# Format the new partition
Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -Force
Write-Output "Formatted partition ${driveLetter}"

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

# Define Win32 API functions
$code = @"
using System;
using System.Runtime.InteropServices;

public class DiskIO {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteFile(
        IntPtr hFile,
        byte[] lpBuffer,
        uint nNumberOfBytesToWrite,
        out uint lpNumberOfBytesWritten,
        IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hFile);
        
    public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);
}
"@
Add-Type -TypeDefinition $code

# Constants
$GENERIC_WRITE = 0x40000000
$FILE_SHARE_WRITE = 0x2
$OPEN_EXISTING = 3

$handle = [DiskIO]::CreateFile($volumePath, $GENERIC_WRITE, $FILE_SHARE_WRITE, [IntPtr]::Zero, $OPEN_EXISTING, 0, [IntPtr]::Zero)

if ($handle -eq [DiskIO]::INVALID_HANDLE_VALUE) {
    throw "Failed to open disk. Error code: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
}

try {
    $buffer = [System.IO.File]::ReadAllBytes($outFile)
    $bytesWritten = 0
    if (![DiskIO]::WriteFile($handle, $buffer, $buffer.Length, [ref]$bytesWritten, [IntPtr]::Zero)) {
        throw "Failed to write to disk. Error code: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    
    if ($bytesWritten -ne $buffer.Length) {
        throw "Failed to write all bytes. Written: $bytesWritten, Expected: $($buffer.Length)"
    }
} finally {
    if ($handle -ne [DiskIO]::INVALID_HANDLE_VALUE) {
        [DiskIO]::CloseHandle($handle)
    }
}

Write-Output "ISO successfully written to partition ${driveLetter}"
Write-Output "Process completed. The system can now be booted from partition ${driveLetter}"