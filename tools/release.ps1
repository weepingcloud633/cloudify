# Publish a new Cloudify version that every installed copy picks up by itself.
#   powershell -File tools\release.ps1 -Version 0.16.0 -Notes "What changed"
# Needs: the GitHub CLI (gh, signed in) and a repository named in src\update.rs (REPO).
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Notes = "",
    [switch]$NoPublish
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot)
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3" }
$comma = $Version.Replace('.', ',') + ',0'

# bump the version everywhere it lives
(Get-Content Cargo.toml -Raw) -replace '(?m)^version = "[^"]+"', "version = `"$Version`"" | Set-Content Cargo.toml -NoNewline -Encoding utf8
(Get-Content installer\cloud-music.iss -Raw) -replace '#define AppVersion "[^"]+"', "#define AppVersion `"$Version`"" | Set-Content installer\cloud-music.iss -NoNewline -Encoding utf8
$rc = Get-Content assets\app.rc -Raw
$rc = $rc -replace 'FILEVERSION [\d,]+', "FILEVERSION $comma" -replace 'PRODUCTVERSION [\d,]+', "PRODUCTVERSION $comma"
$rc = $rc -replace '(VALUE "FileVersion", ")[^"]+', "`${1}$Version" -replace '(VALUE "ProductVersion", ")[^"]+', "`${1}$Version"
Set-Content assets\app.rc $rc -NoNewline -Encoding utf8

# build, stage and compile the installer
& powershell -File tools\stage.ps1
$iscc = @("$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup 6 was not found" }
& $iscc installer\cloud-music.iss | Out-Null
$exe = "dist\Cloudify-Setup-$Version.exe"
if (-not (Test-Path $exe)) { throw "The installer was not built" }

# the checksum the app verifies before it runs the download
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
"$hash  Cloudify-Setup-$Version.exe" | Set-Content "$exe.sha256" -Encoding ascii
"built $exe  sha256 $hash"

if ($NoPublish) { "Not published (-NoPublish)."; return }
if (-not $Notes) { $Notes = "Cloudify $Version" }
gh release create "v$Version" $exe "$exe.sha256" --title "Cloudify $Version" --notes $Notes
"Published v$Version. Installed copies will offer it on their next start."
