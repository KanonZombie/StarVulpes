"""Stage unit `ending`: end_game_seq 02:E56F, credits map 0D:F1EE (owner: build/agent-ending/ENDING.md).

Loaded by every generator (tools/level-shapes.py stage_modules()). Nothing to add today:
* the score and credit lines are text objects (msprint), not shapes; the score objects use zaco_4
  (header $D924, already in tools/level-shapes.py) only for z-remove/size;
* the THE END letters of the credits map (font_t $E804, font_h $E874, font_e $E7B0, font_n $E83C,
  font_d $C8F4) are catalogued by tools/stages/spacemisc.py (OOTD uses them too). This file must not
  name them as Python hex literals: spacemisc.py skips every header it finds written in the stage
  modules that sort before it;
* playercred 0B:B566 is ported by the player-modes unit (M4PmCredI);
* the background `cred` (setbg $81, 03:A7D3) is converted by tools/convert-level-backgrounds.py.
"""
SHAPES = []
EFFECTS = []
PSTRATS = {}
