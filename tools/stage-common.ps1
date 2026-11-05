# Shared by extract_sf.ps1, build.ps1 and tools/asm-private.ps1 (dot-sourced).
# No machine- or user-specific paths: tools are found through environment
# variables, the project folder or PATH.
$MegaSvpStarFoxSha256 = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'

# Machine-specific tool paths: megasvp.local.json at the project root (not in
# git; template megasvp.local.example.json). Each key is the MEGASVP_* variable
# of a tool; a variable already set in the environment wins. Relative paths
# start at the project root. The Python tools these scripts run inherit them.
$MegaSvpToolVariables = 'MEGASVP_PYTHON', 'MEGASVP_ASM68K', 'MEGASVP_FFMPEG', 'MEGASVP_MDSDRV', 'MEGASVP_SPC_CORE',
                        'MEGASVP_SJASM', 'MEGASVP_Z80EMU'
$megaSvpLocal = Join-Path (Split-Path -Parent $PSScriptRoot) 'megasvp.local.json'
if (Test-Path -LiteralPath $megaSvpLocal -PathType Leaf) {
    foreach ($entry in (Get-Content -LiteralPath $megaSvpLocal -Raw | ConvertFrom-Json).PSObject.Properties) {
        if ($entry.Name -notin $MegaSvpToolVariables) {
            throw "megasvp.local.json: clave desconocida $($entry.Name) (validas: $($MegaSvpToolVariables -join ', '))."
        }
        if ([Environment]::GetEnvironmentVariable($entry.Name)) { continue }
        $toolPath = [string]$entry.Value
        if (-not [IO.Path]::IsPathRooted($toolPath)) { $toolPath = Join-Path (Split-Path -Parent $PSScriptRoot) $toolPath }
        if (-not (Test-Path -LiteralPath $toolPath)) { throw "megasvp.local.json: $($entry.Name) no existe: $toolPath" }
        Set-Item -LiteralPath "Env:$($entry.Name)" -Value (Resolve-Path -LiteralPath $toolPath).Path
    }
}

# One stage at a time: both write build/. Released by the caller's `finally`
# (also when the script runs inside a long-lived interactive pwsh).
function Enter-MegaSvpBuildLock([string]$Root) {
    $path = (Resolve-Path -LiteralPath $Root).Path.ToUpperInvariant()
    $key = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($path)))
    $mutex = [Threading.Mutex]::new($false, "Local\MegaSVP-build-$key")
    try { $owned = $mutex.WaitOne([TimeSpan]::FromMinutes(20)) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { throw 'Otra etapa (extract_sf.ps1 o build.ps1) sigue en curso tras 20 min.' }
    return $mutex
}

# Hash of the extraction code: the scripts run by extract_sf.ps1, the stage
# modules tools/stages/*.py and, transitively, every tools/*.py they name
# ('x.py' / 'x-y.py' strings for runpy) or import (import cpu65816, ...).
# Probes, smoke tests and oracles are not part of it, nor is evidence/ (probes
# write their reports there). build.ps1 refuses build/ data extracted by other code.
function Get-MegaSvpExtractionInputs([string]$Root) {
    $tools = Join-Path $Root 'tools'
    $names = [regex]::Matches((Get-Content -LiteralPath (Join-Path $Root 'extract_sf.ps1') -Raw), "'([A-Za-z0-9_/-]+\.py)'") |
             ForEach-Object { $_.Groups[1].Value }
    $queue = [Collections.Generic.Queue[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($n in $names) { $queue.Enqueue((Join-Path $tools $n)) }
    $queue.Enqueue((Join-Path $tools 'audio/spc-trace.cpp'))
    $queue.Enqueue((Join-Path $tools 'audio/build-spc-trace.ps1'))
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $tools 'stages') -Filter '*.py' -File) { $queue.Enqueue($f.FullName) }
    while ($queue.Count) {
        $f = $queue.Dequeue()
        if (-not (Test-Path -LiteralPath $f -PathType Leaf) -or -not $seen.Add($f)) { continue }
        $text = Get-Content -LiteralPath $f -Raw
        foreach ($m in [regex]::Matches($text, "['""/]([A-Za-z0-9_-]+\.py)['""]")) { $queue.Enqueue((Join-Path $tools $m.Groups[1].Value)) }
        foreach ($m in [regex]::Matches($text, '(?m)^\s*(?:import|from)\s+([A-Za-z0-9_]+)')) {
            foreach ($cand in @("$($m.Groups[1].Value).py", ($m.Groups[1].Value -replace '_', '-') + '.py')) {
                $queue.Enqueue((Join-Path $tools $cand))
                $queue.Enqueue((Join-Path (Split-Path -Parent $f) $cand))
            }
        }
    }
    [void]$seen.Add((Join-Path $Root 'extract_sf.ps1'))
    [void]$seen.Add((Join-Path $tools 'stage-common.ps1'))
    return @($seen | Sort-Object)
}

