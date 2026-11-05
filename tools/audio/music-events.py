"""Restore omitted startbgm consumers at their existing translated states.

Extraction reads commands from the original USA LDA / STA $1F49 / STZ $1F48.
Replay instructions are assembled with the same symbol table and matched
against the freshly built host code. No game counter/branch is invented.
"""
import json
from catalog import ROOT, SF_SHA, sha


# start label, search end (or a bounded 192-byte function prefix),
# displaced absolute instructions, original command site, condition.
EVENTS = [
  ('M4TitleFrameEnd','M4TitleTimeout','move.w #1,M4_TITLE_EXIT',0x1ff535,''),
  ('M4TitleTimeout','M4TitleContinue','move.w #2,M4_TITLE_EXIT',0x1ff55c,''),
  ('M4CtlNoBack','M4CtlFading','move.b #2,M4_CTL_PHASE',0x1ffb92,''),
  ('M4CnNotX','M4CnStartYes','move.b #2,M4_CN_EXIT',0x03e70b,''),
  ('M4CnStartYes','M4CnNotStart','subq.b #1,M4_GM_CREDITS',0x03e71c,''),
  ('M4RmGo','M4RmBlink','move.b #1,M4_RM_FLASH',0x03c03c,''),
  ('M4TrStart','M4TrTailRet','st M4_TR_FADING',0x1ffc18,''),
  ('M4RmNoLines','M4RmShipStart','moveq #0,d0\n        move.b M4_GS_CURPLANET,d0',0x03bedf,
   'cmpi.b #$0e,M4_GS_CURPLANET\n        beq.s {play}\n        cmpi.b #$0a,M4_GS_CURPLANET\n        bne.s {skip}'),
  ('M4RmZoomSet','M4RmPepperSetupDone','move.w M4_RM_COUNT,M4_RM_ZTOTAL',0x03c232,'briefing'),
  ('M4PmWoEnd','M4PmLimSpace','andi.b #$fe,M4_BOSS_PSTRATF',0x0b8b2c,''),
  ('M4WpState1','M4WpS1Dist','cmpi.b #1,M4_WP_STATE',0x0ba322,
   'cmpi.b #1,M4_WP_STATE\n        bne.s {skip}\n        cmpi.w #20,M4_WP_W1556\n        bne.s {skip}'),
  ('M4WpS1Dist','M4WpState2','move.w #60,M4_WP_W1556',0x0ba3bd,''),
  ('M4WpHyperInit','M4WpNoCopy','jsr M4CdDupPlayer',0x0ba464,''),
  ('M4BhCaptured','M4BhNot70','bclr #1,M4_LP_PSF3',0x0adea1,''),
  ('M4BhNot70','M4BhNot31','move.b #$ff,M4_FADE',0x0adebb,''),
  ('M4SmBhInto','M4SmBhPull','move.b #8,36(a0)',0x0a92a8,''),
  ('M4SmBhPull','M4SmBhNoFade','move.b #$ff,M4_FADE',0x0a92cf,''),
  ('M4SmEndCount','M4SmEndCountClr','move.l #M4SmEndDone,32(a0)',0x0a97fd,''),
  ('M4SmPv65','M4SmPv65No','move.w #$02c0,42(a0)',0x04a6a6,''),
  ('M4VePship1','M4VeP1S1','move.b #23,36(a0)',0x06d4d0,
   'cmpi.b #$e0,12(a0)\n        bne.s {skip}'),
  ('M4VeP3S2','M4VeP3S3','andi.b #$fd,M4_LP_PSF3',0x06dc69,''),
  ('M4VaCoreExpI','M4VaCoreExp','move.l #M4VaCoreExp,X_EXP(a0)',0x07f09c,''),
  ('M4B1Explode','M4B1ExplodeChain','st M4_BOSS_DYING',0x06eabf,''),
  ('M4Boss7Die','M4Boss7Fall','st M4_BOSS_DYING',0x07d263,''),
  ('M4AbBodyDie','M4AbBodyDying','st M4_BOSS_DYING',0x079608,''),
  ('M4CnBaExp','M4CnBaExpSet','st M4_BOSS_DYING',0x07a19c,''),
  ('M4MbBoss2Die','M4MbBoss2Dying','st M4_BOSS_DYING',0x0892d8,''),
  ('M4BhBossExplode','M4BhExplodeChain','st M4_BOSS_DYING',0x06eabf,''),
  ('M4VrChgI_BCE0',None,'move.b #2,38(a0)',0x07bd1f,''),
  ('M4VrChg4Init_BEC1','M4VrChg4_BEEA','move.l #M4VrChg4_BEEA,32(a0)',0x07bee2,''),
  ('M4VrSepExpI_CA3F','M4VrSepExp_CA7F','move.l #M4VrSepExp_CA7F,32(a0)',0x07ca77,''),
  ('M4V3TeNoTrailer','M4V3TruckSwerve','move.l #M4V3TruckSwerve,X_EXP(a0)',0x09c9fe,''),
  ('M4SmWebSpin','M4SmWebNotYet','move.b 37(a0),d0\n        add.b d0,14(a0)',0x09d88e,
   'tst.b 37(a0)\n        bne.s {skip}'),
]
BRIEFING_ALT = 0x03c228
COMMANDS_PATH = ROOT / 'build/audio-native/music-commands.json'


