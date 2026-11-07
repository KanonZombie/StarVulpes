# Validación

## Extractor SPC precompilado

La extracción normal usa `tools/audio/ensure-spc-trace.ps1`: descarga la
versión y URL fijadas en `tools/audio/spc-trace.json` y verifica SHA-256.
`trace-score.py` vuelve a comprobar el ejecutable antes de ejecutarlo.
No se requieren Visual Studio ni fuentes de Snes9x. Procedimiento y
reconstrucción opcional en [SPC_TRACE.md](tools/audio/SPC_TRACE.md).

Validación de la versión 1.0.0:

- Descarga anónima real y reutilización del caché con la red bloqueada.
- Rechazo de un ejecutable existente corrupto y de una descarga con hash
  incorrecto. Eliminación de descargas parciales ante fallos de transporte.
- Dos compilaciones y reconstrucción desde el paquete de fuentes con
  ejecutables idénticos. Dependencia dinámica única: `KERNEL32.dll`.
- Tema con loop y créditos completos: trazas idénticas al extractor anterior,
  incluidos los tiempos de retorno y finalización.
- Los 227 contextos de trazas coinciden con la extracción anterior.
  `./rebuild.ps1 -KeepIntermediates`, con solo la ROM comercial en `ref/`
  y sin `MEGASVP_SPC_CORE` válido, produce la misma ROM de 2.097.152 bytes,
  checksum `$2128` y SHA-256 indicado al final de este documento.
- `trace-score.py` rechaza también un ejecutable sustituido después de la
  descarga. Las comprobaciones de audio pasan: 35 bancos, 52 secuencias
  musicales y 50 efectos recuperados.
- El rebuild normal desde Windows PowerShell 5.1, que se relanza con
  PowerShell 7, produce la misma ROM y deja únicamente `StarVulpes.bin`
  en `build/`. Se probó también con una configuración antigua que apunta
  `MEGASVP_SPC_CORE` a un directorio inexistente: ya no es una dependencia.

## Compilación y audio

Compila con `./rebuild.ps1 -KeepIntermediates` para conservar los archivos
de diagnóstico que usan estas comprobaciones. El
ensamblador comprueba las firmas SVP, el vector de reset y la correspondencia
de las 52 copias SSP y las 78 fuentes del fork gráfico. El integrador comprueba
la ubicación y los hashes de los recursos de audio dentro de la ROM de 2 MiB.

```powershell
./.venv/Scripts/python.exe tools/audio/check-mdsdrv-effects.py
```

La comprobación espera una ROM compilada con el catálogo por defecto.
Ejecuta el host y el driver compilados. Comprueba los 35 bancos, los 52
comandos de referencia con sus límites de reproducción y la prioridad
de efectos sobre música. Los 113 bloques PCM de efectos coinciden con
el hash de referencia.

Para recorrer intro, título y Corneria en BizHawk 2.9.1 con Genesis Plus GX,
configura `-BizHawk` con la ruta a `EmuHawk.exe`.

```powershell
$env:MEGASVP_MDS_PLAY = '1'
$env:MEGASVP_MDS_FIRE = '1'
./tools/audio/check-playback.ps1 -BizHawk 'C:/emu/BizHawk/EmuHawk.exe' `
    -Lua (Join-Path $PWD 'tools/audio/mdsdrv-playback.lua') -Frames 7000
```

Comprueba `video_error=0`, `sound_ready=1`, `corneria=true` y
`sfx_played` positivo en `build/audio-native/playback/state.txt`.
`scramble_music_frames` y `corneria_music_frames` deben ser positivos.

La compilación comprobada produjo una ROM de 2.097.152 bytes con checksum
`$2128` y SHA-256
`01187ed048d245f579f49cd912f6da35cec6a91aec20b077a98844c092bcbf80`.
BizHawk llegó a Corneria con vídeo y audio activos y reprodujo 204 efectos.
