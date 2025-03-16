# AWS Credentials and Config File Update Script
param (
    [switch]$Debug = $false
)

# Debug information output function
function Write-DebugInfo {
    param (
        [string]$Message
    )
    Write-Host "[DEBUG] $Message" -ForegroundColor Cyan
}

# Common processing function: Execute file update process
function Update-AwsFile {
    param (
        [string]$SourceDir,        # Source file directory
        [string]$FilePattern,      # Target file pattern (credentials.* or config.*)
        [string]$FileRegex,        # Filename regex pattern
        [string]$TmpFileName,      # Temporary filename
        [string]$TargetFile,       # Target file path (.aws/credentials or .aws/config)
        [string]$BackupFile        # Backup filename
    )
    
    # Create temporary file in current directory
    # Use absolute path of current directory to avoid path issues
    $currentDir = (Get-Location).Path
    $tmpFilePath = Join-Path -Path $currentDir -ChildPath $TmpFileName
    
    if ($Debug) {
        Write-DebugInfo "Temporary file location: $tmpFilePath"
    }
    
    # Get files matching the specified pattern
    $files = Get-ChildItem -Path $SourceDir -Filter $FilePattern | 
             Where-Object { $_.Name -match $FileRegex } | 
             Sort-Object Name
    
    if ($files.Count -eq 0) {
        Write-Warning "No files matching pattern '$FilePattern' found in directory '$SourceDir'."
        return $false
    }

    if ($Debug) {
        Write-DebugInfo "Found $($files.Count) files (pattern: $FilePattern):"
        $files | ForEach-Object { Write-DebugInfo "  - $($_.FullName)" }
    }

    # Combine files in sorted order and create temporary file (preserving line endings)
    try {
        # Remove existing temporary file if it exists
        if (Test-Path -Path $tmpFilePath) {
            Remove-Item -Path $tmpFilePath -Force
            if ($Debug) {
                Write-DebugInfo "Deleted existing temporary file: $tmpFilePath"
            }
        }
        
        $outStream = [System.IO.File]::Create($tmpFilePath)
        
        foreach ($file in $files) {
            if ($Debug) {
                Write-DebugInfo "Merging file: $($file.FullName)"
            }
            
            try {
                $inStream = [System.IO.File]::OpenRead($file.FullName)
                try {
                    $inStream.CopyTo($outStream)
                }
                finally {
                    if ($inStream -ne $null) {
                        $inStream.Close()
                        $inStream.Dispose()
                    }
                }
            }
            catch {
                Write-Error "Error reading file '$($file.FullName)': $_"
                if ($outStream -ne $null) {
                    $outStream.Close()
                    $outStream.Dispose()
                }
                Remove-Item -Path $tmpFilePath -Force -ErrorAction SilentlyContinue
                return $false
            }
        }
    }
    catch {
        Write-Error "Error creating temporary file: $_"
        return $false
    }
    finally {
        if ($outStream -ne $null) {
            $outStream.Close()
            $outStream.Dispose()
        }
    }

    if ($Debug) {
        Write-DebugInfo "Created temporary file: $tmpFilePath"
    }

    # Difference check flag
    $isDifferent = $false

    # Compare only if target file exists
    if (Test-Path -Path $TargetFile) {
        try {
            # Compare files in binary mode
            $existingBytes = [System.IO.File]::ReadAllBytes($TargetFile)
            $newBytes = [System.IO.File]::ReadAllBytes($tmpFilePath)
            
            # If file sizes differ, mark as different
            if ($existingBytes.Length -ne $newBytes.Length) {
                $isDifferent = $true
                if ($Debug) {
                    Write-DebugInfo "File sizes differ: existing=$($existingBytes.Length) bytes, new=$($newBytes.Length) bytes"
                }
            } else {
                # Compare byte by byte
                for ($i = 0; $i -lt $existingBytes.Length; $i++) {
                    if ($existingBytes[$i] -ne $newBytes[$i]) {
                        $isDifferent = $true
                        if ($Debug) {
                            Write-DebugInfo "Difference detected at byte position $i"
                        }
                        break
                    }
                }
            }
            
            # Show detailed differences in debug mode (load as text and compare line by line)
            if ($isDifferent -and $Debug) {
                Write-DebugInfo "Differences found with existing file (text comparison):"
                $existingLines = Get-Content -Path $TargetFile
                $newLines = Get-Content -Path $tmpFilePath
                $diff = Compare-Object -ReferenceObject $existingLines -DifferenceObject $newLines
                $diff | ForEach-Object {
                    if ($_.SideIndicator -eq "=>") {
                        Write-DebugInfo "  + $($_.InputObject)" -ForegroundColor Green
                    } else {
                        Write-DebugInfo "  - $($_.InputObject)" -ForegroundColor Red
                    }
                }
            }
        }
        catch {
            Write-Error "Error comparing files: $_"
            $isDifferent = $true  # Treat as different in case of error
            if ($Debug) {
                Write-DebugInfo "Treating as different due to error"
            }
        }
    } else {
        # If existing file doesn't exist, mark as different
        $isDifferent = $true
        if ($Debug) {
            Write-DebugInfo "Target file does not exist: $TargetFile"
        }
        
        # Create .aws directory if it doesn't exist
        $awsDir = Split-Path -Parent $TargetFile
        if (-not (Test-Path -Path $awsDir)) {
            if (-not $Debug) {
                New-Item -Path $awsDir -ItemType Directory -Force | Out-Null
                Write-Host "Created .aws directory: $awsDir"
            } else {
                Write-DebugInfo "[DEBUG MODE] Will create .aws directory: $awsDir"
            }
        }
    }

    # If no differences, delete temporary file and exit
    if (-not $isDifferent) {
        Write-Host "No differences found with existing $($FilePattern.Replace('*', '')) file. No update needed."
        Remove-Item -Path $tmpFilePath -Force
        return $false
    }

    # If differences exist, backup existing file
    if (Test-Path -Path $TargetFile) {
        if (-not $Debug) {
            try {
                # Copy in binary mode to preserve line endings
                [System.IO.File]::Copy($TargetFile, $BackupFile, $true)
                Write-Host "Backed up existing file to: $BackupFile"
            }
            catch {
                Write-Error "Error creating backup: $_"
                return $false
            }
        } else {
            Write-DebugInfo "[DEBUG MODE] Would backup existing file: $TargetFile -> $BackupFile"
        }
    }

    # Replace target file with temporary file
    if (-not $Debug) {
        try {
            # Copy in binary mode to preserve line endings
            [System.IO.File]::Copy($tmpFilePath, $TargetFile, $true)
            Write-Host "Successfully updated file: $TargetFile"
        }
        catch {
            Write-Error "Error updating file: $_"
            return $false
        }
    } else {
        Write-DebugInfo "[DEBUG MODE] Would apply temporary file to production: $tmpFilePath -> $TargetFile"
    }

    # Delete temporary file
    if (-not $Debug) {
        Remove-Item -Path $tmpFilePath -Force
    } else {
        Write-DebugInfo "[DEBUG MODE] Would delete temporary file: $tmpFilePath"
        Write-DebugInfo "Temporary file not deleted due to debug mode"
    }
    
    return $true
}

