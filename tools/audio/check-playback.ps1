# Exercise the main ROM and dump audio with a project-local emulator config.
# Does not create a diagnostic ROM or change the user's emulator settings.
param([string]$BizHawk='C:\emu\BizHawk-2.9.1-win-x64\EmuHawk.exe',
      [string]$Rom='', [string]$Lua='', [string]$OutputDirectory='',
      [ValidateRange(1,60000)][int]$Frames=5000)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out=if ($OutputDirectory) { $OutputDirectory } else { Join-Path $root 'build/audio-native/playback' }
New-Item -ItemType Directory -Force $out | Out-Null
$config=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $BizHawk) 'config.ini') -Raw | ConvertFrom-Json
foreach ($entry in $config.PathEntries.Paths) { if ($entry.Type -eq 'Base') { $entry.Path=$out } }
$config.SingleInstanceMode=$false
$config.SoundEnabled=$false
$config.SaveWindowPosition=$false
$config.PreferredCores | Add-Member -NotePropertyName 'GEN' -NotePropertyValue 'Genplus-gx' -Force
$cfg=Join-Path $out 'config.ini'
$config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $cfg -Encoding utf8
$env:MEGASVP_AUDIO_PLAYBACK=$out.Replace('\','/')
$env:MEGASVP_AUDIO_FRAMES=[string]$Frames
if (-not $Rom) { $Rom=Join-Path $root 'build/megasvp-m4-intro.bin' }
if (-not $Lua) { $Lua=Join-Path $root 'tools/audio/release-playback.lua' }
$wav=Join-Path $out 'audio.wav'
foreach ($name in @('audio.wav','state.txt','driver-helpers.bin','host.ram')) {
    $previous=Join-Path $out $name
    if (Test-Path -LiteralPath $previous) { Remove-Item -LiteralPath $previous }
}
$arguments=@(('"--config={0}"' -f $cfg),('"--lua={0}"' -f $lua),'--dump-type=wave',('"--dump-name={0}"' -f $wav),('--dump-length={0}' -f ($Frames+1)),'--dump-close',('"{0}"' -f $rom))
$process=Start-Process -FilePath $BizHawk -ArgumentList $arguments -WorkingDirectory $out -WindowStyle Hidden -PassThru
$process.Id | Set-Content -LiteralPath (Join-Path $out 'pid.txt')
Write-Host "Audio playback validation PID $($process.Id); $out"
