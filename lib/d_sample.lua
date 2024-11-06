-- sample pages

d_sample = {}

local MusicUtil = require "musicutil"
local UI = require "ui"
local Formatters = require "formatters"
local BeatClock = require "beatclock"

local Timber = include "lib/d_timber"

local options = {}
options.OFF_ON = {"Off", "On"}
options.QUANTIZATION = {"None", "1/32", "1/24", "1/16", "1/12", "1/8", "1/6", "1/4", "1/3", "1/2", "1 bar"}
options.QUANTIZATION_DIVIDERS = {nil, 32, 24, 16, 12, 8, 6, 4, 3, 2, 1}

local SCREEN_FRAMERATE = 15
local screen_dirty = true
local GRID_FRAMERATE = 30
local grid_dirty = true
local grid_w, grid_h = 16, 8

local midi_in_device
local midi_clock_in_device
local grid_device

local NUM_SAMPLES = 128  -- max 256

local beat_clock
local note_queue = {}

local sample_status = {}
local STATUS = {
  STOPPED = 0,
  STARTING = 1,
  PLAYING = 2,
  STOPPING = 3
}
for i = 0, NUM_SAMPLES - 1 do sample_status[i] = STATUS.STOPPED end

function d_sample.load_folder(file, add)
  
  local sample_id = 0
  if add then
    for i = NUM_SAMPLES - 1, 0, -1 do
      if Timber.samples_meta[i].num_frames > 0 then
        sample_id = i + 1
        break
      end
    end
  end
  
  Timber.clear_samples(sample_id, NUM_SAMPLES - 1)
  
  local split_at = string.match(file, "^.*()/")
  local folder = string.sub(file, 1, split_at)
  file = string.sub(file, split_at + 1)
  
  local found = false
  for k, v in ipairs(Timber.FileSelect.list) do
    if v == file then found = true end
    if found then
      -- get lowercase filename
      local lower_v = v:lower()
        
      -- check for <row0col> ... naming convention
      local rowcol = string.match(lower_v, "^%d%d%d ")
      if rowcol ~= nil then
          rowcol = tonumber(rowcol)
          sample_id = 16 * (rowcol // 100) + rowcol - (rowcol // 100) * 100
      end
      if sample_id > 255 then
        print("Max files loaded")
        break
      end

      if string.find(lower_v, ".wav") or string.find(lower_v, ".aif") or string.find(lower_v, ".aiff") or string.find(lower_v, ".ogg") then
        Timber.load_sample(sample_id, folder .. v)
        sample_id = sample_id + 1
      else
        print("Skipped", v)
      end
    end
  end
end

local function set_sample_id(id)
  current_sample_id = id
  while current_sample_id >= NUM_SAMPLES do current_sample_id = current_sample_id - NUM_SAMPLES end
  while current_sample_id < 0 do current_sample_id = current_sample_id + NUM_SAMPLES end
  sample_setup_view:set_sample_id(current_sample_id)
  waveform_view:set_sample_id(current_sample_id)
  filter_amp_view:set_sample_id(current_sample_id)
  amp_env_view:set_sample_id(current_sample_id)
  mod_env_view:set_sample_id(current_sample_id)
  lfos_view:set_sample_id(current_sample_id)
  mod_matrix_view:set_sample_id(current_sample_id)
end

local function id_to_x(id)
  return (id - 1) % grid_w + 1
end
local function id_to_y(id)
  return math.ceil(id / grid_w)
end

local function note_on(sample_id, vel)
  if Timber.samples_meta[sample_id].num_frames > 0 then
    -- print("note_on", sample_id)
    vel = vel or 1
    engine.noteOn(sample_id, MusicUtil.note_num_to_freq(60), vel, sample_id)
    sample_status[sample_id] = STATUS.PLAYING
    global_view:add_play_visual()
    screen_dirty = true
    grid_dirty = true
  end
end

local function note_off(sample_id)
  -- print("note_off", sample_id)
  engine.noteOff(sample_id)
  screen_dirty = true
  grid_dirty = true
end

local function clear_queue()
  
  for k, v in pairs(note_queue) do
    if Timber.samples_meta[v.sample_id].playing then
      sample_status[v.sample_id] = STATUS.PLAYING
    else
      sample_status[v.sample_id] = STATUS.STOPPED
    end
  end
  
  note_queue = {}
end

local function queue_note_event(event_type, sample_id, vel)
  
  local quant = options.QUANTIZATION_DIVIDERS[params:get("quantization_" .. sample_id)]
  if params:get("quantization_" .. sample_id) > 1 then
    
    -- Check for already queued
    for i = #note_queue, 1, -1 do
      if note_queue[i].sample_id == sample_id then
        if note_queue[i].event_type ~= event_type then
          table.remove(note_queue, i)
          if Timber.samples_meta[sample_id].playing then
            sample_status[sample_id] = STATUS.PLAYING
          else
            sample_status[sample_id] = STATUS.STOPPED
          end
          grid_dirty = true
        end
        return
      end
    end
    
    if event_type == "on" or sample_status[sample_id] == STATUS.PLAYING then
      if Timber.samples_meta[sample_id].num_frames > 0 then
        local note_event = {
          event_type = event_type,
          sample_id = sample_id,
          vel = vel,
          quant = quant
        }
        table.insert(note_queue, note_event)
        
        if event_type == "on" then
          sample_status[sample_id] = STATUS.STARTING
        else
          sample_status[sample_id] = STATUS.STOPPING
        end
      end
    end
    
  else
    if event_type == "on" then
      note_on(sample_id, vel)
    else
      note_off(sample_id)
    end
  end
  grid_dirty = true
end

local function note_off_all()
  engine.noteOffAll()
  clear_queue()
  screen_dirty = true
  grid_dirty = true
end

local function note_kill_all()
  engine.noteKillAll()
  clear_queue()
  screen_dirty = true
  grid_dirty = true
end

local function set_pressure_voice(voice_id, pressure)
  engine.pressureVoice(voice_id, pressure)
end

local function set_pressure_sample(sample_id, pressure)
  engine.pressureSample(sample_id, pressure)
end

local function set_pressure_all(pressure)
  engine.pressureAll(pressure)
end

local function set_pitch_bend_voice(voice_id, bend_st)
  engine.pitchBendVoice(voice_id, MusicUtil.interval_to_ratio(bend_st))
end

local function set_pitch_bend_sample(sample_id, bend_st)
  engine.pitchBendSample(sample_id, MusicUtil.interval_to_ratio(bend_st))
end

local function set_pitch_bend_all(bend_st)
  engine.pitchBendAll(MusicUtil.interval_to_ratio(bend_st))
end

local function key_down(sample_id, vel)
  
  if pages.index == 2 then
    sample_setup_view:sample_key(sample_id)
  end
  
  if params:get("launch_mode_" .. sample_id) == 1 then
    queue_note_event("on", sample_id, vel)
    
  else
    if (sample_status[sample_id] ~= STATUS.PLAYING and sample_status[sample_id] ~= STATUS.STARTING) or sample_status[sample_id] == STATUS.STOPPING then
      queue_note_event("on", sample_id, vel)
    else
      queue_note_event("off", sample_id)
    end
  end
  
end

local function key_up(sample_id)
  if params:get("launch_mode_" .. sample_id) == 1 and params:get("play_mode_" .. sample_id) ~= 4 then
    queue_note_event("off", sample_id)
  end
end


return d_sample