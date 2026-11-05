# Validación

Compila con `./rebuild.ps1` siguiendo el [README](README.md). El
ensamblador comprueba las firmas SVP, el vector de reset y la correspondencia
de las 52 copias SSP y las 78 fuentes del fork gráfico. El integrador comprueba
la ubicación y los hashes de los recursos de audio dentro de la ROM de 2 MiB.

```powershell
./.venv/Scripts/python.exe tools/audio/check-mdsdrv-effects.py
```

La comprobación ejecuta el host y el driver compilados, prueba las 35 rutas
de bancos y la prioridad de efectos sobre música. Los 113 bloques PCM de
efectos coinciden con el hash de referencia.

Para recorrer intro, título y Corneria en BizHawk 2.9.1 con Genesis Plus GX,
configura `-BizHawk` con la ruta a `EmuHawk.exe`.

```powershell
$env:MEGASVP_MDS_PLAY = '1'
$env:MEGASVP_MDS_FIRE = '1'
./tools/audio/check-playback.ps1 -BizHawk 'C:/emu/BizHawk/EmuHawk.exe' `
    -Lua (Join-Path $PWD 'tools/audio/mdsdrv-playback.lua') -Frames 4800
```

Comprueba `video_error=0`, `sound_ready=1`, `corneria=true` y
`sfx_played` positivo en `build/audio-native/playback/state.txt`.

La compilación comprobada produjo SHA-256
`4b4410b9f3fb03bb1ca631d912e47ad39f5fe9beadc6346b8806d6de47a07832`.
La prueba en BizHawk alcanzó Corneria con audio y vídeo activos y registró
50 efectos reproducidos de 50 solicitudes.
