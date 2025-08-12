-- Traveler.lua -- 
setSize(720,480)
setBackground("_images/traveler_bg.png")

-- NxN grid of cells
-- rovers move through the grid, bouncing off walls and each other,
--   bouncing off obstacles too 

local MAX_ROWS    = 12
local MAX_COLUMNS = 12

local MAX_ROVERS  = 12

local CELL_NORTH     = 1
local CELL_NORTHEAST = 2
local CELL_EAST      = 3
local CELL_SOUTHEAST = 4
local CELL_SOUTH     = 5
local CELL_SOUTHWEST = 6
local CELL_WEST      = 7
local CELL_NORTHWEST = 8
  -- "direction" numbers must be 1.. 8
local CELL_EMPTY     = 9
local CELL_COLLISION = 10 -- rover collision 
local CELL_OBSTACLE_MIRROR_UP_RIGHT   = 11
local CELL_OBSTACLE_MIRROR_UP_LEFT    = 12
local CELL_OBSTACLE_MIRROR_HORIZONTAL = 13
local CELL_OBSTACLE_MIRROR_VERTICAL   = 14
local CELL_OBSTACLE_SQUARE            = 15
local CELL_OBSTACLE_DIAMOND           = 16
local CELL_OBSTACLE_RANDOM_DIRECTION  = 17
local CELL_OBSTACLE_WORMHOLE          = 18
local CELL_OBSTACLE_MIRROR_UP_RIGHT_TOGGLE   = 19
local CELL_OBSTACLE_MIRROR_UP_LEFT_TOGGLE    = 20
local CELL_OBSTACLE_MIRROR_HORIZONTAL_TOGGLE = 21
local CELL_OBSTACLE_MIRROR_VERTICAL_TOGGLE   = 22
local CELL_OBSTACLE_ACCELERATE       = 23
local CELL_OBSTACLE_PAUSE            = 24

local WALL_NORTH = 1
local WALL_EAST  = 2
local WALL_SOUTH = 3
local WALL_WEST  = 4

local GRID_X = 180
local GRID_Y = 55
local CELL_SIZE = 30
local GRID_WIDTH = (CELL_SIZE * MAX_COLUMNS)
local GRID_HEIGHT = (CELL_SIZE * MAX_ROWS)
local GRID_X_RIGHT = GRID_X + GRID_WIDTH + 75

local NUM_CELL_IMAGES = 24

local isGridLocked = false

local isPlaying = false
local isTransportRunning = false
local wobblePercent = 0
local pauseOnCollide = false

local pauseOnChord = false
local numStrikes = 0

local maxRovers = MAX_ROVERS

--------------------------------------------------------------------------------
-- Lua Range Helper
--------------------------------------------------------------------------------

local function clamp(value, min, max)
  return math.min(math.max(value, min), max)
end

--------------------------------------------------------------------------------
-- Lua Table helper
--------------------------------------------------------------------------------

