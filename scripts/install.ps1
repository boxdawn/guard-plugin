# SessionStart on Windows: put the guard build at
# $env:CLAUDE_PLUGIN_DATA\current\bdxguard.exe (see install.sh). Downloaded
# once per version from the boxdawn/guard GitHub release named below and used
# only if its sha256 matches the value pinned here. Uses the curl.exe and
# tar.exe that ship with Windows 10 and later.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { exit 0 }

$Version = '0.4.8'
$Build = '55ad13102e02188d07e8f73559a2a0f7484c9dda'
$Sum = 'be27ef02245801ccdd23affd8d0f3fbf6c830e01887026cec3c53577c2591a38'

# Windows on Arm runs the x64 build under emulation.
if ($env:PROCESSOR_ARCHITECTURE -notin @('AMD64', 'ARM64')) {
    [Console]::Error.WriteLine("boxdawn guard: no build for $env:PROCESSOR_ARCHITECTURE"); exit 1
}
$data = $env:CLAUDE_PLUGIN_DATA
$dst = Join-Path $data 'current'
$dstId = Join-Path $dst 'BUILD_ID'
$installed = (Test-Path $dstId) -and ((Get-Content -Raw $dstId).Trim() -eq $Build)
if (-not $installed) {
    New-Item -ItemType Directory -Force $data | Out-Null
    $tmp = Join-Path $data "download.$PID"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        $archive = Join-Path $tmp 'build.tar.gz'
        $url = "https://github.com/boxdawn/guard/releases/download/v$Version/bdxguard-windows-x64.tar.gz"
        & "$env:SystemRoot\System32\curl.exe" -fsSL --proto '=https' --tlsv1.2 --retry 2 -o $archive $url
        if ($LASTEXITCODE -ne 0) { throw "download failed ($LASTEXITCODE)" }
        if ((Get-FileHash -Algorithm SHA256 $archive).Hash.ToLower() -ne $Sum) {
            throw 'downloaded build does not match its pinned sha256; not installed'
        }
        $unpacked = Join-Path $tmp 'build'
        New-Item -ItemType Directory $unpacked | Out-Null
        & "$env:SystemRoot\System32\tar.exe" -xzf $archive -C $unpacked
        if ($LASTEXITCODE -ne 0) { throw "unpack failed ($LASTEXITCODE)" }
        if ((Get-Content -Raw (Join-Path $unpacked 'BUILD_ID')).Trim() -ne $Build) { throw 'unexpected build id' }
        $old = "$dst.old"
        if (Test-Path $old) { Remove-Item -Recurse -Force $old }
        if (Test-Path $dst) { Move-Item $dst $old }
        Move-Item $unpacked $dst
        if (Test-Path $old) { Remove-Item -Recurse -Force $old }
    } catch {
        [Console]::Error.WriteLine("boxdawn guard: $($_.Exception.Message)"); exit 1
    } finally {
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    }
}

# With an API key in the plugin's settings, fetch the signed rules in the
# background (the session does not wait). Without one this opens no connection.
if ($env:CLAUDE_PLUGIN_OPTION_API_KEY) {
    Start-Process -FilePath (Join-Path $dst 'bdxguard.exe') -ArgumentList 'fetch-rules' -WindowStyle Hidden
}