# Start main processing
if ($Debug) {
    Write-DebugInfo "Running in debug mode"
    $currentLocation = (Get-Location).Path
    Write-DebugInfo "Current working directory: $currentLocation"
}

# Processing counter
$updatedCount = 0

# AWS credentials file paths
$awsCredentialsPath = Join-Path -Path $HOME -ChildPath ".aws\credentials"
$awsConfigPath = Join-Path -Path $HOME -ChildPath ".aws\config"

if ($Debug) {
    Write-DebugInfo "AWS credentials path: $awsCredentialsPath"
    Write-DebugInfo "AWS config path: $awsConfigPath"
}

# Process files in credentials directory
$credentialsDir = ".\credentials"
if (Test-Path -Path $credentialsDir) {
    $credentialsDir = (Resolve-Path $credentialsDir).Path
    $credentialsBackup = Join-Path -Path (Split-Path -Path $awsCredentialsPath -Parent) -ChildPath "credentials.bak"
    
    if ($Debug) {
        Write-DebugInfo "Credentials directory: $credentialsDir"
        Write-DebugInfo "Backup path: $credentialsBackup"
    }
    
    $result = Update-AwsFile -SourceDir $credentialsDir `
                           -FilePattern "credentials.*" `
                           -FileRegex "credentials\.\d{4}-\d{2}\d{2}\..+" `
                           -TmpFileName "credentials.tmp" `
                           -TargetFile $awsCredentialsPath `
                           -BackupFile $credentialsBackup
    
    if ($result) {
        $updatedCount++
    }
} else {
    Write-Warning "Credentials directory not found: $credentialsDir"
}

# Process files in configs directory
$configsDir = ".\configs"
if (Test-Path -Path $configsDir) {
    $configsDir = (Resolve-Path $configsDir).Path
    $configBackup = Join-Path -Path (Split-Path -Path $awsConfigPath -Parent) -ChildPath "config.bak"
    
    if ($Debug) {
        Write-DebugInfo "Config directory: $configsDir"
        Write-DebugInfo "Backup path: $configBackup"
    }
    
    $result = Update-AwsFile -SourceDir $configsDir `
                           -FilePattern "config.*" `
                           -FileRegex "config\.\d{4}-\d{2}\d{2}\..+" `
                           -TmpFileName "config.tmp" `
                           -TargetFile $awsConfigPath `
                           -BackupFile $configBackup
    
    if ($result) {
        $updatedCount++
    }
} else {
    Write-Warning "Configs directory not found: $configsDir"
}

# Output results
if ($Debug) {
    Write-DebugInfo "Completed debug mode run - no actual changes were made"
} else {
    if ($updatedCount -gt 0) {
        Write-Host "Process completed: $updatedCount file(s) updated"
    } else {
        Write-Host "Process completed: No updates were made"
    }
}
exit 0