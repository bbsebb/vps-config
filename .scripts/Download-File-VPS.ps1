<#
.SYNOPSIS
  Downloads a file from a VPS server using the 'vps' alias.
.DESCRIPTION
  This script utilizes the native Windows 'scp' command.
  It uses the 'Host vps' entry defined in the ~/.ssh/config file for authentication.
  The local destination is FIXED to C:\Users\bbseb\Downloads for simplified execution.
#>

# --- 1. Configuration of Alias and Paths ---
# The hostname must match the 'Host' line in your config file
$HostAlias = "vps"

# FIXED Local Destination Path.
$LocalPath = "C:\Users\bbseb\Downloads"

# --- 2. Request Remote File Path ---
$RemoteFilePath = Read-Host -Prompt "Enter the FULL path to the file on the VPS (Ex: /home/bbsebb/report.pdf)"

# --- Basic Validation ---
if ( [string]::IsNullOrWhiteSpace($RemoteFilePath))
{
    Write-Error "The remote path cannot be empty."
    exit 1
}

# --- 3. Construct and Display Operation ---
# Format: alias:remote/path
$Source = "$HostAlias`:$RemoteFilePath"

Write-Host "`nAttempting to download from [$HostAlias] : $RemoteFilePath" -ForegroundColor Cyan
Write-Host "FIXED Local Destination : $LocalPath`n" -ForegroundColor Yellow

## --- 4. Execute the SCP Command ---
try
{
    # Executes the SCP command using the configured alias
    scp $Source $LocalPath

    # Check the exit code ($LASTEXITCODE is used by external executables)
    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "`n✅ Success! The file has been copied to your Downloads folder: $LocalPath" -ForegroundColor Green
    }
    else
    {
        Write-Host "`n❌ SCP Transfer Failed. Error code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Check: 1. The file exists on the VPS. 2. The SSH key or passphrase is correct." -ForegroundColor Yellow
    }
}
catch
{
    Write-Host "`n❌ An unexpected error occurred during scp execution." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host "`nOperation completed."