local function tableLookup(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

-- --------------------------------------------------------------------------------
-- -- UI Helpers
-- --------------------------------------------------------------------------------

local function formatPercent(value)
  return string.format("%0.1f %%", value)
end

--------------------------------------------------------------------------------
-- Note/Pitch Names
--------------------------------------------------------------------------------
--- TODO: add button to select 'use sharps' or 'use flats'
local pitchNamesFlats  = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local pitchNamesSharps = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
local useFlats = true
local pitchNames = pitchNamesFlats

local function formatNoteName(midiNoteNumber)
  local octave = midiNoteNumber % 12
  return pitchNames[octave + 1]..tostring((midiNoteNumber - octave) / 12 - 2)
end

--------------------------------------------------------------------------------
-- Scales
--------------------------------------------------------------------------------
local scales = {
	{"Chromatic", {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}},
	{"Major (Ionian)", {0, 2, 4, 5, 7, 9, 11}},
	{"Minor (Aeolion)", {0, 2, 3, 5, 7, 8, 10}},
	{"Harmonic Minor", {0, 2, 3, 5, 7, 8, 11}},
	{"Melodic Minor", {0, 2, 3, 5, 7, 9, 11}},
	{"Major Pentatonic", {0, 2, 4, 7, 9}},
	{"Minor Pentatonic", {0, 3, 5, 7, 10}},
	{"Dorian (D)", {0, 2, 3, 5, 7, 9, 10}},
	{"Phrygian (E)", {0, 1, 3, 5, 7, 8, 10}},
	{"Lydian (F)", {0, 2, 4, 6, 7, 9, 11}},
	{"Mixolydian (G)", {0, 2, 4, 5, 7, 9, 10}},
	{"Locrian (B)", {0, 1, 3, 5, 6, 8, 10}},
	{"Whole Tone", {0, 2, 4, 6, 8, 10}},
	{"1/2 Tone 1 Tone", {0, 1, 3, 4, 6, 7, 9, 10}},
	{"1 Tone 1/2 Tone", {0, 2, 3, 5, 6, 8, 9, 11}},
	{"Altered", {0, 2, 4, 6, 8, 10, 10}},
	{"Hungarian", {0, 2, 3, 6, 7, 8, 10}},
	{"Phrygish", {0, 1, 4, 5, 7, 8, 10}},
	{"Arabic", {0, 1, 4, 5, 7, 8, 11}},
	{"Persian", {0, 1, 4, 5, 7, 10, 11}},
	{"Acoustic (Lydian b7)", {0, 2, 4, 6, 7, 9, 10}},
	{"Harmonic Major", {0, 2, 4, 5, 7, 8, 11}},


  -- TODO: clean up scale list
  { "Onoleo", {0, 7, 8, 12, 16, 17, 19, 20, 24} },
  { "Sen", {0, 1, 5, 7, 10, 12, 13, 17, 19, 22} },

  { "Aegean", {0, 4, 7, 11, 12, 16, 18, 19, 23} },
  { "Dark Aegean", {0, 5, 8, 12, 13, 17, 19, 20} },
  { "Akebono", {0, 5, 7, 8, 12, 13} },
  { "AmaRa", {0, 7, 10, 12, 14, 15, 17} },
  { "Ananda", {0, 4, 5, 7, 11, 12, 14, 16, 19} },
  { "AnnaZiska", {0, 7, 8, 10, 12, 14, 15, 17} },
  { "Arboreal", {0, 7, 8, 10, 12, 15} },
  { "Arcadian", {0, 4, 7, 9, 11, 12, 14, 18, 19, 21} },
  { "Golden Arcadia", {0, 4, 7, 11, 12, 14, 18, 19, 21} },
  -- { "Deep Arcadian",  {0, 9, 12, 14, 16, 17, 19, 23, 24, 28} },
  { "Avalon", {0, 3, 5, 7, 8, 10, 12, 15, 17, 19} },
  { "Awake", {0, 3, 7, 8, 10, 12, 15, 19} },
  { "Baduhari", {0, 7, 11, 12, 14, 16, 17, 19} },
  { "Bhinna", {0, 7, 10, 12, 13, 16, 17, 19} },
--  { "Blackpool", {0, 5, 7, 12, 13, 15, 17, 18} },
  { "Blues", {0, 5, 8, 10, 11, 12, 15, 17, 20} },
  -- { "Caspian", {0, 7, 11, 12, 14, 15, 18, 19} },
  { "Celtic Minor", {0, 7, 10, 12, 14, 15, 17, 19} },
  { "Chad Gayo", {0, 7, 8, 10, 12, 17, 19, 20} },
  { "ChanDhra", {0, 5, 7, 8, 10, 12, 13, 15, 17} },
  { "Big Bear", {0, 5, 7, 10, 12, 14, 15, 19} },
  -- { "Da Xiong Diao", {0, 5, 7, 10, 12, 14, 15, 17, 19} },
  -- { "Daxala", {0, 6, 7, 8, 11, 12, 14, 15} },
  { "Debac", {0, 7, 8, 10, 12, 14, 15, 17, 19} },
  { "Deshvara", {0, 5, 7, 11, 12, 14, 17, 19} },
--   { "Ebbtide", {0, 7, 8, 10, 12, 13, 15, 19, 20, 24} },
  { "Egyptian", {0, 7, 10, 12, 15, 17, 19, 22} },
  { "Elysian", {0, 4, 7, 9, 11, 12, 14, 19, 21, 23} },
  { "Emmanuel", {0, 7, 8, 12, 13, 16, 17, 19, 24} },
  { "Fifth Mode", {0, 7, 9, 10, 12, 15, 17, 19, 21} },
  { "Genus", {0, 7, 11, 12, 14, 16, 18, 19} },
  { "Golden Dawn", {0, 6, 7, 11, 12, 14, 18, 19} },
  { "Golden Gate", {0, 4, 7, 11, 12, 14, 18, 19} },
----   { "Copperfield", {0, 4, 7, 11, 12, 14, 18, 19, 23} },
  { "Spindrift", {0, 4, 7, 11, 12, 14, 16, 18, 19} },
---  { "Goonkali", {0, 5, 6, 10, 12, 13, 17, 18, 22} },
---  { "Gopikatilaka", {0, 7, 8, 11, 12, 15, 17, 19} },
  { "Gowleeswari", {0, 7, 8, 12, 15, 19, 20} },
  { "Hafiz", {0, 3, 5, 7, 8, 11, 12, 15, 17, 19} },
  { "Hijaz", {0, 5, 6, 9, 10, 12, 13, 15, 17} },
---  { "Hijazkiar", {0, 5, 6, 9, 10, 12, 13, 16, 17} },
---  { "Hiperaeolian", {0, 7, 8, 10, 12, 13, 15, 17, 19} },
---  { "Hira-Joshi", {0, 7, 8, 12, 13, 17, 19, 20} },
---  { "Hokkaido", {0, 5, 7, 8, 10, 12, 13, 17, 19} },
---  { "Hokkaido 10", {0, 5, 7, 8, 10, 12, 13, 17, 19, 20, 29} },
---  { "Honchishi", {0, 7, 8, 10, 12, 13, 17, 19} },
--  { "Hungarian major", {0, 3, 5, 8, 18, 21, 23, 24, 27} },
--  { "Huzam", {0, 5, 8, 9, 10, 12, 14, 16, 17} },
  { "Hyboreal", {0, 7, 8, 10, 12, 14, 15, 19, 20, 22} },
  { "Insen", {0, 7, 8, 12, 14, 15, 17, 19} },
  { "Integral", {0, 7, 8, 10, 12, 14, 15, 19} },
  { "Protus", {0, 7, 8, 10, 12, 14, 15, 19, 22} },
  { "Inuit", {0, 5, 7, 9} },
  { "Iwato", {0, 7, 8, 12, 13, 17, 19, 20, 24} },
---  { "Jibuk", {0, 5, 7, 9, 10, 12, 14, 15, 17} },
---  { "Kaffa", {0, 7, 8, 11, 12, 14, 15, 17, 19} },
---  { "Kambhoji", {0, 7, 9, 10, 12, 14, 17, 19} },
  { "Kapijingla", {0, 7, 9, 10, 12, 16, 17, 19} },
--  { "Kedaram", {0, 7, 9, 11, 12, 14, 18, 19} },
--  { "Khyberi", {0, 6, 7, 10, 12, 14, 15, 18, 19} },
---  { "Kiavara", {0, 5, 7, 8, 12, 13, 16, 17, 19} },
---  { "King Island", {0, 5, 7, 8, 10, 12, 15, 17} },
  { "Klezmera", {0, 7, 12, 13, 16, 17, 19, 20, 24} },
  { "Kokin-Choshi", {0, 5, 6, 10, 12, 15, 17, 18, 22} },
---  { "Kumari", {0, 4, 7, 9, 11, 12, 15, 16, 19} },
---  { "Kumo", {0, 5, 7, 8, 12, 13, 15, 19} },
  { "La Sirena", {0, 3, 7, 9, 10, 12, 14, 15, 19} },
  { "Limoncello", {0, 5, 7, 11, 12, 14, 16, 19} },
  { "LongLoy", {0, 5, 7, 8, 10, 12, 14, 15, 17} },
  { "Magic Hour", {0, 3, 7, 10, 12, 14, 15, 19} },
--   { "Melog", {0, 4, 5, 7, 11, 12, 17, 19} },
  { "Melog-Selisir", {0, 4, 5, 7, 11, 12, 16, 17, 19} },
---  { "Migration", {0, 4, 6, 7, 11, 14, 16, 18} },
---  { "Mixophonic", {0, 5, 7, 10, 12, 14, 16, 19} },
  { "MonDhra", {0, 4, 7, 8, 10, 12, 13, 16, 17, 19} },
  { "Monsoon", {0, 4, 5, 7, 8, 12, 16, 17, 19} },
---  { "Mysorean", {0, 4, 5, 7, 11, 12, 14, 15, 19} },
  { "Nihavend", {0, 7, 8, 10, 12, 13, 16, 17, 19} },
  { "Noh", {0, 5, 7, 10, 12, 13, 14, 16, 17} },
--  { "North Sea", {0, 2, 3, 7, 9, 10, 12, 14} },
---  { "Olimpia", {0, 3, 5, 7, 9, 10, 12, 14, 15} },
---  { "Olympos", {0, 6, 10, 11, 15, 17, 18, 22, 23} },
  { "Overtone", {0, 7, 9, 11, 12, 14, 15, 17, 19} },
  { "Oxalis", {0, 4, 5, 7, 9, 12, 16, 17, 19} },
  { "Oxalista", {0, 4, 5, 7, 9, 12, 14, 16, 17, 19} },
  { "Paradise", {0, 5, 7, 9, 11, 12, 14, 16, 17} },
  { "Paradiso", {0, 4, 7, 11, 12, 14, 16, 19} },
--  { "Purvi", {0, 4, 5, 8, 10, 11, 12, 15, 16} },
  { "Pygmalion", {0, 3, 5, 7, 8, 12, 12, 17, 19, 20} },
  { "Pygmy", {0, 5, 7, 8, 12, 15, 17, 19, 20} },
--  { "Pyramid", {0, 7, 9, 10, 12, 13, 16, 19, 21} },
--  { "Raga Dejani", {0, 4, 7, 10, 12, 16, 17, 19, 22} },
  { "Raga Desh", {0, 4, 5, 7, 10, 12, 16, 17, 19} },
--  { "Raga Desya Todi", {0, 4, 7, 9, 11, 12, 14, 16, 19} },
  { "Raja", {0, 3, 7, 8, 11, 12, 14, 15, 19, 24} },
--  { "Riverrun", {0, 3, 7, 10, 12, 14, 17, 19} },
  { "Riviera", {0, 4, 5, 7, 9, 11, 12, 14, 16, 19} },
  -- { "Rufinus", {0, 3, 7, 8, 10, 12, 13, 15} },
  { "Russian Major", {0, 4, 5, 7, 11, 12, 16, 17, 19, 21} },
  { "SaBye", {0, 3, 5, 7, 8, 10, 12, 14, 15} },
  { "SalaDin", {0, 5, 7, 10, 12, 13, 16, 17, 19} },
  { "Saudade", {0, 5, 7, 11, 12, 14, 15, 19} },
  { "Shakti", {0, 2, 3, 6, 7, 9, 12, 14} },
  { "Shanti", {0, 2, 4, 6, 7, 9, 12, 14} },
--  { "Shang", {0, 7, 9, 10, 12, 14, 15, 17, 19} },
  { "Shang-Diao", {0, 5, 7, 10, 12, 15, 17, 19, 22} },
--  { "Syrah", {0, 7, 8, 11, 12, 14, 15, 19} },
--   { "Shiraz", {0, 5, 7, 8, 11, 12, 14, 15, 19} },
  { "Special PBJ", {0, 2, 4, 7, 9, 11, 12, 16, 19} },
  { "Spyner", {0, 5, 7, 12, 14, 16, 17, 22} },
  { "Voyager", {0, 3, 7, 10, 12, 14} },
--   { "Suddha", {0, 7, 8, 10, 12, 15, 17, 19} },
--  { "Sundown", {0, 5, 7, 10, 12, 15, 17, 19} },
--  { "Synthesis", {0, 3, 7, 8, 10, 12, 14, 15, 17, 19} },
  { "TalaySai", {0, 5, 7, 8, 11, 12, 14, 15, 17} },
--  { "Tharsi", {0, 5, 7, 11, 12, 14, 15, 18, 19} },
  { "Ujo", {0, 5, 7, 10, 12, 14, 17, 19, 22} },
  { "Wadi Rum", {0, 7, 8, 11, 12, 15, 18, 19} },
  { "Xiao Xiong Diao", {0, 5, 7, 8, 12, 14, 15} },
  { "YshaSavita", {0, 7, 11, 12, 14, 16, 17, 19} },
  { "Yu Shan Diao", {0, 3, 5, 7, 10, 12, 15, 17, 19} },
  { "Yue Diao", {0, 7, 10, 12, 15, 17, 19, 22} },
  { "Zheng",  {0, 7, 9, 12, 14, 16, 19, 21} },
  { "Zokuso", {0, 7, 8, 12, 13, 15, 19, 20} },
}

local scaleNames = {}
for i = 1, #scales do
  scaleNames[i] = scales[i][1]
end

-- --------------------------------------------------------------------------------
-- -- Timing
-- --------------------------------------------------------------------------------

local clockRateBeatsNominal = 1
local clockRateMultiplier = 1
local clockRateBeats = 1

local gateLengthPercent = 1
local gateLengthBeats = 1

local function computeGateLengthBeats()
  gateLengthBeats = clockRateBeats * gateLengthPercent
end

local function updateClock()
  clockRateBeats = clockRateBeatsNominal * clockRateMultiplier
  computeGateLengthBeats()
end

local function setClockRate(beats)
  clockRateBeatsNominal = beats
  updateClock()
end

local function setClockRateMultiplier(factor)
  clockRateMultiplier = factor
  updateClock()
end

local function setGateLengthPercent(value)
  gateLengthPercent = value
  computeGateLengthBeats()
end

local function bars(num) 
  return num * 4 -- 4 beats per bar
end

local function beats(num)
  return num
end

local tempoDivisions = {
-- division   gate-length an number of beats
  { '8x',        bars(8)     },
  {' 6x',        bars(6)     },
  { '4x',        bars(4)     },
  { '3x',        bars(3)     },
  { '2x',        bars(2)     },
  { '1x dot',    bars(1.5)   },
  { '1x',        bars(1)     },
  { '1/2 dot',   beats(3)    },
  { '1x trip',   bars(2/3)   },
  { '1/2',       beats(2)    },
  { '1/4 dot',   beats(1.5)  },
  { '1/2 trip',  beats(4/3)  },
  { '1/4',       beats(1)    },
  { '1/8 dot',   beats(3/4)  },
  { '1/4 trip',  beats(2/3)  },
  { '1/8',       beats(1/2)  } ,
  { '1/16 dot',  beats(3/8)  },
  { '1/8 trip',  beats(1/3)  },
  { '1/16',      beats(2/8)  },
  { '1/32 dot',  beats(3/16) },
  { '1/16 trip', beats(1/6)  },
  { '1/32',      beats(2/16) },
  { '1/32 trip', beats(1/12) },
}

local tempoDivisionNames = {}
for i = 1, #tempoDivisions do
    tempoDivisionNames[i] = tempoDivisions[i][1]
end

--------------------------------------------------------------------------------
-- Outlier handling algorithm
--------------------------------------------------------------------------------

local OUTLIER_FREEZE = 1
local OUTLIER_CORRAL = 2
local OUTLIER_REMOVE = 3

local outlierOption = OUTLIER_FREEZE

local outlierOptions = {
    { 'Leave',  OUTLIER_FREEZE },
    { 'Corral', OUTLIER_CORRAL },
    { 'Remove', OUTLIER_REMOVE },
}

local outlierOptionNames = {}
for i = 1, #outlierOptions do
    outlierOptionNames[i] = outlierOptions[i][1]
end

--------------------------------------------------------------------------------
-- Cell Occupancy class - holds the rovers occupying the cell 
--------------------------------------------------------------------------------
local Occupants = {}

function Occupants:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.rovers = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }
  o.roverCount = 0
  return o
end

function Occupants:addRover(rover)
  -- print("Occupants: addRover:",rover,"entry =",self.rovers[rover.id])
  if self.rovers[rover.id] == nil then
    self.roverCount = self.roverCount + 1
  end
  self.rovers[rover.id] = rover
  if pauseOnCollide and self.roverCount > 1 then
    rover.pauseCount = self.roverCount
  end
end

function Occupants:removeRover(rover)
  -- print("Occupants: removeRover:",rover,"entry =",self.rovers[rover.id])
  if self.rovers[rover.id] ~= nil then
    self.roverCount = self.roverCount - 1
  end
  self.rovers[rover.id] = nil
end

--------------------------------------------------------------------------------
-- Cell class
--------------------------------------------------------------------------------
local Cell = { image = nil, roverCount = 0 }

function Cell:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.image = nil
  o.obstacle = nil  -- set to CELL_x value when obstacle is present 
  o.occupants = Occupants:new()
  return o
end

function Cell:addRover(rover)
  self.occupants:addRover(rover)
  if self.image.value >= 10 then -- is obstacle 
    -- leave image as is 
  elseif self.obstacle ~= nil then
    self.image:setValue(self.obstacle, false)
  elseif self.occupants.roverCount == 0 then
    self.image:setValue(CELL_EMPTY, false)
  elseif self.occupants.roverCount == 1 then 
    self.image:setValue(rover.direction, false)
  else -- rover count > 1 
    self.image:setValue(CELL_COLLISION, false)
  end
  -- print("CELL: Add Rover: cell image =", self.image.value, ",num rovers =", self.occupants.roverCount)
