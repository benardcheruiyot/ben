param(
    [string]$ServerHost = "69.169.97.136",
    [string]$User = "ubuntu",
    [string]$KeyPath = "",
    [string]$Domain = "kopa.mkopaji.com",
    [string]$WwwDomain = "www.kopa.mkopaji.com",
    [string]$Email = "admin@kopa.mkopaji.com"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localFixScript = Join-Path $scriptDir "fix_mkopaji_www_tls_noninteractive.sh"

if (-not (Test-Path $localFixScript)) {
    throw "Missing script: $localFixScript"
}

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    throw "ssh client is not available. Install OpenSSH client first."
}

if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    throw "scp client is not available. Install OpenSSH client first."
}

$remote = "$User@$ServerHost"
$remoteScriptPath = "/tmp/fix_mkopaji_www_tls_noninteractive.sh"
$sshArgs = @("-o", "StrictHostKeyChecking=accept-new")

if ($KeyPath -and $KeyPath.Trim().Length -gt 0) {
    if (-not (Test-Path $KeyPath)) {
        throw "SSH key not found at: $KeyPath"
    }
    $sshArgs += @("-i", $KeyPath)
} else {
    Write-Host "No key path provided. Using default SSH agent/config." -ForegroundColor Yellow
}

Write-Host "==> Uploading TLS fix script to $remote" -ForegroundColor Cyan
& scp @sshArgs $localFixScript "$remote`:$remoteScriptPath"

Write-Host "==> Executing TLS fix script on server" -ForegroundColor Cyan
& ssh @sshArgs $remote "chmod +x $remoteScriptPath && sudo DOMAIN='$Domain' WWW='$WwwDomain' EMAIL='$Email' bash $remoteScriptPath"

Write-Host "==> Verifying HTTPS endpoint" -ForegroundColor Cyan
& ssh @sshArgs $remote "curl -I --max-time 15 https://$Domain || true"

Write-Host "TLS automation completed." -ForegroundColor Green
