-- movements
--
-- time allows for movement.

-- norns `require` statements
-- x = require('module')

engine.name = "m_Timber"

-- script components
m_tape = include 'lib/m_tape'
m_sample = include 'lib/m_sample'
m_seq = include 'lib/m_seq'
m_grid = include 'lib/m_grid'
m_ui = include 'lib/m_ui'
m_delay = include 'lib/m_delay'

HOLD_K1 = false
REDRAW_FRAMERATE = 30  -- same for grid and screen
DISPLAY_ID = 1
PAGE_ID = 1

-- parameter options for all non-timber parameters
p_options = {}

-- track defaults across samples and recording
track_param_default = {
  amp = 1,
  delay = 0,
  pan = 0,
  filter = 20000,
  scale = 1,
  rate = 1,
  prob = 1,
  noise = 0,
  midi_1 = 1,
  midi_2 = 0,
  midi_3 = 0
}

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()

  manage_data()

  m_sample.build_params()
  m_seq.build_params()

  m_sample.init()
  m_seq.init()
  m_ui.init()
  m_grid.init()

  -- set default parameters
  for i, p in ipairs({'amp', 'pan'}) do
    for t=1,7 do
      params:set('track_' .. t .. "_" .. p, track_param_default[p])
    end
  end
  
  -- redraw clock
  screen_dirty = true
  grid_dirty = true
  clock.run(redraw_clock)
end

-----------------------------------------------------------------
-- UI
-----------------------------------------------------------------

function redraw()
  screen.clear()

  display[DISPLAY_ID]:redraw()
  m_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_redraw"]()

  screen.update()
end

function key(n, z)
  if n == 1 then
    if z == 1 then
      HOLD_K1 = true
    else
      HOLD_K1 = false
    end
  end

  m_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_key"](n,z)

  -- !! "screen_dirty" decided in primary function !!
end

function enc(n, d)
  if n == 1 then
    if HOLD_K1 then
      DISPLAY_ID = util.clamp(DISPLAY_ID + d, 1, #display_names)
      PAGE_ID = 1
    else
      display[DISPLAY_ID]:set_index_delta(d, false)
      PAGE_ID = display[DISPLAY_ID].index
    end
    screen_dirty = true
  end

  m_ui[display_names[DISPLAY_ID] .. "_" .. PAGE_ID .."_enc"](n,d)

  -- !! "screen_dirty" decided in primary function !!
end

function redraw_clock()
  while true do
    clock.sleep(1/REDRAW_FRAMERATE)
    
    if screen_dirty then
      redraw()
      screen_dirty = false
    end

    if grid_dirty then
      m_grid:grid_redraw()
      grid_dirty = false
    end

  end
end

-----------------------------------------------------------------
-- DATA
-----------------------------------------------------------------

function manage_data()

  -- save
  params.action_write = function(filename,name,number)
    print("finished writing '"..filename.."' as '"..name.."'", number)
    os.execute("mkdir -p "..norns.state.data.."/"..number.."/")

    m_data = {
      p_options = p_options,
      partitions = partitions,
      banks = banks,
      bank_folders = bank_folders,
      track_param_level = track_param_level,
      param_pattern = param_pattern,
      track_pool = track_pool,
      track_pool_cue = track_pool_cue,
      step = step,
      step_range = step_range,
      clock_range = clock_range,
      offset = offset,
      time_type = time_type,
      pattern = pattern,
      bank = bank
    }

    tab.save(m_data, norns.state.data.."/"..number.."/dots.data")

  end

  -- load
  params.action_read = function(filename,silent,number)
    print("finished reading '"..filename.."'", number)

    m_data = tab.load(norns.state.data.."/"..number.."/dots.data")

    p_options = m_data.p_options
    partitions = m_data.partitions
    banks = m_data.banks
    bank_folders = m_data.bank_folders
    track_param_level = m_data.track_param_level
    param_pattern = m_data.param_pattern
    track_pool = m_data.track_pool
    track_pool_cue = m_data.track_pool_cue
    step = m_data.step
    step_range = m_data.step_range
    clock_range = m_data.clock_range
    offset = m_data.offset
    time_type = m_data.time_type
    pattern = m_data.pattern
    bank = m_data.bank
    
  end

  -- delete
  params.action_delete = function(filename,name,number)
    print("finished deleting '"..filename, number)
    norns.system_cmd("rm -r "..norns.state.data.."/"..number.."/")
  end

end