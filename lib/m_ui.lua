-- user interface
-- i.e., redraw, key, and enc for each page

-- each page should be paired with a grid page
-- "shift" on grid associated with K1
-- E1 changes page
-- each page only uses E/K 2 and 3

-- not sure about this yet ...:
-- grid page change --> affect display page
-- display page change --> NO grid page change

local m_ui = {}

local UI = require "ui"

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_ui.init()
  display = {}
  display[1] = UI.Pages.new(1, 3)  -- sample
  display[2] = UI.Pages.new(2, 1)  -- rec
  display[3] = UI.Pages.new(3, 1)  -- delay

  -- display info in order
  display_names = {'sample', 'rec', 'delay'}
end

-----------------------------------------------------------------
-- NAVIGATION
-----------------------------------------------------------------

-- main navigation bar
function m_ui.draw_nav(header)
  y = 5  -- default text hight
  glyph_buffer = 2

  for i = 1,#display_names do
    x = (i - 1) * glyph_buffer
    screen.move(x, y)
    screen.level(i == DISPLAY_ID and 15 or 2)
    screen.text("|")
  end

  -- current display header
  screen.move_rel(glyph_buffer * 2, 0)
  screen.text(header)
  screen.stroke()
end

-----------------------------------------------------------------
-- SAMPLE
-----------------------------------------------------------------

-- 0: OVERVIEW --------------------------------------------------
-- TODO: build this, connect with K1

-- 1: TRACK -----------------------------------------------

function m_ui.sample_1_redraw()
  local folder = bank_folders[BANK]

  bank_text = "send midi or K2"
  bank_text = folder ~= nil and folder or bank_text

  m_ui.draw_nav(
      TRACK .. " • " .. 
      BANK .. " • " .. 
      bank_text)

  screen.move(64, 32)
  screen.text_center('sample!')

  -- add params like noise (that are not on the config pages) per track

  screen.stroke()
end

function m_ui.sample_1_key(n,z)

  if n == 2 and z == 1 then
    m_sample:load_bank(BANK)
  end

end

function m_ui.sample_1_enc(n,d)
  print('sample 1 enc')
end

-- 2: SAMPLE  ------------------------------------------------------
function m_ui.sample_2_redraw()
  m_ui.draw_nav(
      TRACK .. " • " .. 
      BANK .. " • " .. 
      (SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-"))

  waveform_view:update()
  waveform_view:redraw()

  screen.stroke()
end

function m_ui.sample_2_key(n,z)
  waveform_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_2_enc(n,d)
  waveform_view:enc(n, d)
  screen_dirty = true
end

-- 3: FILTER AMP --------------------------------------------------
function m_ui.sample_3_redraw()
  m_ui.draw_nav(
      TRACK .. " • " .. 
      BANK .. " • " .. 
      (SAMPLE ~= nil and params:string('sample_' .. SAMPLE) or "-"))

  screen.aa(1)
  filter_amp_view:redraw()

  screen.stroke()
end

function m_ui.sample_3_key(n,z)
  -- for fine tuning
  if n == 1 then
    if z == 1 then
      Timber.shift_mode = true
    else
      Timber.shift_mode = false
    end
  end

  filter_amp_view:key(n, z)
  screen_dirty = true
end

function m_ui.sample_3_enc(n,d)
  filter_amp_view:enc(n, d)
  screen_dirty = true
end


-----------------------------------------------------------------
-- REC
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------
rec_toggle = 0

function m_ui.rec_1_redraw()
  m_ui.draw_nav("rec 1")
  screen.move(64, 32)
  screen.text_center('rec!')

  if rec_toggle == 1 then
    screen.move(64, 50)
    screen.text_center('ooooh!')
  end

  screen.stroke()
end

function m_ui.rec_1_key(n,z)
  if n == 3 and z == 1 then
    rec_toggle = rec_toggle ~ 1
    screen_dirty = true
  end
end

function m_ui.rec_1_enc(n,d)
  print('recording encoder')
end


-----------------------------------------------------------------
-- DELAY
-----------------------------------------------------------------

-- 1: MAIN ------------------------------------------------------
function m_ui.delay_1_redraw()
  m_ui.draw_nav("delay 1")
  screen.move(64, 32)
  screen.text_center('delay!')

  if rec_toggle == 1 then
    screen.move(64, 50)
    screen.text_center('oh yeaaah!')
  end

  screen.stroke()
end

function m_ui.delay_1_key(n,z)
  if n == 3 and z == 1 then
    rec_toggle = rec_toggle ~ 1
    screen_dirty = true
  end
end

function m_ui.delay_1_enc(n,d)
  print('recording encoder')
end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

return m_ui