def extract():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert sha(rom) == SF_SHA
    commands = {}
    for address in [row[3] for row in EVENTS] + [BRIEFING_ALT]:
        at = (address >> 16) * 0x8000 + (address & 0x7fff)
        assert (rom[at], rom[at+2], rom[at+5]) == (0xa9, 0x8d, 0x9c), hex(address)
        assert int.from_bytes(rom[at+3:at+5], 'little') == 0x1f49, hex(address)
        assert int.from_bytes(rom[at+6:at+8], 'little') == 0x1f48, hex(address)
        commands[f'{address:06X}'] = rom[at+1]
    COMMANDS_PATH.parent.mkdir(parents=True, exist_ok=True)
    COMMANDS_PATH.write_text(json.dumps(commands, indent=2) + '\n', encoding='utf-8')
    print(f'Extracted {len(commands)} music commands')


def prepare():
    commands = json.loads(COMMANDS_PATH.read_text(encoding='utf-8'))

    def command(address):
        value = commands[f'{address:06X}']
        if type(value) is not int or not 0 <= value <= 255:
            raise ValueError(f'Invalid music command at {address:06X}: {value}')
        return value

    def load_command(value):
        mnemonic = 'moveq' if value < 128 else 'move.w'
        return f'{mnemonic} #{value},d0'

    wrappers=[];specs=[]
    for index,(start,end,instruction,address,condition) in enumerate(EVENTS):
        cmd = command(address)
        label=f'ReleaseEvent{index}'
        play=label+'Play';skip=label+'Done'
        argument=f'move.w #${cmd:x},d0'
        if condition=='briefing':
            condition=''
            argument=f'''moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        add.w d0,d0
        lea M4RmPlanetSprs,a0
        btst #7,1(a0,d0.w)
        beq.s {label}Fast
        {load_command(cmd)}
        bra.s {label}Request
{label}Fast:
        {load_command(command(BRIEFING_ALT))}
{label}Request:'''
        wrappers.append(f'''{label}:
        move.w sr,-(sp)
        movem.l d0/a0,-(sp)
        {condition.format(play=play,skip=skip)}
{play}:
        {argument}
        bsr ReleaseCommand
{skip}:
        movem.l (sp)+,d0/a0
        move.w (sp)+,sr
{label}Replay:
        {instruction}
{label}Jump:
        jmp $0
''')
        specs.append(dict(label=label,start=start,end=end,original_command=cmd,original_site=address,
            instruction=instruction))
    return '\n'.join(wrappers),specs


def install(rom,audio,origin,labels,symbols,specs):
    for spec in specs:
        label=spec['label'];first=labels[label+'Replay'];jump=labels[label+'Jump']
        instruction=audio[first-origin:jump-origin]
        assert len(instruction)>=6 and len(instruction)%2==0,(spec,len(instruction))
        a=symbols[spec['start']];b=symbols[spec['end']] if spec['end'] else a+192
        assert rom[a:b].count(instruction)==1,(spec['start'],instruction.hex())
        at=rom.index(instruction,a,b);spec['host_site']=at;spec['bytes']=instruction.hex()
        rom[at:at+len(instruction)]=b'\x4e\xf9'+labels[label].to_bytes(4,'big')+b'\x4e\x71'*((len(instruction)-6)//2)
        assert audio[jump-origin:jump-origin+6]==bytes.fromhex('4ef900000000')
        audio[jump-origin+2:jump-origin+6]=(at+len(instruction)).to_bytes(4,'big')
    return specs


if __name__ == '__main__':
    extract()