end

function Cell:removeRover(rover)
  self.occupants:removeRover(rover)
  if self.occupants.roverCount == 0 then
    if self.image.value > 10 then -- is obstacle 
      -- leave image as is 
    else
      self.image:setValue(CELL_EMPTY, false)
    end
  end
  -- print("CELL: Remove Rover: cell image =", self.image.value, ",num rovers =", self.occupants.roverCount)
end

function Cell:removeAllRovers()
  self.occupants.rovers = {}
  self.occupants.roverCount = 0
  if self.image.value <= 8 or self.image.value == CELL_COLLISION then
    self.image:setValue(CELL_EMPTY, false)
  end
end

--------------------------------------------------------------------------------
-- Grid class
--------------------------------------------------------------------------------
local Grid = { numRows = MAX_ROWS, numColumns = MAX_COLUMNS, cells = {} }

function Grid:new(numRows,numColumns)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.numRows = numRows
  o.numColumns = numColumns
  o.cells = {} -- [row][column]
  for r = 1, MAX_ROWS do
    local row = {}
    for c = 1, MAX_COLUMNS do
      row[c] = Cell:new()
    end
    o.cells[r] = row
  end
  return o
end

function Grid:setNumRows(numRows)
  self.numRows = numRows
  self:forceRepaint()
end

function Grid:setNumColumns(numColumns)
  self.numColumns = numColumns
  self:forceRepaint()
end

function Grid:clearAll()
  for row = 1, MAX_ROWS do
    for column = 1, MAX_COLUMNS do
      local cell = self.cells[row][column]
      cell:removeAllRovers()
      cell.image:setValue(CELL_EMPTY, false)
    end
  end
end

function Grid:clearRovers()
  for row = 1, MAX_ROWS do
    for column = 1, MAX_COLUMNS do
      self.cells[row][column]:removeAllRovers()
    end
  end
end

function Grid:clearObstacles()
  for row = 1, MAX_ROWS do
    for column = 1, MAX_COLUMNS do
      local cell = self.cells[row][column]
      if cell.image.value >= 10 then
        cell.image:setValue(CELL_EMPTY, false)
      end
    end
  end
end

function Grid:getValue(row,column)
  return self.cells[row][column].image.value
end

function Grid:setValue(row,column,value)
  self.cells[row][column].image:setValue(value, true)
end

function Grid:setEditLock(isLocked)
  for row = 1, MAX_ROWS do
    for column = 1, MAX_COLUMNS do
      self.cells[row][column].image.interceptsMouseClicks = not isLocked
    end
  end
end

function Grid:addRover(rover)
  self.cells[rover.row][rover.column]:addRover(rover)
end

function Grid:removeRover(rover)
  self.cells[rover.row][rover.column]:removeRover(rover)
end

local repaintInProgress = false
function Grid:forceRepaint()
  -- KLUDGE: force grid refresh to clear out stuck images 
  repaintInProgress = true
  for row= 1, self.numRows do
    local grid_row = self.cells[row]
    for column = 1, self.numColumns do
      local image = grid_row[column].image
      local value = image.value
      image:setValue(24, false) -- set to "unused" value to force clean up of CELL_EMPTY
      image:setValue(value, false)
    end
  end
  repaintInProgress = false
end

local grid = Grid:new(MAX_ROWS, MAX_COLUMNS) -- moved later 

--------------------------------------------------------------------------------
-- Wall class
--------------------------------------------------------------------------------
local Wall = { }

function Wall:new(position)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.position = position                              -- north, east, south, west
  o.rootPitch = 60
  o.scaleDegrees = { 0, 0, 0 }
  o.pitches = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } -- midi note number 
  o.pitchOffset = 0
  o.pitchAscending = true
  o.activeStrikes = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } -- holds the 'index' for each active strike on the wall
  o.numStrikesActive = 0
  o.slideAmount = 0     -- on strike, shift row/column this much 
  o.isMute = false
  return o
end

