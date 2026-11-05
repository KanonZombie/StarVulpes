-- Unmodified MDSDRV listening ROM. No performance sampling or diagnostic ROM.
local out=assert(os.getenv('MEGASVP_AUDIO_PLAYBACK'))
local f=assert(io.open(out..'/state.txt','w'))
f:write('rom_hash='..gameinfo.getromhash()..'\n')
client.speedmode(400)
local previous=-1
local pictures=false
local started=false
local play=os.getenv('MEGASVP_MDS_PLAY')=='1'
local fire=os.getenv('MEGASVP_MDS_FIRE')=='1'
local laser=false
local scramble=false
local corneria=false
local music_frames=0
local scramble_music_frames,corneria_music_frames=0,0
local laser_pcm_frames,radio_pcm_frames,together_frames=0,0,0
local low_buffer,saturated=0,0
local music_pcm_frames,music_player_pcm_frames,pcm2_frames,music_radio_conflicts=0,0,0,0
local watch_file=io.open(out..'/../effects-watch.lua','r')
local watch=nil
if watch_file then watch_file:close();watch=dofile(out..'/../effects-watch.lua') end
for frame=1,tonumber(os.getenv('MEGASVP_AUDIO_FRAMES') or '5000') do
  local bank=memory.read_u16_be(0xff0104,'M68K BUS')
  local cmd=memory.read_u16_be(0xff0106,'M68K BUS')
  if memory.read_u32_be(0xff0100,'M68K BUS')==0x4d445344 and bank~=previous then
    f:write('music '..frame..' '..bank..' '..cmd..' '..memory.read_u16_be(0xff0108,'M68K BUS')..'\n')
    f:flush();previous=bank
  end
  if memory.read_u16_be(0xff0108,'M68K BUS')>0 and bank<35 then started=true end
  if memory.read_u16_be(0xff0108,'M68K BUS')>0 then music_frames=music_frames+1 end
  if memory.read_u16_be(0xff0108,'M68K BUS')>0 then
    if bank==5 then scramble_music_frames=scramble_music_frames+1 end
    if bank==6 then corneria_music_frames=corneria_music_frames+1 end
  end
  if bank==5 then scramble=true end
  if bank==6 then corneria=true end
  if bank==6 and watch then
    local player_song=memory.read_u16_be(0xff0404,'M68K BUS')%0x4000
    local world_song=memory.read_u16_be(0xff0406,'M68K BUS')%0x4000
    local player,radio,music_pcm=false,false,false
    for i=0,15 do
      local track=0xff044c+58*i
      local flags=memory.read_u16_be(track,'M68K BUS')
      if flags>=0x8000 and math.floor(flags/32)%2==0 then
        local channel=memory.read_u8(track+12,'M68K BUS')
        local request=memory.read_u8(track+13,'M68K BUS')
        if channel==5 and request==0 and player_song==watch.laser then player=true end
        if channel==11 and request==2 and watch.radio[world_song] then radio=true end
        if channel==11 and request==6 then music_pcm=true end
        if channel==10 then pcm2_frames=pcm2_frames+1 end
      end
    end
    if player then laser_pcm_frames=laser_pcm_frames+1 end
    if radio then radio_pcm_frames=radio_pcm_frames+1 end
    if player and radio then together_frames=together_frames+1 end
    if music_pcm then music_pcm_frames=music_pcm_frames+1 end
    if music_pcm and player then music_player_pcm_frames=music_player_pcm_frames+1 end
    if music_pcm and radio then music_radio_conflicts=music_radio_conflicts+1 end
    if (player or radio or music_pcm) and memory.read_u8(0xe01,'Z80 RAM')<35 then low_buffer=low_buffer+1 end
    for i=0,255 do local v=memory.read_u8(0x1f00+i,'Z80 RAM');if v==127 or v==128 then saturated=saturated+1 end end
  end
  if memory.read_u16_be(0xff9ba0,'M68K BUS')>0 then pictures=true end
  if bank==6 and memory.read_u16_be(0xff008a,'M68K BUS')==53 then laser=true end
  if play then joypad.set({['P1 Start']=(bank==1 or bank==2 or bank==4) and frame%120<12,
                          ['P1 Down']=bank==2 and frame%120<12,
                          ['P1 B']=fire and bank==6 and frame%36<12}) end
  emu.frameadvance()
end
f:write('music_requested='..tostring(started)..'\n')
f:write('music_active_frames='..music_frames..'\n')
f:write('scramble_music_frames='..scramble_music_frames..'\ncorneria_music_frames='..corneria_music_frames..'\n')
f:write('laser_pcm_frames='..laser_pcm_frames..'\nradio_pcm_frames='..radio_pcm_frames..'\nsimultaneous_pcm_frames='..together_frames..'\n')
f:write('low_buffer_frames='..low_buffer..'\nsaturated_buffer_samples='..saturated..'\n')
f:write('music_pcm_frames='..music_pcm_frames..'\nmusic_player_pcm_frames='..music_player_pcm_frames..'\npcm2_frames='..pcm2_frames..'\nmusic_radio_conflicts='..music_radio_conflicts..'\n')
f:write('scramble='..tostring(scramble)..'\ncorneria='..tostring(corneria)..'\n')
f:write('firing_enabled='..tostring(fire)..'\nlaser_requested='..tostring(laser)..'\n')
f:write('pictures='..tostring(pictures)..'\n')
f:write('video_error='..memory.read_u16_be(0xff9ba4,'M68K BUS')..'\n')
f:write('sound_ready='..memory.read_u16_be(0xff0084,'M68K BUS')..'\n')
f:write('music_updates='..memory.read_u32_be(0xff010c,'M68K BUS')..'\n')
f:write('pcm_mode='..memory.read_u8(0xe05,'Z80 RAM')..'\n')
f:write('sfx_requests='..memory.read_u16_be(0xff0086,'M68K BUS')..'\n')
f:write('sfx_played='..memory.read_u16_be(0xff0088,'M68K BUS')..'\n')
f:write('dma_deferred_hints='..memory.read_u32_be(0xff0128,'M68K BUS')..'\n')
f:write('dma_gate_arms='..memory.read_u32_be(0xff012c,'M68K BUS')..'\n')
f:write('presentations='..memory.read_u16_be(0xff9ba0,'M68K BUS')..'\n')
f:close()
local ram=assert(io.open(out..'/host.ram','wb'))
for i=0,65535 do ram:write(string.char(memory.read_u8(0xff0000+i,'M68K BUS'))) end
ram:close()
