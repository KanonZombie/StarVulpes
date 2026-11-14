# Validación

## Auditoría SNES/MD del 13 y 14 de noviembre de 2026

- Entrada y persistencia del jugador. 93 comparaciones de 19 entradas,
  reinicios, CONTINUE y datos entre etapas. Arranque y vuelo de Corneria
  y entrenamiento probados mediante el mando en BizHawk 2.9.1.
- Modelos y geometría SVP. 96 cabeceras recuperadas. Validación de
  470 modelos y 940 poses, con límites ampliados de vértices y visibilidad.
- Estrategias. 929 comparaciones, incluidos los modos de salida y los
  disparos de la mina de Venom. Los tres guiones de salida ensayados
  devuelven el control al mapa.
- Paletas y fondos. 106.396 comparaciones, 33 fondos, 24.354 colores
  CPU/SVP y 205 matrices de estrellas contrastadas con la ROM original.

Estas pruebas de correspondencia y emulación se ejecutaron durante el
desarrollo. La validación en Nomad sigue pendiente.

## Extractor SPC precompilado

La extracción usa `tools/audio/spc-trace.exe`, incluido en el checkout.
`ensure-spc-trace.ps1` y `trace-score.py` verifican el SHA-256 fijado en
`tools/audio/spc-trace.json` antes de ejecutarlo. No descargan herramientas
ni requieren Visual Studio o fuentes externas de Snes9x. Reconstrucción
opcional y atribuciones en [SPC_TRACE.md](tools/audio/SPC_TRACE.md).

Validación del extractor 1.0.0:

- Verificación sin red del ejecutable incluido. Archivos ausentes o corruptos
  se rechazan sin descargar ni compilar alternativas. `trace-score.py`
  también comprueba el ejecutable antes de ejecutarlo.
- Las diez unidades SMP incluidas coinciden con la revisión upstream
  registrada y excluyen `iplrom.cpp`. Reconstrucción del ejecutable idéntica
  con el toolchain registrado. Única DLL importada: `KERNEL32.dll`.
- Los 227 contextos de trazas coinciden con la extracción anterior,
  incluidos los loops y el final de los créditos. Audio: 35 bancos,
  52 secuencias musicales y 50 efectos recuperados sin cambios.
- El rebuild normal funciona con las llamadas web de PowerShell bloqueadas
  y deja únicamente `StarVulpes.bin` en `build/`. La validación inicial
  del cambio de extractor produjo una ROM de 2.097.152 bytes con checksum
  `$2128` y SHA-256
  `01187ed048d245f579f49cd912f6da35cec6a91aec20b077a98844c092bcbf80`.
- Una configuración antigua con `MEGASVP_SPC_CORE` apuntando a un directorio
  inexistente ya no bloquea las etapas normales.

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

La ROM de referencia para los cuatro lotes tiene 2.097.152 bytes, checksum
`$946D` y SHA-256
`726ae9fb0f1f1761dc56d7f6550cd54b23c082c0c6acdfde7fb15d0360ecd53c`.