function Wall:updatePitches()
  local octave = math.floor(self.pitchOffset / #self.scaleDegrees) * 12
  local index = math.floor(self.pitchOffset % #self.scaleDegrees) + 1
  local highestOffset = -999
  for i=1,MAX_COLUMNS do
      local offset = self.scaleDegrees[index]
      if offset > highestOffset then
        highestOffset = offset
      end
      self.pitches[i] = self.rootPitch + offset + octave
      self.pitches[i] = clamp(self.pitches[i], 0, 127)
      index = index + 1
      if index > #self.scaleDegrees then
        index = 1
        octave = octave + 12 + (12 * math.floor(highestOffset / 12))
      end
  end

  if not self.pitchAscending then
    table.sort(self.pitches, function(x,y) return x > y end)
  end
end

function Wall:setScale(scaleDegrees)
  self.scaleDegrees = scaleDegrees
  self:updatePitches()
end

function Wall:setRootPitch(rootPitch, scaleDegrees)
  self.rootPitch = rootPitch
  self:updatePitches()
end

function Wall:setPitchesAscending(isAscending)
  self.pitchAscending = isAscending
  self:updatePitches()
end

function Wall:rotatePitches(rotation)
  self.pitchOffset = rotation
  self:updatePitches()
end

function Wall:strike(index)
  self.numStrikesActive = self.numStrikesActive + 1
  self.activeStrikes[self.numStrikesActive] = index
end

function Wall:clearStrikes()
  self.numStrikesActive = 0
end

local wallNorth = Wall:new(WALL_NORTH)
local wallEast  = Wall:new(WALL_EAST)
local wallSouth = Wall:new(WALL_SOUTH)
local wallWest  = Wall:new(WALL_WEST)

local noteVelocity = 100
local noteVelocityChaos = 0

local function performStrike(wall, index)
  numStrikes = numStrikes + 1

  if pauseOnChord and numStrikes > 1 then
    return
  end

  if gateLengthBeats <= 0 then
    return
  end

  -- -- TODO: add wall.velocity .. possibly 0 to 

  local midiChannel = 1
  local noteNumber = wall.pitches[index]
  local velocity = noteVelocity + (math.random(-1,1) * (noteVelocityChaos * 128))
  -- print("STRIKE: wall=" .. wall.direction .. ",idx=" .. index .. ",note=" .. noteNumber)
  if velocity > 0 then
    if velocity > 127 then
      velocity = 127
    end
    -- print("note: value", value, "(velocity", velocity, ") = midi", noteNumber)
    playNote(noteNumber, velocity, beat2ms(gateLengthBeats), nil, midiChannel)
    wall:strike(index)
  end
end

local function performRowStrike(wall, rover)
  performStrike(wall, rover.row)
  rover:shiftRow(wall.slideAmount)
  if pauseOnChord then
    rover.pauseCount = rover.pauseCount + (numStrikes - 1)
  end
end

local function performColumnStrike(wall, rover)
  performStrike(wall, rover.column)
  rover:shiftColumn(wall.slideAmount)
  if pauseOnChord then
    rover.pauseCount = rover.pauseCount + (numStrikes - 1)
  end
end

local function strikeNorthWall(rover)
  performColumnStrike(wallNorth, rover)
end

local function strikeEastWall(rover)
  performRowStrike(wallEast, rover)
end

local function strikeSouthWall(rover)
  performColumnStrike(wallSouth, rover)
end

local function strikeWestWall(rover)
  performRowStrike(wallWest, rover)
end

local function strikeNorthEastCorner(rover)
  if math.random() <= 0.5 then
    strikeNorthWall(rover)
  else
    strikeEastWall(rover)
  end
end

local function strikeSouthEastCorner(rover)
  if math.random() <= 0.5 then
    strikeSouthWall(rover)
  else
    strikeEastWall(rover)
  end
end

local function strikeSouthWestCorner(rover)
  if math.random() <= 0.5 then
    strikeSouthWall(rover)
  else
    strikeWestWall(rover)
  end
end

local function strikeNorthWestCorner(rover)
  if math.random() <= 0.5 then
    strikeNorthWall(rover)
  else
    strikeWestWall(rover)
  end
end

--------------------------------------------------------------------------------
-- Rover class
--------------------------------------------------------------------------------
local Rover = {}

local roverIds = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

function Rover:new(row,column,direction)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.row = row
  o.column = column
  o.direction = direction
  o.active = true  -- false when rover position is outside of active grod rows/columns 
  o.id = table.remove(roverIds,1)
  o.pauseCount = 0
  return o
end

function Rover:retire()
  table.insert(roverIds, self.id)
end

function Rover:__tostring()
  return "<Rover(id="..self.id..",row=" .. self.row .. ",col=" .. self.column .. ",dir=" .. self.direction .. ",pause=" .. self.pauseCount .. ")>"
end

-- TODO: move to where Rover is declared 
function Rover:redirect(direction, rowDelta, columnDelta)
  self.direction = direction
  self.row = clamp(self.row + rowDelta, 1, grid.numRows)
  self.column = clamp(self.column + columnDelta, 1, grid.numColumns)
end

function Rover:shiftRow(rowDelta) -- shift row after striking a wall 
 if rowDelta ~= 0 then
    local newRow = self.row + rowDelta
    -- print("RowDelta",rowDelta)
    if newRow < 1 then
      newRow = grid.numRows - ((0 - newRow) % grid.numRows)
    elseif newRow > grid.numRows then
      newRow = (newRow % grid.numRows)
      if newRow == 0 then
        newRow = self.row
      end
    end
    -- print("Rover",self,"newColumn",newColumn)
    self.row = newRow
  end

  -- if rowDelta == 1 then
--     if self.row == grid.numRows then
--         self.row = 1
--     else
--         self.row = self.row + 1
--     end
--   elseif rowDelta == -1 then
--     if self.row == 1 then
--         self.row = grid.numRows
--     else
--         self.row = self.row - 1
--     end
--   end
end

function Rover:shiftColumn(columnDelta) -- shift column after striking a wall 
  if columnDelta ~= 0 then
    local newColumn = self.column + columnDelta
    if newColumn < 1 then
      newColumn = grid.numColumns - ((0 - newColumn) % grid.numColumns)
    elseif newColumn > grid.numColumns then
      newColumn = (newColumn % grid.numColumns)
      if newColumn == 0 then
        --print("-- Zero Compensation")
        newColumn = self.column
      end
    end
    --print("shiftColumn",self,"newColumn",newColumn)
    self.column = newColumn
  end






-- if columnDelta == 1 then
  --   if self.column == grid.numColumns then
  --       self.column = 1
  --   else
  --       self.column = self.column + 1
  --   end
  -- elseif columnDelta == -1 then
  --   if self.column == 1 then
  --       self.column = grid.numColumns
  --   else
  --       self.column = self.column - 1
  --   end
  -- end
end

function Rover:randomize()
  self.direction = math.floor(math.random(1,8) + 0.5)
  self.row       = math.floor(math.random(1,grid.numRows) + 0.5)
  self.column    = math.floor(math.random(1,grid.numColumns) + 0.5)
end

local function reactObstacleSquare(rover)
  if rover.direction == CELL_NORTH then
    rover:redirect(CELL_SOUTH, 1, 0)
  elseif rover.direction == CELL_EAST then
    rover:redirect(CELL_WEST, 0, -1)
  elseif rover.direction == CELL_SOUTH then
    rover:redirect(CELL_NORTH, -1, 0)
  elseif rover.direction == CELL_WEST then
    rover:redirect(CELL_EAST, 0, 1)
  elseif rover.direction == CELL_NORTHEAST then
    if math.random() <= 0.5 then
      rover:redirect(CELL_NORTH, 0, 1)
    else
      rover:redirect(CELL_EAST, 1, 0)
    end
  elseif rover.direction == CELL_SOUTHEAST then
    if math.random() <= 0.5 then
      rover:redirect(CELL_SOUTH, 0, 1)
    else
      rover:redirect(CELL_EAST, 1, 0)
    end
  elseif rover.direction == CELL_SOUTHWEST then
    if math.random() <= 0.5 then
      rover:redirect(CELL_SOUTH, 0, 1)
    else
      rover:redirect(CELL_WEST, -1, 0)
    end
  elseif rover.direction == CELL_NORTHWEST then
    if math.random() <= 0.5 then
      rover:redirect(CELL_NORTH, 0, 1)
    else
      rover:redirect(CELL_WEST, -1, 0)
    end
  end
end

local function reactObstacleDiamond(rover)
  if rover.direction == CELL_NORTH then
    if math.random() <= 0.5 then
      rover:redirect(CELL_NORTHWEST, 0, -1)
    else
      rover:redirect(CELL_NORTHEAST, 0, 1)
    end
  elseif rover.direction == CELL_EAST then
    if math.random() <= 0.5 then
      rover:redirect(CELL_NORTHEAST, -1, 0)
    else
      rover:redirect(CELL_SOUTHEAST, 1, 0)
    end
  elseif rover.direction == CELL_SOUTH then
    if math.random() <= 0.5 then
      rover:redirect(CELL_SOUTHWEST, 0, -1)
    else
      rover:redirect(CELL_SOUTHEAST, 0, 1)
    end
  elseif rover.direction == CELL_WEST then
    if math.random() <= 0.5 then
      rover:redirect(CELL_NORTHWEST, -1, 0)
    else
      rover:redirect(CELL_SOUTHWEST, 1, 0)
    end
  elseif rover.direction == CELL_NORTHEAST then
    rover:redirect(CELL_SOUTHWEST, 1, -1)
  elseif rover.direction == CELL_SOUTHEAST then
    rover:redirect(CELL_NORTHWEST, -1, -1)
  elseif rover.direction == CELL_SOUTHWEST then
    rover:redirect(CELL_NORTHEAST, -1, 1)
  elseif rover.direction == CELL_NORTHWEST then
    rover:redirect(CELL_SOUTHEAST, 1, 1)
  end
end

local function reactObstacleMirrorUpRight(rover)  -- \ 
  if rover.direction == CELL_NORTH then
    rover:redirect(CELL_WEST, 0, -1)
  elseif rover.direction == CELL_EAST then
    rover:redirect(CELL_SOUTH, 1, 0)
  elseif rover.direction == CELL_SOUTH then
    rover:redirect(CELL_EAST, 0, 1)
  elseif rover.direction == CELL_WEST then
    rover:redirect(CELL_NORTH, -1, 0)
  elseif rover.direction == CELL_NORTHEAST then
    rover:redirect(CELL_SOUTHWEST, 1, -1)
  elseif rover.direction == CELL_SOUTHEAST then
    rover:redirect(CELL_SOUTHEAST, 1, 1) -- pass straight through 
  elseif rover.direction == CELL_SOUTHWEST then
    rover:redirect(CELL_NORTHEAST, -1, 1)
  elseif rover.direction == CELL_NORTHWEST then
    rover:redirect(CELL_NORTHWEST, -1, -1) -- pass straight through 
  end
end

local function reactObstacleMirrorUpLeft(rover)  -- / 
  if rover.direction == CELL_NORTH then
    rover:redirect(CELL_EAST, 0, 1)
  elseif rover.direction == CELL_EAST then
    rover:redirect(CELL_NORTH, -1, 0)
  elseif rover.direction == CELL_SOUTH then
    rover:redirect(CELL_WEST, 0, -1)
  elseif rover.direction == CELL_WEST then
    rover:redirect(CELL_SOUTH, 1, 0)
  elseif rover.direction == CELL_NORTHEAST then
    rover:redirect(CELL_NORTHEAST, -1, 1)-- pass straight through 
  elseif rover.direction == CELL_SOUTHEAST then
    rover:redirect(CELL_NORTHWEST, -1, -1) 
  elseif rover.direction == CELL_SOUTHWEST then
    rover:redirect(CELL_SOUTHWEST, 1, -1) -- pass straight through 
  elseif rover.direction == CELL_NORTHWEST then
    rover:redirect(CELL_SOUTHEAST, 1, 0)
  end
end

local function reactObstacleMirrorHorizontal(rover)
  if rover.direction == CELL_NORTH then
    rover:redirect(CELL_SOUTH, 1, 0)
  elseif rover.direction == CELL_EAST then
    rover:redirect(CELL_EAST, 0, 1)-- pass straight through 
  elseif rover.direction == CELL_SOUTH then
    rover:redirect(CELL_NORTH, -1, 0)
  elseif rover.direction == CELL_WEST then
    rover:redirect(CELL_WEST, 0, -1)-- pass straight through 
  elseif rover.direction == CELL_NORTHEAST then
    rover:redirect(CELL_SOUTHEAST, 1, 1)
  elseif rover.direction == CELL_SOUTHEAST then
    rover:redirect(CELL_NORTHEAST, -1, 1) 
  elseif rover.direction == CELL_SOUTHWEST then
    rover:redirect(CELL_NORTHWEST, -1, -1)
  elseif rover.direction == CELL_NORTHWEST then
    rover:redirect(CELL_SOUTHWEST, 1, -1)
  end
end

local function reactObstacleMirrorVertical(rover)
  if rover.direction == CELL_NORTH then
    rover:redirect(CELL_NORTH, -1, 0) -- pass straight through
  elseif rover.direction == CELL_EAST then
    rover:redirect(CELL_WEST, 0, -1)
  elseif rover.direction == CELL_SOUTH then
    rover:redirect(CELL_SOUTH, 1, 0) -- pass straight through
  elseif rover.direction == CELL_WEST then
    rover:redirect(CELL_EAST, 0, 1)
  elseif rover.direction == CELL_NORTHEAST then
    rover:redirect(CELL_NORTHWEST, -1, -1)
  elseif rover.direction == CELL_SOUTHEAST then
    rover:redirect(CELL_SOUTHWEST, 1, -1) 
  elseif rover.direction == CELL_SOUTHWEST then
    rover:redirect(CELL_SOUTHEAST, 1, 1)
  elseif rover.direction == CELL_NORTHWEST then
    rover:redirect(CELL_NORTHEAST, -1, 1)
  end
end

local function reactObstacleRandomDirection(rover)
  local direction = math.floor(math.random(1,8) + 0.5)
  rover:redirect(direction, 0, 0)
end

local function reactObstacleWormhole(rover)
  rover:randomize()
end

local function reactObstacleMirrorUpRightToggle(rover)  -- .\
  grid:setValue(rover.row,rover.column,CELL_OBSTACLE_MIRROR_UP_LEFT_TOGGLE)
  reactObstacleMirrorUpRight(rover)
end

local function reactObstacleMirrorUpLeftToggle(rover)  -- /.
  grid:setValue(rover.row,rover.column,CELL_OBSTACLE_MIRROR_UP_RIGHT_TOGGLE)
  reactObstacleMirrorUpLeft(rover)
end

local function reactObstacleMirrorHorizontalToggle(rover)
  grid:setValue(rover.row,rover.column,CELL_OBSTACLE_MIRROR_VERTICAL_TOGGLE)
  reactObstacleMirrorHorizontal(rover)
end

local function reactObstacleMirrorVerticalToggle(rover)
  grid:setValue(rover.row,rover.column,CELL_OBSTACLE_MIRROR_HORIZONTAL_TOGGLE)
  reactObstacleMirrorVertical(rover)
end

local function reactObstacleAccelerate(rover) -- pass straight through 
  if rover.direction == CELL_NORTH then
    rover:redirect(CELL_NORTH, -1, 0) 
  elseif rover.direction == CELL_EAST then
    rover:redirect(CELL_EAST, 0, 1)
  elseif rover.direction == CELL_SOUTH then
    rover:redirect(CELL_SOUTH, 1, 0)
  elseif rover.direction == CELL_WEST then
    rover:redirect(CELL_WEST, 0, -1)
  elseif rover.direction == CELL_NORTHEAST then
    rover:redirect(CELL_NORTHEAST, -1, 1)
  elseif rover.direction == CELL_SOUTHEAST then
    rover:redirect(CELL_SOUTHEAST, 1, 1)
  elseif rover.direction == CELL_SOUTHWEST then
    rover:redirect(CELL_SOUTHWEST, 1, -1)
  elseif rover.direction == CELL_NORTHWEST then
    rover:redirect(CELL_NORTHWEST, -1, -1)
  end
end

local function reactObstaclePause(rover)
    rover.pauseCount = rover.pauseCount + 1
end


local function handleObstacle(rover)
  local cellValue = grid:getValue(rover.row,rover.column)
  if cellValue <= 10 then 
    return false -- not an obstacle
  end

  -- TODO: replace if/else with a function lookup table 
  if cellValue == CELL_OBSTACLE_SQUARE then
    reactObstacleSquare(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_DIAMOND then
    reactObstacleDiamond(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_UP_RIGHT then
    reactObstacleMirrorUpRight(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_UP_LEFT then
    reactObstacleMirrorUpLeft(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_HORIZONTAL then
    reactObstacleMirrorHorizontal(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_VERTICAL then
    reactObstacleMirrorVertical(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_RANDOM_DIRECTION then
    reactObstacleRandomDirection(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_WORMHOLE then
    reactObstacleWormhole(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_UP_LEFT_TOGGLE then
    reactObstacleMirrorUpLeftToggle(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_UP_RIGHT_TOGGLE then
    reactObstacleMirrorUpRightToggle(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_HORIZONTAL_TOGGLE then
    reactObstacleMirrorHorizontalToggle(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_MIRROR_VERTICAL_TOGGLE then
    reactObstacleMirrorVerticalToggle(rover)
    return true
  elseif cellValue == CELL_OBSTACLE_ACCELERATE then
    reactObstacleAccelerate(rover)
    return false ------------------------------------------- NOTE: return false to let wall strikes be processed
  elseif cellValue == CELL_OBSTACLE_PAUSE then
    reactObstaclePause(rover)
    return true
  end
end

-- use table of function pointers to move rovers 
local function moveNorth(rover)
  if rover.row > 1 then 
    rover.row = rover.row - 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.row == 1 then
    strikeNorthWall(rover)
    rover.direction = CELL_SOUTH
  end
end

local function moveNorthEast(rover)
  if rover.row > 1 and rover.column < grid.numColumns then
    rover.row    = rover.row    - 1
    rover.column = rover.column + 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.row == 1 then
    if rover.column == grid.numColumns then
      strikeNorthEastCorner(rover)
      rover.direction = CELL_SOUTHWEST
    else
      strikeNorthWall(rover)
      rover.direction = CELL_SOUTHEAST
    end
  elseif rover.column == grid.numColumns then
      strikeEastWall(rover)
      rover.direction = CELL_NORTHWEST
  end
end

local function moveEast(rover)
  if rover.column < grid.numColumns then
    rover.column = rover.column + 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.column == grid.numColumns then
    strikeEastWall(rover)
    rover.direction = CELL_WEST
  end
end

local function moveSouthEast(rover)
  if rover.row < grid.numRows and rover.column < grid.numColumns then
    rover.row    = rover.row    + 1
    rover.column = rover.column + 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.row == grid.numRows then
    if rover.column == grid.numColumns then
      strikeSouthEastCorner(rover)
      rover.direction = CELL_NORTHWEST
    else
      strikeSouthWall(rover)
      rover.direction = CELL_NORTHEAST
    end
  elseif rover.column == grid.numColumns then
      strikeEastWall(rover)
      rover.direction = CELL_SOUTHWEST
  end
end

local function moveSouth(rover)
  if rover.row < grid.numRows then
    rover.row = rover.row + 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.row == grid.numRows then
    strikeSouthWall(rover)
    rover.direction = CELL_NORTH
  end
end

local function moveSouthWest(rover)
  if rover.row < grid.numRows and rover.column > 1 then
    rover.row    = rover.row    + 1
    rover.column = rover.column - 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.row == grid.numRows then
    if rover.column == 1 then
      -- strike southwest corner 
      strikeSouthWestCorner(rover)
      rover.direction = CELL_NORTHEAST
    else
      strikeSouthWall(rover)
      rover.direction = CELL_NORTHWEST
    end
  elseif rover.column == 1 then
      strikeWestWall(rover)
      rover.direction = CELL_SOUTHEAST
  end
end

local function moveWest(rover)
  if rover.column > 1 then
    rover.column = rover.column - 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.column == 1 then
    strikeWestWall(rover)
    rover.direction = CELL_EAST
  end
end

local function moveNorthWest(rover)
  if rover.row > 1 and rover.column > 1 then
    rover.row    = rover.row    - 1
    rover.column = rover.column - 1
    if handleObstacle(rover) then
      return
    end
  end
  if rover.row == 1 then
    if rover.column == 1 then
      -- strike northwest corner 
      strikeNorthWestCorner(rover)
      rover.direction = CELL_SOUTHEAST
    else
      strikeNorthWall(rover)
      rover.direction = CELL_SOUTHWEST
    end
  elseif rover.column == 1 then
    strikeWestWall(rover)
    rover.direction = CELL_NORTHEAST
  end
end

local roverForwardFunctions = {
  moveNorth,
  moveNorthEast,
  moveEast,
  moveSouthEast,
  moveSouth,
  moveSouthWest,
  moveWest,
  moveNorthWest
}


local rovers = {}

local function addRover(row, column, direction)
  local rover = nil
  if #rovers >= maxRovers then -- rover table full
    rover = rovers[1] -- oldest rover 
    grid:removeRover(rover)  -- remove from grid
    table.remove(rovers, 1)  -- remove from table
    rover:retire()
  end
  rover = Rover:new(row, column, direction)
  table.insert(rovers,rover)
  grid:addRover(rover)  -- place rover in the grid
end


-- TODO: tacky function .. fix this 
local function removeRoverFromRoverTable(roverToRetire) -- remove rover from rover table 
  -- print("removeRoverFromRoverTable:",roverToRetire)
  for i = 1,#rovers do
    local rover = rovers[i]
    if rover.id == roverToRetire.id then
      -- print("  found rover",rover)
      table.remove(rovers, i)
      roverToRetire:retire()
      break
    end
  end
  -- print("    #rovers =",#rovers)
end

local function retireAllRovers()
  for i = 1, #rovers do
    rovers[i]:retire() -- return the rover id to the pool 
  end
  rovers = {}
end


local function removeAllRoversAt(row, column)
  -- print("== Remove all rovers at",row,column,"BEFORE: rover count =",grid.cells[row][column].occupants.roverCount)
  local occupants = grid.cells[row][column].occupants
  for i = 1,MAX_ROVERS do
    local rover = occupants.rovers[i]
    if rover ~= nil then
      -- print("  .. removing rover", rover)
      occupants:removeRover(rover)
      removeRoverFromRoverTable(rover)
    end
  end
  -- print("removeAllRoversAt, num rovers is now", occupants.roverCount)
end

local function advanceRovers()
  numStrikes = 0
  -- print("== advance rovers")
  for i = 1, #rovers do
    local rover = rovers[i]
    -- print("Rover",i,rover)
    if rover.active then
      if rover.pauseCount > 0 then
        rover.pauseCount = rover.pauseCount - 1
      else
        -- remove rover from cell it is currently occupying
        grid:removeRover(rover)

        -- wobble position if enabled
        if wobblePercent > math.random() then
            rover:redirect(rover.direction, math.floor(math.random(-1,1)), math.floor(math.random(-1,1)))
        end

        -- move the rover to its next cell
        -- if the rover hits a wall or an obstacle then the direction may be changed 
        local motionFunction = roverForwardFunctions[rover.direction]
        motionFunction(rover)

        -- indicate the rover's presence in the new cell 
        grid:addRover(rover)
      end
    end
  end
end

local function moveRover(rover, row, column)
  grid:removeRover(rover)  -- remove rover from current cell 
  rover.row = row
  rover.column = column
  grid:addRover(rover)     -- add rover to new cell 
end

local function makeCell(row,column)
  local cellWidget = Knob("Cell_r"..row.."_c"..column, CELL_EMPTY, 1, NUM_CELL_IMAGES, true)
  cellWidget:setStripImage("_images/traveler_cell_strip_30x30.png", NUM_CELL_IMAGES)
  cellWidget.interceptsMouseClicks = true
  cellWidget.showLabel = false
  cellWidget.showValue = false
  cellWidget.showPopupDisplay = false
  cellWidget.tooltip = "Row "..row..", Column "..column  -- TODO: later, add name of cell contents to tooltip Empty, Northeast, Square, etc  
  cellWidget.x = GRID_X + (CELL_SIZE * (column -1))
  cellWidget.y = GRID_Y + (CELL_SIZE * (row - 1))
  cellWidget.changed = function(self)
    -- print("Cell", row, column, self.value,isGridLocked,isPlaying)
    if not repaintInProgress then
      removeAllRoversAt(row,column)
      if self.value >= 1 and self.value <= 8 then
        addRover(row,column,self.value)
      end
    end
  end

  local cell = Cell:new()
  cell.image = cellWidget
  cell.roverCount = 0
  return cell
end


local gridLockButton = OnOffButton("GridLock", isGridLocked)
gridLockButton.normalImage = "_images/unlocked.png"
gridLockButton.pressedImage = "_images/locked.png"
gridLockButton.tooltip = "Enable/Disable grid cell editing"
gridLockButton.x = GRID_X - 30
gridLockButton.y = GRID_Y - 20
gridLockButton.changed = function(self)
  isGridLocked = self.value
  grid:setEditLock(isGridLocked)
end

-- pitch labels 
local pitchLabelTextColorQuiet  = "paleturquoise" 
local pitchLabelTextColorStrike = "black"

local function makePitchLabel(wall, index)
    local pitchLabel = Label("L1")
    pitchLabel.text = "TBD"
    pitchLabel.backgroundColour = "#00808080" -- invisible, alpha == 0 
    pitchLabel.textColour = pitchLabelTextColorQuiet
    pitchLabel.size = {26, 15}
    pitchLabel.interceptsMouseClicks = false
    if wall == WALL_NORTH then
        pitchLabel.x = GRID_X + (CELL_SIZE * (index - 1))
        pitchLabel.y = GRID_Y - 20
    elseif wall == WALL_EAST then
        pitchLabel.x = GRID_X + (CELL_SIZE * (grid.numColumns)) + 5
        pitchLabel.y = GRID_Y + (CELL_SIZE * (index - 1)) + 8
    elseif wall == WALL_SOUTH then
        pitchLabel.x = GRID_X + (CELL_SIZE * (index - 1))
        pitchLabel.y = GRID_Y + (CELL_SIZE * (grid.numRows)) + 5
    elseif wall == WALL_WEST then
        pitchLabel.x = GRID_X - 30
        pitchLabel.y = GRID_Y + (CELL_SIZE * (index - 1)) + 8
    end
    return pitchLabel
end

local function extinguishStrike(pitchLabel)
--  pitchLabel.backgroundColour = "#808080" -- Web Gray -- "darkgray" -- "black"
  pitchLabel.backgroundColour = "#00808080"
  pitchLabel.textColour = pitchLabelTextColorQuiet
end

local function highlightStrike(pitchLabel)
  pitchLabel.backgroundColour = "gold"
  pitchLabel.textColour = pitchLabelTextColorStrike
end



local pitchLabelsNorth = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }
local pitchLabelsEast  = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }
local pitchLabelsSouth = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }
local pitchLabelsWest  = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil }

for i = 1, MAX_COLUMNS do
  pitchLabelsNorth[i] = makePitchLabel(WALL_NORTH, i)
  pitchLabelsSouth[i] = makePitchLabel(WALL_SOUTH, i)
end

for i = 1, MAX_ROWS do
  pitchLabelsEast[i] = makePitchLabel(WALL_EAST, i)
  pitchLabelsWest[i] = makePitchLabel(WALL_WEST, i)
end

-- TODO: make "pitchLabels" part of the Wall class 

-- for i = 1, MAX_ROWS do
--   pitchLabelsNorth[i].text = formatNoteName(60 + ((i-1) * 2))
--   pitchLabelsEast[i].text = formatNoteName(60 + ((i-1) * 2))
--   pitchLabelsSouth[i].text = formatNoteName(60 + ((i-1) * 2))
--   pitchLabelsWest[i].text = formatNoteName(60 + ((i-1) * 2))
-- end

local function clearStrikes(wall, pitchLabels)
  --print("Clear Strikes: wall", wall.direction, "Active=", wall.numStrikesActive)
  for i = 1, wall.numStrikesActive do
    local index = wall.activeStrikes[i]
    extinguishStrike(pitchLabels[index])
  end
  wall.numStrikesActive = 0
end

local function showStrikes(wall, pitchLabels)
  --print("Show Strikes: wall", wall.direction, "Active=", wall.numStrikesActive)
  for i = 1, wall.numStrikesActive do
    local index = wall.activeStrikes[i]
    highlightStrike(pitchLabels[index])
  end
end

local function populatePitchLabels(wall,pitchLabels)
  for i = 1, MAX_COLUMNS do
    pitchLabels[i].text = formatNoteName(wall.pitches[i])
  end
end

local function updatePitchLabels()
  populatePitchLabels(wallNorth, pitchLabelsNorth)
  populatePitchLabels(wallEast, pitchLabelsEast)
  populatePitchLabels(wallSouth, pitchLabelsSouth)
  populatePitchLabels(wallWest, pitchLabelsWest)
end

local function setDisplayAccidentalsSharp(useSharps)
  useFlats = not useSharps
  if useFlats then
    pitchNames = pitchNamesFlats
  else
    pitchNames = pitchNamesSharps
  end
end


local function setRootPitch(pitch)
  wallNorth:setRootPitch(pitch)
  wallEast:setRootPitch(pitch)
  wallSouth:setRootPitch(pitch)
  wallWest:setRootPitch(pitch)
  updatePitchLabels()
end

local function setScale(scale)
  wallNorth:setScale(scale)
  wallEast:setScale(scale)
  wallSouth:setScale(scale)
  wallWest:setScale(scale)
  updatePitchLabels()
end

local function redrawGrid() -- TODO: Grid:redraw() 
  local isRowActive = true
  local isColumnActive = true
  local isCellActive = true

  for row = 1, MAX_ROWS do
    isRowActive = (row <= grid.numRows)
    for column = 1, MAX_COLUMNS do
      isColumnActive = (column <= grid.numColumns)
      isCellActive = isRowActive and isColumnActive
      local cell =  grid.cells[row][column]
      if cell.image.value == CELL_COLLISION and cell.occupants.roverCount == 0 then
        cell.image.value = CELL_EMPTY
      end
      cell.image.enabled = isCellActive
      cell.image.visible = isCellActive
    end
  end

  local grid_east_x  = GRID_X + (grid.numColumns * CELL_SIZE) + 5
  local grid_south_y = GRID_Y + (grid.numRows * CELL_SIZE) + 5

  for row = 1, MAX_ROWS do
    isRowActive = (row <= grid.numRows)
    pitchLabelsEast[row].x =  grid_east_x
    pitchLabelsEast[row].enabled = isRowActive
    pitchLabelsEast[row].visible = isRowActive
    pitchLabelsWest[row].enabled = isRowActive
    pitchLabelsWest[row].visible = isRowActive
  end

  for column = 1, MAX_COLUMNS do
    isColumnActive = (column <= grid.numColumns)
    pitchLabelsSouth[column].y =  grid_south_y
    pitchLabelsSouth[column].enabled = isColumnActive
    pitchLabelsSouth[column].visible = isColumnActive
    pitchLabelsNorth[column].enabled = isColumnActive
    pitchLabelsNorth[column].visible = isColumnActive
  end

  -- manage rovers outside the active grid area
  local outliers = {}
  for i = 1, #rovers do
    local rover = rovers[i]
    if rover.row <= grid.numRows and rover.column <= grid.numColumns then
      rover.active = true
    else
      rover.active = false
      if outlierOption == OUTLIER_CORRAL then
        rover.active = true
        local newRow = clamp(rover.row, 1, grid.numRows)
        local newColumn = clamp(rover.column, 1, grid.numColumns)
        moveRover(rover, newRow, newColumn)       -- TODO: manage collisions !!
      elseif outlierOption == OUTLIER_REMOVE then
        table.insert(outliers,i)
      end
    end
  end
  -- remove outliers identified for deletion
  for i = 1, #outliers do
    local rover = rovers[i]
    local cell = grid.cells[rover.row][rover.column]
    cell.image.enabled = true
    cell:removeRover(rover)
    cell.image.enabled = false
    table.remove(rovers, outliers[i])
    rover:retire()
  end
end

local function setNumRows(numRows)
  grid.numRows = numRows
  redrawGrid()
end

local function setNumColumns(numColumns)
  grid.numColumns = numColumns
  redrawGrid()
end

--------------------------------------------------------------------------------
-- Sequencer
--------------------------------------------------------------------------------

local function setMaxRovers(count)
  maxRovers = count
  while #rovers > maxRovers do
    local rover = table.remove(rovers, #rovers)
    grid:removeRover(rover)
    rover:retire()
  end
end

local function clearPreviousStrikes()
  clearStrikes(wallNorth, pitchLabelsNorth)
  clearStrikes(wallEast, pitchLabelsEast)
  clearStrikes(wallSouth, pitchLabelsSouth)
  clearStrikes(wallWest, pitchLabelsWest)
end

local function showActiveStrikes()
  showStrikes(wallNorth, pitchLabelsNorth)
  showStrikes(wallEast, pitchLabelsEast)
  showStrikes(wallSouth, pitchLabelsSouth)
  showStrikes(wallWest, pitchLabelsWest)
end

local function stepOnce()
  clearPreviousStrikes()
  advanceRovers()
  showActiveStrikes()
end

function startPlaying()
  if isPlaying then
    return
  end
  run(sequenceRunner)
end

function stopPlaying()
  isPlaying = false
end

function sequenceRunner()
  isPlaying = false
  spawn(play)
end

local function round(num)
  -- https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
  return num + (2^52 + 2^51) - (2^52 + 2^51)
end

function play()
  isPlaying = true

  local playTime = 0

  -- print("Beat Duration", getBeatDuration())



  -- TODO: sync to transport
  -- transport(start)
  --  transportRunning = start
  -- end 
  -- if transportRunning then 
  --    local nextBeatTime = round((getRunningBeatTime() + clockRateBeats) / clockRateBeats) * clockRateBeats
  --    wait until that time
  -- else
  --  start right away 
  -- end 

  local nextBeatTime = round((getRunningBeatTime() + clockRateBeats) / clockRateBeats) * clockRateBeats
  if isTransportRunning then
    waitBeat(nextBeatTime - getRunningBeatTime())
  end

  -- local beatTime = getRunningBeatTime()
  -- local beatsToWait = math.ceil(beatTime) - beatTime
  -- waitBeat(beatsToWait)

  while isPlaying
  do
    -- round to nearest fraction of beatTime based on selected clock rate 
    -- local coeff = 1/clockRateBeats -- TODO: precompute this 
    -- local nextBeatTime = round((getRunningBeatTime() + clockRateBeats) * coeff) / coeff 
    nextBeatTime = round((getRunningBeatTime() + clockRateBeats) / clockRateBeats) * clockRateBeats

    stepOnce()
    playTime = playTime + getTime()
    if playTime >= 3000 then -- milliseconds 
      grid:forceRepaint()
      playTime = 0
    end

    --    waitBeat(clockRateBeats)
    -- beatsToWait = nextBeatTime - getRunningBeatTime()
    -- print("  wait:",getRunningBeatTime(),beatsToWait)
    waitBeat(nextBeatTime - getRunningBeatTime())
  end

    --TODO: wait 1 beat in loop
    --  beatCountdown = beatCountdown - 1
    --  if beatsCountdown == 0 
    --     stepOnce()
    --     beatCountdown = beats
    -- this way changing the tempo will not have to wait for a really long beat to expire
    -- max wait in the loop could be QuarterNote (1 beat) for example 

  -- KLUDGE: force grid refresh to clear out stuck images 
  grid:forceRepaint()


end

--------------------------------------------------------------------------------
-- UI Widgets
--------------------------------------------------------------------------------

local pitchRootWidget = NumBox("RootPitch", 60, 1, 127, true)
pitchRootWidget.unit = Unit.Generic
pitchRootWidget.textColour = "lightblue"
pitchRootWidget.backgroundColour = "black"
pitchRootWidget.displayName = "Root Pitch"
pitchRootWidget.tooltip = "Root Pitch"
pitchRootWidget.displayText = formatNoteName(60) -- TODO: use const
pitchRootWidget.size = {100,20}
pitchRootWidget.x = 5
pitchRootWidget.y = 90
pitchRootWidget.changed = function(self)
    -- TODO: update scales 
    self.displayText = formatNoteName(self.value)
    setRootPitch(self.value)
end

local scaleMenu = Menu("Scale", scaleNames)
scaleMenu.x = 5
scaleMenu.y = 30
scaleMenu.width = 130
-- scaleMenu.height = 45
scaleMenu.textColour = "lightblue"
scaleMenu.backgroundColour = "black"
scaleMenu.displayName = "Scale"
scaleMenu.tooltip = "Note Scale"
scaleMenu.showLabel = true
scaleMenu.value = 2 -- Major
scaleMenu.changed = function(self)
  setScale(scales[self.value][2])
end
scaleMenu:changed()

-- ----------------------------------------------------------
-- ATTENTION: use the (13 - x) trick to INVERT the row number 
-- so that the puck position in the XY cntroller matches the 
-- position of the lower right corner of the grid.

local gridResizeHandleWidget = Image("_images/drag-arrow-svgrepo-com.png")
gridResizeHandleWidget.visible = true
gridResizeHandleWidget.x = GRID_X
gridResizeHandleWidget.y = GRID_Y
gridResizeHandleWidget.setRow = function(self, rowNumber)
  self.y = GRID_Y + (CELL_SIZE * rowNumber)
end
gridResizeHandleWidget.setColumn = function(self, columnNumber)
  self.x = GRID_X + (CELL_SIZE * columnNumber) + 5
end

local numRowsWidgetHidden = Knob("NumRowsHidden", (13 - MAX_ROWS), 1, MAX_ROWS, true)
numRowsWidgetHidden.visible = false 

--local numRowsWidget = NumBox("NumRows", (13 - MAX_ROWS), 1, MAX_ROWS, true)
local numRowsWidget = NumBox("NumRows", MAX_ROWS, 1, MAX_ROWS, true)
-- local numRowsWidget = Knob("NumRows", 1, 1, MAX_ROWS, true)
numRowsWidget.displayName = "Rows"
numRowsWidget.outlineColour = "yellow"
numRowsWidget.tooltip = "Number of grid rows"
numRowsWidget.size = { 80, 20 }
numRowsWidget.x = 5
numRowsWidget.y = 215
numRowsWidget.changed = function(self)
  setNumRows(self.value)
  -- setNumRows((MAX_ROWS + 1) - self.value)
  -- self.displayText = tostring((MAX_ROWS + 1) - self.value)
  numRowsWidgetHidden:setValue(13 - self.value)
  gridResizeHandleWidget:setRow(self.value)
end

numRowsWidgetHidden.changed = function(self)
  numRowsWidget:setValue(13 - self.value)
end

-- local numColumnsWidget = Knob("NumColumns", MAX_COLUMNS, 1, MAX_COLUMNS, true)
local numColumnsWidget = NumBox("NumColumns", MAX_COLUMNS, 1, MAX_COLUMNS, true)
numColumnsWidget.displayName = "Columns"
numColumnsWidget.tooltip = "Number of grid columns"
numColumnsWidget.size = { 80, 20 }
numColumnsWidget.x = 5
numColumnsWidget.y = 245
numColumnsWidget.changed = function(self)
  setNumColumns(self.value)
  gridResizeHandleWidget:setColumn(self.value)
end

local gridResizeWidget = XY("NumColumns", "NumRowsHidden")
gridResizeWidget.x = GRID_X -- 5
gridResizeWidget.y = GRID_Y -- 245
gridResizeWidget.width = GRID_WIDTH + 20 -- 80
gridResizeWidget.height = GRID_HEIGHT + 20-- 80
gridResizeWidget.alpha = 0
gridResizeWidget.tooltip = "Grid Resize"

-- Create tge grid CELLS here so that the XY area is "under" the grid cells
for row = 1, MAX_ROWS do
  for column = 1, MAX_COLUMNS do
    grid.cells[row][column] = makeCell(row,column)
  end
end

numRowsWidget:changed()
numColumnsWidget:changed()


local clockMenu = Menu("Clock", tempoDivisionNames)
clockMenu.x = 5
clockMenu.y = 120
clockMenu.width = 70
clockMenu.textColour = "lightblue"
clockMenu.backgroundColour = "black"
clockMenu.displayName = "Clock"
clockMenu.tooltip = "Clock Rate"
clockMenu.changed = function(self)
  local numBeats = tempoDivisions[self.value][2]
  setClockRate(numBeats)
end
clockMenu:setValue(tableLookup(tempoDivisionNames, "1/8"), true) -- TODO use const 

local rateMultiplierWidget = Knob("RateMultiplier", 1, 0.5, 2, false)
rateMultiplierWidget.displayName = "Clock Mult"
rateMultiplierWidget.tooltip = "Clock Rate Multiplier"
rateMultiplierWidget.mapper = Mapper.Exponential
rateMultiplierWidget.x = 15
rateMultiplierWidget.y = 175
rateMultiplierWidget.height = 30
rateMultiplierWidget.changed = function(self)
  setClockRateMultiplier(1/self.value)
end

local playButton = OnOffButton("Play", false)
playButton.persistent = false
playButton.backgroundColourOff = "#ff084486"
playButton.backgroundColourOn = "#ff02ACFE"
playButton.textColourOff = "#ff22FFFF"
playButton.textColourOn = "#efFFFFFF"
playButton.displayName = "Play"
playButton.size = {80, 20}
playButton.x = 5
playButton.y = 5

local stepButton = Button("Step")
stepButton.persistent = false
stepButton.backgroundColourOff = "#ff084486"
stepButton.backgroundColourOn = "#ff02ACFE"
stepButton.textColourOff = "#ff22FFFF"
stepButton.textColourOn = "#efFFFFFF"
stepButton.displayName = "Step"
stepButton.size = {80, 20}
stepButton.x = 95
stepButton.y = 5
stepButton.changed = function(self)
  if not isPlaying then
    isPlaying = true
    redrawGrid()
    stepOnce()
    isPlaying = false
    grid:forceRepaint()  -- KLUDGE: force grid refresh to clear out stuck images 
  end
end

playButton.changed = function(self)
  if self.value == true then
    stepButton.enabled = false
    redrawGrid()
    startPlaying()
  else
    stepButton.enabled = true
    stopPlaying()
  end
end

local clearAllButton = Button("ClearAll", false)
clearAllButton.persistent = false
clearAllButton.backgroundColourOff = "#ff084486"
clearAllButton.backgroundColourOn = "#ff02ACFE"
clearAllButton.textColourOff = "#ff22FFFF"
clearAllButton.textColourOn = "#efFFFFFF"
clearAllButton.displayName = "Clear All"
clearAllButton.tooltip = "Remove all Rovers and Obstacles"
clearAllButton.size = {80, 20}
clearAllButton.x = GRID_X_RIGHT + 10
clearAllButton.y = 380
clearAllButton.changed = function(self)
  playButton:setValue(false)
  grid:clearAll()
  retireAllRovers()
  redrawGrid()
  clearPreviousStrikes()
end

local clearRoversButton = Button("ClearRovers", false)
clearRoversButton.persistent = false
clearRoversButton.backgroundColourOff = "#ff084486"
clearRoversButton.backgroundColourOn = "#ff02ACFE"
clearRoversButton.textColourOff = "#ff22FFFF"
clearRoversButton.textColourOn = "#efFFFFFF"
clearRoversButton.displayName = "Clear Rovers"
clearRoversButton.tooltip = "Remove all Rovers"
clearRoversButton.size = {80, 20}
clearRoversButton.x = GRID_X_RIGHT + 10
clearRoversButton.y = 410
clearRoversButton.changed = function(self)
  playButton:setValue(false)
  grid:clearRovers()
  retireAllRovers()
  redrawGrid()
  clearPreviousStrikes()
end

local clearObstaclesButton = Button("ClearObstacles", false)
clearObstaclesButton.persistent = false
clearObstaclesButton.backgroundColourOff = "#ff084486"
clearObstaclesButton.backgroundColourOn = "#ff02ACFE"
clearObstaclesButton.textColourOff = "#ff22FFFF"
clearObstaclesButton.textColourOn = "#efFFFFFF"
clearObstaclesButton.displayName = "Clear Obstacles"
clearObstaclesButton.tooltip = "Remove all Obstacles"
clearObstaclesButton.size = {80, 20}
clearObstaclesButton.x = GRID_X_RIGHT + 10
clearObstaclesButton.y = 440
clearObstaclesButton.changed = function(self)
  grid:clearObstacles()
  -- obstacles = {}
  redrawGrid()
  clearPreviousStrikes()
end

local rotateNorthWidget = Slider("PitchOffsetNorth", 0, -24, 24, true, false)
rotateNorthWidget.backgroundColour = "darkgray"
rotateNorthWidget.showLabel = false
--rotateNorthWidget.showPopupDisplay = false
rotateNorthWidget.tooltip = "North wall pitch offset"
rotateNorthWidget.size = {110,20}
rotateNorthWidget.x = 300
rotateNorthWidget.y = 5
rotateNorthWidget.changed = function(self)
    wallNorth:rotatePitches(self.value)
    populatePitchLabels(wallNorth, pitchLabelsNorth)
end

local rotateEastWidget = Slider("PitchOffsetEast", 0, -24, 24, true, true)
rotateEastWidget.backgroundColour = "darkgray"
rotateEastWidget.showLabel = false
--rotateEastWidget.showPopupDisplay = false
rotateEastWidget.tooltip = "East wall pitch offset"
rotateEastWidget.size = {20, 110}
rotateEastWidget.x = 585
rotateEastWidget.y = 175
rotateEastWidget.changed = function(self)
    wallEast:rotatePitches(self.value)
    populatePitchLabels(wallEast, pitchLabelsEast)
end

local rotateSouthWidget = Slider("PitchOffsetSouth", 0, -24, 24, true, false)
rotateSouthWidget.backgroundColour = "darkgray"
rotateSouthWidget.showLabel = false
--rotateSouthWidget.showPopupDisplay = false
rotateSouthWidget.tooltip = "South wall pitch offset"
rotateSouthWidget.size = {110,20}
rotateSouthWidget.x = 300
rotateSouthWidget.y = 445
rotateSouthWidget.changed = function(self)
    wallSouth:rotatePitches(self.value)
    populatePitchLabels(wallSouth, pitchLabelsSouth)
end

local rotateWestWidget = Slider("PitchOffsetWest", 0, -24, 24, true, true)
rotateWestWidget.backgroundColour = "darkgray"
rotateWestWidget.showLabel = false
-- rotateWestWidget.showPopupDisplay = true
rotateWestWidget.tooltip = "West wall pitch offset"
rotateWestWidget.size = {20, 110}
rotateWestWidget.x = 120
rotateWestWidget.y = 175
rotateWestWidget.changed = function(self)
    wallWest:rotatePitches(self.value)
    populatePitchLabels(wallWest, pitchLabelsWest)
end


local ascendNorthWidget = OnOffButton("AscendNorth", true)
ascendNorthWidget.showLabel = false
ascendNorthWidget.normalImage = "_images/traveler_descending.png"
ascendNorthWidget.pressedImage = "_images/traveler_ascending.png"
ascendNorthWidget.exported = true
ascendNorthWidget.tooltip = "Ascending/Descending order of pitches on North wall"
ascendNorthWidget.x = GRID_X + 90
ascendNorthWidget.y = 5
ascendNorthWidget.changed = function(self)
  wallNorth:setPitchesAscending(self.value)
  populatePitchLabels(wallNorth, pitchLabelsNorth)
end

local ascendEastWidget = OnOffButton("AscendEast", true)
ascendEastWidget.showLabel = false
ascendEastWidget.normalImage = "_images/traveler_descending.png"
ascendEastWidget.pressedImage = "_images/traveler_ascending.png"
ascendEastWidget.exported = true
ascendEastWidget.tooltip = "Ascending/Descending order of pitches on East wall"
ascendEastWidget.x = GRID_X_RIGHT - 32
ascendEastWidget.y = 150
ascendEastWidget.changed = function(self)
  wallEast:setPitchesAscending(self.value)
  populatePitchLabels(wallEast, pitchLabelsEast)
end

local ascendSouthWidget = OnOffButton("AscendSouth", true)
ascendSouthWidget.showLabel = false
ascendSouthWidget.normalImage = "_images/traveler_descending.png"
ascendSouthWidget.pressedImage = "_images/traveler_ascending.png"
ascendSouthWidget.exported = true
ascendSouthWidget.tooltip = "Ascending/Descending order of pitches on South wall"
ascendSouthWidget.x = GRID_X + 90
ascendSouthWidget.y = 445
ascendSouthWidget.changed = function(self)
  wallSouth:setPitchesAscending(self.value)
  populatePitchLabels(wallSouth, pitchLabelsSouth)
end

local ascendWestWidget = OnOffButton("AscendWest", true)
ascendWestWidget.showLabel = false
ascendWestWidget.normalImage = "_images/traveler_descending.png"
ascendWestWidget.pressedImage = "_images/traveler_ascending.png"
ascendWestWidget.exported = true
ascendWestWidget.tooltip = "Ascending/Descending order of pitches on West wall"
ascendWestWidget.x = GRID_X - 63
ascendWestWidget.y = 150
ascendWestWidget.changed = function(self)
  wallWest:setPitchesAscending(self.value)
  populatePitchLabels(wallWest, pitchLabelsWest)
end






scaleMenu:changed()
pitchRootWidget:changed()

rotateNorthWidget:changed()
rotateEastWidget:changed()
rotateSouthWidget:changed()
rotateWestWidget:changed()

ascendNorthWidget:changed()

local wobbleWidget = Knob("Wobble", 0, 0, 1, false)
wobbleWidget.Unit = Unit.Percent
wobbleWidget.mapper = Mapper.Quadratic
wobbleWidget.displayText = formatPercent(0)
wobbleWidget.outlineColour = "red"
wobbleWidget.x = GRID_X_RIGHT
wobbleWidget.y = 40
wobbleWidget.changed = function(self)
  wobblePercent = self.value
  self.displayText = formatPercent(self.value * 100)
end

-- Wall slide 

-- local northSlideLabel = Label("NothSlideLabel", "0")
-- northSlideLabel.x = 490
-- northSlideLabel.y = 0
-- northSlideLabel.editable = false
-- northSlideLabel.interceptsMouseClicks = false
-- northSlideLabel.showLabel = false
-- northSlideLabel.text = "0"

local wallNorthSlideWidget = NumBox("NorthSlide", 0, -(MAX_COLUMNS - 1), (MAX_COLUMNS - 1), true)
-- local wallNorthSlideWidget = Knob("NorthSlide", 0, -(MAX_COLUMNS - 1), (MAX_COLUMNS - 1), true)
--local wallNorthSlideWidget = MultiStateButton("NorthSlide", { "<", ".", ">"})
--wallNorthSlideWidget.displayName = "Slide"
wallNorthSlideWidget.showLabel = false
wallNorthSlideWidget.showValue = true
wallNorthSlideWidget.showPopupDisplay = true
wallNorthSlideWidget.tooltip = "Column shift after North wall strike"
wallNorthSlideWidget.backgroundColor = "blue"
wallNorthSlideWidget.size = {30,20}
wallNorthSlideWidget.x = 415
wallNorthSlideWidget.y = 5
wallNorthSlideWidget.changed = function(self)
  print("WallNorthSlide", self.value)
  wallNorth.slideAmount = self.value
--  northSlideLabel.text = tostring(self.value)
end

local wallEastSlideWidget = NumBox("EastSlide", 0, -(MAX_COLUMNS - 1), (MAX_COLUMNS - 1), true)
wallEastSlideWidget.showLabel = false
wallEastSlideWidget.showValue = true
wallEastSlideWidget.showPopupDisplay = true
wallEastSlideWidget.tooltip = "Row shift after East wall strike"
wallEastSlideWidget.backgroundColor = "blue"
wallEastSlideWidget.size = {30,20}
wallEastSlideWidget.x = GRID_X_RIGHT - 30
wallEastSlideWidget.y = 295
wallEastSlideWidget.changed = function(self)
  wallEast.slideAmount = self.value
end

local wallSouthSlideWidget = NumBox("SouthSlide", 0, -(MAX_COLUMNS - 1), (MAX_COLUMNS - 1), true)
wallSouthSlideWidget.showLabel = false
wallSouthSlideWidget.showValue = true
wallSouthSlideWidget.showPopupDisplay = true
wallSouthSlideWidget.tooltip = "Column shift after South wall strike"
wallSouthSlideWidget.backgroundColor = "blue"
wallSouthSlideWidget.size = {30,20}
wallSouthSlideWidget.x = 415
wallSouthSlideWidget.y = 445
wallSouthSlideWidget.displayName = "South Slide"
wallSouthSlideWidget.changed = function(self)
  wallSouth.slideAmount = self.value
end


local wallWestSlideWidget = NumBox("WestSlide", 0, -(MAX_COLUMNS - 1), (MAX_COLUMNS - 1), true)
wallWestSlideWidget.showLabel = false
wallWestSlideWidget.showValue = true
wallWestSlideWidget.showPopupDisplay = true
wallWestSlideWidget.tooltip = "Row shift after West wall strike"
wallWestSlideWidget.backgroundColor = "blue"
wallWestSlideWidget.size = {30,20}
wallWestSlideWidget.x = GRID_X - 65
wallWestSlideWidget.y = 295
wallWestSlideWidget.changed = function(self)
  wallWest.slideAmount = self.value
end

-- Velocity 
local velocityWidget = Knob("Velocity", 100, 0, 127, true)
velocityWidget.outlineColour = "green"
velocityWidget.x = 5
velocityWidget.y = 327
velocityWidget.changed = function(self)
  noteVelocity = self.value
end

local velocityChaosWidget = Knob("VelocityChaos", 0, 0, 100, false)
velocityChaosWidget.unit = Unit.Percent
velocityChaosWidget.displayName = "Vel Chaos"
velocityChaosWidget.tooltip = "Velocity Chaos"
velocityChaosWidget.outlineColour = "green"
velocityChaosWidget.x = 30
velocityChaosWidget.y = 370
velocityChaosWidget.height = 40
velocityChaosWidget.changed = function(self)
  noteVelocityChaos = self.value * 0.01
end

local gateLengthWidget = Knob("GateLength", gateLengthPercent * 100, 0, 400, false)
gateLengthWidget.unit = Unit.Percent
gateLengthWidget.mapper = Mapper.Quadratic
gateLengthWidget.displayName = "Gate Len"
gateLengthWidget.tooltip = "Gate Length Multiplier"
gateLengthWidget.outlineColour = "orange"
gateLengthWidget.x = 5
gateLengthWidget.y = 420
gateLengthWidget.changed = function(self)
  setGateLengthPercent(self.value * 0.01)
end


local outlierMenuWidget = Menu("Outliers", outlierOptionNames)
outlierMenuWidget.textColour = "lightblue"
outlierMenuWidget.backgroundColour = "black"
outlierMenuWidget.displayName = "Outliers"
outlierMenuWidget.tooltip = "How to treat Rovers outside the grid boundary"
outlierMenuWidget.showLabel = true
outlierMenuWidget.value = OUTLIER_CORRAL
outlierMenuWidget.x = 5
outlierMenuWidget.y = 270
outlierMenuWidget.size = {79,45}
outlierMenuWidget.changed = function(self)
  outlierOption = outlierOptions[self.value][2]
end
outlierMenuWidget:changed()


local function disperseRovers()
  for i = 1,#rovers do
    local rover = rovers[i]
    if rover.active then
      grid:removeRover(rover)
      -- give 3 tries to put each rover into an empty cell
      rover:randomize()
      local numTries = 1
      while grid.cells[rover.row][rover.column].image.value ~= CELL_EMPTY and numTries <= 3 do
        rover:randomize()
        numTries = numTries + 1
      end
      grid:addRover(rover)
    end
  end
  redrawGrid()
  clearPreviousStrikes()
end

local disperseButton = Button("Disperse", false)
disperseButton.persistent = false
disperseButton.backgroundColourOff = "#ff084486"
disperseButton.backgroundColourOn = "#ff02ACFE"
disperseButton.textColourOff = "#ff22FFFF"
disperseButton.textColourOn = "#efFFFFFF"
disperseButton.displayName = "Disperse"
disperseButton.size = {80, 20}
disperseButton.x = GRID_X_RIGHT - 90
disperseButton.y = 5
disperseButton.changed = function(self)
  disperseRovers()
end

local pauseCollideButton = OnOffButton("PauseCollide", false)
pauseCollideButton.backgroundColourOff = "#ff084486"
pauseCollideButton.backgroundColourOn = "#ff02ACFE"
pauseCollideButton.textColourOff = "#ff22FFFF"
pauseCollideButton.textColourOn = "#efFFFFFF"
pauseCollideButton.displayName = "Pause Collide"
pauseCollideButton.tooltip = "Pause rovers to break up a collision"
pauseCollideButton.size = {80, 20}
pauseCollideButton.x = GRID_X_RIGHT + 10
pauseCollideButton.y = 90
pauseCollideButton.changed = function(self)
  pauseOnCollide = self.value
end

local pauseButton = OnOffButton("PauseChord", false)
pauseButton.backgroundColourOff = "#ff084486"
pauseButton.backgroundColourOn = "#ff02ACFE"
pauseButton.textColourOff = "#ff22FFFF"
pauseButton.textColourOn = "#efFFFFFF"
pauseButton.displayName = "Pause Multi"
pauseButton.tooltip = "Pause rovers to break up a multi-strike (chord), prefer single note sequences"
pauseButton.size = {80, 20}
pauseButton.x = GRID_X_RIGHT + 10
pauseButton.y = 120
pauseButton.changed = function(self)
  pauseOnChord = self.value
end

--local maxRoversWidget = NumBox("MaxRovers", MAX_ROVERS, 1, MAX_ROVERS, true)
local maxRoversWidget = Knob("MaxRovers", MAX_ROVERS, 1, MAX_ROVERS, true)
maxRoversWidget.showLabel = true
maxRoversWidget.showValue = true
maxRoversWidget.showPopupDisplay = true
maxRoversWidget.textColour = "lightblue"
maxRoversWidget.backgroundColour = "black"
maxRoversWidget.outlineColour = "lightblue"
maxRoversWidget.displayName = "Max Rovers"
maxRoversWidget.tooltip = "Maximum number of rovers"
maxRoversWidget.height = 30
maxRoversWidget.x = GRID_X_RIGHT + 10
maxRoversWidget.y = 160
maxRoversWidget.changed = function(self)
  setMaxRovers(self.value)
end

local sharpFlatButton = OnOffButton("SharpFlat", true)
sharpFlatButton.normalImage = "_images/flat.png"
sharpFlatButton.pressedImage = "_images/sharp.png"
sharpFlatButton.tooltip = "Select Sharps (#) or Flats (b) for note names"
sharpFlatButton.x = 110
sharpFlatButton.y = 90
sharpFlatButton.changed = function(self)
  setDisplayAccidentalsSharp(self.value)
  pitchRootWidget:changed()
end
sharpFlatButton:changed()

-- Event Callbacks 

-- local autoplayButton = OnOffButton("AutoPlay", true)
-- autoplayButton.backgroundColourOff = "#ff084486"
-- autoplayButton.backgroundColourOn = "#ff02ACFE"
-- autoplayButton.textColourOff = "#ff22FFFF"
-- autoplayButton.textColourOn = "#efFFFFFF"
-- autoplayButton.displayName = "Auto Play"
-- autoplayButton.tooltip = "Play automatically on transport"
-- --autoplayButton.size = channelButton.size
-- --autoplayButton.x = channelButton.x + channelButton.width + 5
-- --autoplayButton.y = channelButton.y

-- function onTransport(isRunning)
--   if autoplayButton.value == true then
--     playButton:setValue(isRunning)
--   end
-- end

function onTransport(isRunning)
  isTransportRunning = isRunning
end

makePerformanceView()