function Get-MegaSvpExtractionInputsHash([string]$Root) {
    $files = Get-MegaSvpExtractionInputs $Root | ForEach-Object { Get-Item -LiteralPath $_ }
    $lines = foreach ($f in $files) {
        [IO.Path]::GetRelativePath($Root, $f.FullName).Replace('\', '/') + ' ' + (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

# Python 3 with Pillow and NumPy for the extraction tools (standard library otherwise).
# Order: MEGASVP_PYTHON; the project environment .venv (tools/setup-python.ps1);
# the py launcher or python on PATH; the BizHawk environment of the repository.
function Resolve-MegaSvpPython([string]$Root) {
    $candidates = @()
    if ($env:MEGASVP_PYTHON) {
        if (-not (Test-Path -LiteralPath $env:MEGASVP_PYTHON -PathType Leaf)) { throw "MEGASVP_PYTHON no existe: $env:MEGASVP_PYTHON" }
        return (Resolve-Path -LiteralPath $env:MEGASVP_PYTHON).Path
    }
    $candidates += Join-Path $Root '.venv\Scripts\python.exe'
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($py) {
        $exe = & $py.Source -3 -c 'import sys; print(sys.executable)' 2>$null
        if ($LASTEXITCODE -eq 0 -and $exe) { $candidates += $exe.Trim() }
    }
    foreach ($name in 'python.exe', 'python3.exe') {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { $candidates += $cmd.Source }
    }
    $candidates += Join-Path $Root 'tools\emulator-mcp\.venv-local\Scripts\python.exe'
    foreach ($c in $candidates) {
        if (-not (Test-Path -LiteralPath $c -PathType Leaf)) { continue }
        & $c -c 'import sys, PIL, numpy; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>$null
        if ($LASTEXITCODE -eq 0) { return $c }
    }
    throw 'Falta Python 3.10+ con Pillow y NumPy. Ejecute tools/setup-python.ps1 o defina MEGASVP_PYTHON.'
}

# asm68k: -Asm68k / MEGASVP_ASM68K; asm68k.exe on PATH; ..\asmTools\asm68k.exe
# next to the project folder.
function Resolve-MegaSvpAsm68k([string]$Root, [string]$Requested) {
    $candidates = @()
    if ($Requested) { $candidates += $Requested }
    elseif ($env:MEGASVP_ASM68K) { $candidates += $env:MEGASVP_ASM68K }
    else {
        $cmd = Get-Command asm68k.exe -ErrorAction SilentlyContinue
        if ($cmd) { $candidates += $cmd.Source }
        $candidates += Join-Path (Split-Path -Parent $Root) 'asmTools\asm68k.exe'
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path }
    }
    throw 'Falta asm68k.exe. Use -Asm68k <ruta>, MEGASVP_ASM68K, el PATH o ..\asmTools\asm68k.exe junto al proyecto.'
}

# Genesis Plus GX / PicoDrive idle hacks for Virtua Racing (ssp16.c read_PM4): a PM4
# read returning 0 from the SSP instruction at byte $0854 or $4F12 parks the SSP until
# the 68000 writes DRAM 30FE08 / 30FE06, which this port never does (hang in BizHawk).
# Fails if a PM4-reading instruction starts at one of those addresses. Same decoding
# as tools/check-svp-genplus-idle.py: instruction starts walked from the nearest label.
function Test-MegaSvpGenplusIdle([byte[]]$Rom, [string]$ListingPath) {
    $labels = foreach ($line in [IO.File]::ReadLines($ListingPath, [Text.Encoding]::Latin1)) {
        if ($line -match '^([0-9A-F]{8})\s+([A-Za-z_]\w*):\s*$') {
            $a = [Convert]::ToInt32($Matches[1], 16)
            if ($a -lt 0x20000) { $a }
        }
    }
    $labels = @($labels | Sort-Object)
    $word = { param($at) ([int]$Rom[$at] -shl 8) -bor $Rom[$at + 1] }
    $twoWords = { param($op) $hi = $op -shr 9; ($hi -in 0x04, 0x06, 0x24, 0x26) -or ((($hi -band 0x0f) -eq 4) -and (($hi -band 0x70) -in 0x10, 0x30, 0x40, 0x50, 0x60, 0x70)) }
    $readsPm4 = {
        param($op) $hi = $op -shr 9
        if ($hi -eq 0) { return ($op -ne 0 -and $op -ne 0x37 -and ($op -band 0x0f) -eq 12) }
        if ($hi -in 0x02, 0x0a) { return ((($op -shr 4) -band 0x0f) -eq 12) }
        if ((($hi -band 0x0f) -eq 0) -and (($hi -band 0x70) -in 0x10, 0x30, 0x40, 0x50, 0x60, 0x70)) { return (($op -band 0x0f) -eq 12) }
        return $false
    }
    foreach ($hazard in 0x0854, 0x4F12) {
        $base = @($labels | Where-Object { $_ -le $hazard }) | Select-Object -Last 1
        if ($null -eq $base) { continue }
        $at = $base
        while ($at -lt $hazard) { $at += $(if (& $twoWords (& $word $at)) { 4 } else { 2 }) }
        if ($at -eq $hazard -and (& $readsPm4 (& $word $at))) {
            throw ('Una lectura de PM4 del SSP empieza en ${0:X4}: el atajo de Genesis Plus GX para Virtua Racing colgaria el SVP en BizHawk. Ajuste el codigo SVP (guarda de los generadores).' -f $hazard)
        }
    }
}
