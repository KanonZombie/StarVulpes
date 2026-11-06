# Música de StarVulpes

El catálogo por defecto se genera en `build/mdsdrv/` a partir de la ROM
de Star Fox que aporta cada desarrollador. `tools/audio/mdsdrv-content.py`
convierte a MML 50 temas y dos variantes de comandos. Extrae las notas, sus
duraciones y los puntos de retorno del SPC, con su percusión BRR.
Los timbres melódicos FM/PSG son aproximaciones. La altura y el volumen
se toman al inicio de cada nota, por lo que los deslizamientos, la
automatización de volumen y el panorama pueden diferir del original.
El banco compilado también incluye los efectos y las voces.

## Compilar con tus MML

1. Pon los `.mml` y sus WAV en `music/local/`, con las rutas relativas de las
   muestras intactas. También puedes apuntar a MML que ya tengas en otro lugar.
2. Crea `music/local/tracks.json` con los temas que quieres reemplazar.
   Las rutas de los MML son relativas a este JSON. Las rutas de cada WAV son
   relativas a su MML.

   ```json
   {
     "pcm_rate": 2187,
     "tracks": {
       "07": "Meteor.mml",
       "18": "Boss (Meteor).mml"
     }
   }
   ```

3. Desde la raíz del proyecto, en PowerShell 7, ejecuta el build con la lista.

   ```powershell
   ./rebuild.ps1 -MusicManifest ./music/local/tracks.json
   ```

   En el repositorio público, la salida es `build/StarVulpes.bin`. Para
   reutilizar una extracción vigente, usa `./build.ps1` con el mismo
   parámetro. Ejecutar el build sin `-MusicManifest` vuelve al catálogo por
   defecto. Git ignora `music/local/` y `build/`.

## Identificadores de temas

Son los IDs del catálogo, compartidos entre los bancos que reproducen el
mismo tema. La lista completa sigue el orden de `ORIGINS` y sus ajustes.
[Catálogo](../tools/audio/spc_score.py) · [Resolución de temas](../tools/audio/mdsdrv-content.py)

| ID | Tema |
| --- | --- |
| `01` | Intro |
| `02` | Pantalla de título |
| `03` | Controles |
| `04` | Mapa de ruta |
| `05` | Despegue de Corneria |
| `06` | Corneria |
| `07` | Battle Base Meteor |
| `11` | Asteroid Belt y Venom orbital |
| `12` | Space Armada |
| `16` | Venom en superficie, rutas 1 y 3 |
| `17` | Jefe de Corneria |
| `18` | Jefe de Meteor |
| `22` | Jefe de Asteroid Belt |
| `23` | Jefe de Space Armada |
| `27` | Phantron tras la transformación, con su entrada propia |
| `28` | Andross |
| `34` | Fanfarria de fin de etapa |
| `37` | Ending |
| `38` | Tema principal de los créditos, incluido su cierre |
| `52` | Entrada de salto en el banco de Asteroid Belt |
| `53` | Variante de aviso de secreto del banco 15 |

El ID `47` corresponde al cierre que ya forma parte del tema finito `38`.
El manifiesto generado lista los comandos, la duración y el punto de
retorno de cada secuencia recuperada.

## Formato y presupuesto

- Usa MML de ctrmml con `#platform mdsdrv`. El build conserva el tempo,
  los instrumentos y los bucles definidos por el tema. Pon `L` en el punto
  de retorno de cada pista que repite y alinea el final de esas pistas.
  Los temas finitos terminan al llegar al final del MML.
  [Referencia de ctrmml](https://github.com/superctr/ctrmml/blob/master/mml_ref.md)
- Usa `A`–`E` y `G`–`J` para FM/PSG y `L` para percusión PCM. El importador
  mueve una pista `K` a `L` si `L` está libre y ajusta `pcmmode` al mezclador
  del port. El canal `F` queda reservado para los efectos del jugador.
- `pcm_rate` limita las muestras nuevas a `2187`, `4375`, `6562` u `8750` Hz.
  El valor por defecto es `4375`. El build remuestrea los WAV PCM de 8 o 16
  bits cuando hace falta y deja copias en `build/mdsdrv/local-pcm/`. Para un
  WAV con metadatos de bucle, prepara el WAV y su frecuencia compatible antes
  de importarlo. Los archivos originales se conservan.
- La ROM y la ventana física de audio son de 2 MiB. La secuencia enlazada
  ocupa un bloque continuo y cada muestra debe caber dentro de un banco de
  32 KiB. Las pistas FM/PSG y la percusión corta permiten añadir más temas.
  Si el banco no entra, prueba reemplazar temas o usar menos PCM y una
  frecuencia menor. `build/mdsdrv/packed.json` indica los bytes y huecos
  libres y `build/mdsdrv/manifest.json` muestra los temas y sus rutas.
