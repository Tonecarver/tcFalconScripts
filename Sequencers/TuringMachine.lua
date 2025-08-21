-- TuringMachine --

local function tableLookup(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

local function makeTable(size,initialValue)
  local theTable = {}
  theTable[0] = size
  for i = 1, size do
    theTable[i] = initialValue
  end
  return theTable
end

local function round(num)
  -- https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
  return num + (2^52 + 2^51) - (2^52 + 2^51)
end

-- 

local isPlaying = false
local isTransportRunning = false

local MAX_SEQUENCE_LENGTH = 32
local DEFAULT_SEQUENCE_LENGTH = 16

-- The first "valueLength" bits represent the value (0..255)
-- shiftRegister[1] == Most Significant Bit (MSB)
-- shiftRegister[valueLength] == Least Significant Bit (LSB)

--- Shift Register "Seed" is the value of the register when it is initialized/filled
---   A "reset" operation loads the seed back into the shift register
---   A "preserve" operation copies the existing shoft register contents to the seed
--- 
local shiftRegisterSeed = makeTable(MAX_SEQUENCE_LENGTH, 0)
local shiftRegister = makeTable(MAX_SEQUENCE_LENGTH, 0)
local sequenceLength = DEFAULT_SEQUENCE_LENGTH
local valueLength = 8
local valueDivisor = ((2 ^ valueLength) - 1)


local invertProbability = 0.25 -- sequence chaos
local skipProbability = 0

local freeze = false
local forceOnes = false
local forceZeroes = false

local leds = makeTable(MAX_SEQUENCE_LENGTH, nil) -- UI elements

local notePlayed = nil -- most recently emitted note 

local function fillShiftRegisterRandom()
  for i = 1, MAX_SEQUENCE_LENGTH do
    shiftRegister[i] = (0.5 > math.random()) and 1 or 0
  end
end

local function copySeedToShiftRegister()
  for i = 1, MAX_SEQUENCE_LENGTH do
    shiftRegister[i] = shiftRegisterSeed[i]
  end
end

local function copyShiftRegisterToSeed()
  for i = 1, MAX_SEQUENCE_LENGTH do
    shiftRegisterSeed[i] = shiftRegister[i]
  end
end


-- Min/Max Note Range 
-- TODO: add button to select sharps vs flats 

local pitchNamesFlats  = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local pitchNamesSharps = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
local useFlats = true
local pitchNames = pitchNamesFlats

local function formatNoteName(noteNumber)
  local octave = noteNumber % 12
  return tostring(noteNumber) .. " ("..pitchNames[octave + 1]..tostring((noteNumber - octave) / 12 - 2)..")"
end

-- 

local function enableActiveLeds()
  for i = 1, MAX_SEQUENCE_LENGTH do -- TODO: CONST 
    leds[i].visible = (i <= sequenceLength)
  end
end

local function updateLeds()
  for i = 1,sequenceLength do
    leds[i].value = (shiftRegister[i] == 1)
  end
end

-- TODO: remove LED tooltip 

local function updateValueLength()
  valueLength = math.min(sequenceLength, 8)
  valueDivisor = (2 ^ valueLength) - 1
end

local function setSequenceLength(numBits)
  sequenceLength = numBits
  updateValueLength()
  enableActiveLeds()
end

local function insertBit(bitval)
  -- shift the shiftRegister contents
  for i = sequenceLength,2,-1 do
    shiftRegister[i] = shiftRegister[i-1]
  end
  shiftRegister[1] = bitval  -- insert feedback value 
end

local function updateShiftRegister()
  -- get feedback value, apply modifications 
  local nextInput = shiftRegister[sequenceLength]

  if not freeze then
    if forceOnes then
      nextInput = 1
    elseif forceZeroes then
      nextInput = 0
    elseif invertProbability > 0 and invertProbability >= math.random() then
      if nextInput >= 1 then
        nextInput = 0
      else
        nextInput = 1
      end
    end
  end

  insertBit(nextInput)
end

local function getValue()
  local value = 0
  local factor = 1
  for i = valueLength,1,-1 do
    value = value + (shiftRegister[i] * factor)
    factor = factor * 2
  end
  return value
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
  { '1x dot',     bars(1.5)   },
  { '1x',         bars(1)     },
  { '1/2 dot',   beats(3)    },
  { '1x trip',    bars(2/3)   },
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
-- Min/Max Note Range
--------------------------------------------------------------------------------

local DEFAULT_MIDI_NOTE_MIN = 60
local DEFAULT_MIDI_NOTE_MAX = 84

local midiNoteMin = DEFAULT_MIDI_NOTE_MIN
local midiNoteMax = DEFAULT_MIDI_NOTE_MAX

local function setMidiNoteRange(min,max)
  if min <= max then
    midiNoteMin = min
    midiNoteMax = max
    -- print("Noswap: min", midiNoteMin, "max", midiNoteMax)
  else -- swap ends
    midiNoteMin = max
    midiNoteMax = min
    -- print("  SWAP: min", midiNoteMin, "max", midiNoteMax)
  end
end

--------------------------------------------------------------------------------
-- Pitch Quantization
--------------------------------------------------------------------------------

-- -- 12 tone western scale 
--   C = scale[1]
--   C# = scale[2]
--   etc 
local scaleRaw       = { true, false, false, false, false,false, false, false, false,false, false, false  }
local scaleEffective = { true, false, false, false, false,false, false, false, false,false, false, false  }
local numActiveNotes = 1

local tonicNoteOffset = 0

local QUANTIZE_NEAREST = 1
local QUANTIZE_UP = 2
local QUANTIZE_DOWN = 3
local QUANTIZE_DROP = 4
local pitchQuantizeMode = QUANTIZE_NEAREST

local pitchQuantizeMap = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
--   holds delta offset to map in degree to out degree, -11 .. 0 .. 11 
--   degreeOut = pitchQuantizeRemap[degreeIn] 

local function findDegreeOffsetLower(degree)
  local candidate = degree - 1
  for i = 1, 11 do
    if candidate < 1 then
      candidate = 12
    end
    if scaleEffective[candidate] then
      return (candidate < degree) and (candidate - degree) or ((candidate - 12) - degree)
    end
    candidate = candidate - 1
  end
end

local function findDegreeOffsetHigher(degree)
  local candidate = degree + 1
  for i = 1, 11 do
    if candidate > 12 then
      candidate = 1
    end
    if scaleEffective[candidate] then
      return (candidate > degree) and (candidate - degree) or ((candidate + 12) - degree)
    end
    candidate = candidate + 1
  end
end


local function populatePitchQuantizeMap()
  -- assumption is that there will always be at least 1 note active .. 
  for degree = 1, 12 do
    if scaleEffective[degree] == true then
      pitchQuantizeMap[degree] = 0  -- no change, degree is in scale 
    else
      local offsetLower = findDegreeOffsetLower(degree)
      local offsetHigher = findDegreeOffsetHigher(degree)
      if pitchQuantizeMode == QUANTIZE_NEAREST then
        if math.abs(offsetLower) > math.abs(offsetHigher) then
          pitchQuantizeMap[degree] = offsetLower
        else
          pitchQuantizeMap[degree] = offsetHigher
        end
      elseif pitchQuantizeMode == QUANTIZE_UP then
        pitchQuantizeMap[degree] = offsetHigher
      elseif pitchQuantizeMode == QUANTIZE_DOWN then
        pitchQuantizeMap[degree] = offsetLower
      end
    end
  end
end

local function quantizePitchToScale(noteNumber)
  local degree = (noteNumber % 12) + 1
  if scaleEffective[degree] == false then
    if pitchQuantizeMode == QUANTIZE_DROP then
      return nil
    else
      local quantizedNoteNumber = noteNumber + pitchQuantizeMap[degree]
      if noteNumber < midiNoteMin or noteNumber > midiNoteMax then
        return nil -- outside of range -- TODO: foldit back into the range ?? 
      end
      return quantizedNoteNumber
    end
  end
  return noteNumber
end

-- Keyboard scale selector 
local SCALE_X = 10
local SCALE_Y = 33

local KEY_HEIGHT = 20
local KEY_WIDTH  = 20

local KEY_LED_HEIGHT = 3
local KEY_LED_WIDTH  = KEY_WIDTH - 6

local keyboardLayout = {
  { 0, 1 }, -- C    { x offset in number of "halfkey" widths, y offset in row where flats are at row 0 and naturals at row 1 }
  { 1, 0 }, -- C# 
  { 2, 1 }, -- D
  { 3, 0 }, -- D# 
  { 4, 1 }, -- E
  { 6, 1 }, -- F 
  { 7, 0 }, -- F# 
  { 8, 1 }, -- G 
  { 9, 0 }, -- G# 
  { 10, 1 }, -- A
  { 11, 0 }, -- A# 
  { 12, 1 }, -- B
}

local degreeWidgets = {}
local ledWidgets = {}

local function ensureMinimumNotesActive()
  if numActiveNotes == 1 then
    for i = 1, 12 do
      degreeWidgets[i].interceptsMouseClicks = not scaleEffective[i] -- lock last note so that num notes >= 1
    end
  else
    for i = 1, 12 do
      degreeWidgets[i].interceptsMouseClicks = true -- numNOtes >= 2, allow all notes to be selected
    end
  end
end

local function repaintScaleKeyboard()
  for i = 1, 12 do
     degreeWidgets[i]:setValue(scaleEffective[i], false)
  end
end

local function handleScaleChange()
  numActiveNotes = 0
  -- Copy the scaleRaw (withour root offset applied) to scaleEffective applying the rootNoteOffset 
  for i = 1,12 do
    local toIdx = i + tonicNoteOffset
    if toIdx > 12 then 
      toIdx = toIdx - 12
    end
    -- print("  copy scaleRaw["..i.."] ("..tostring(scaleRaw[i])..") to scaleEffective["..toIdx.."]")
    scaleEffective[toIdx] = scaleRaw[i]
    if scaleEffective[toIdx] then
      numActiveNotes = numActiveNotes + 1
    end
  end
  ensureMinimumNotesActive()
  populatePitchQuantizeMap()
  repaintScaleKeyboard()
end

local function setScaleDegree(degree, isEnabled)
  -- adjust the degree to account for the root offset
  local toIdx = degree - tonicNoteOffset
  if toIdx < 1 then
    toIdx = toIdx + 12
  end
  scaleRaw[toIdx] = isEnabled
  handleScaleChange()
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
--   { "Dark Aegean", {0, 5, 8, 12, 13, 17, 19, 20} },
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


--------------------------------------------------------------------------------
-- Midi note generation
--------------------------------------------------------------------------------

local noteVelocity = 100
local noteVelocityChaos = 0

local midiChannel = 1

local function setNominalVelocity(value)
  noteVelocity = value
end

local function setVelocityChaos(value)
  noteVelocityChaos = value
end

local colorLedOn = "goldenrod"
local colorLedOff = "darkgray"
local colorKeyOn = "goldenrod"
local colorKeyOff = "darkgray"

local function sendMidiNote()
  if notePlayed ~= nil then -- extinguish LED indicating which scale degree was recently played 
    ledWidgets[(notePlayed % 12) + 1].backgroundColour = colorLedOff
    notePlayed = nil
  end

  if skipProbability > math.random() then
    return
  end

  if gateLengthBeats <= 0 then
    return
  end

  local value = getValue()
  local depth = value / valueDivisor
  local midiNoteSpan = (midiNoteMax - midiNoteMin)
  local noteNumber = nil

  noteNumber = math.ceil(midiNoteMin + (depth * midiNoteSpan))
  noteNumber = quantizePitchToScale(noteNumber)
  if noteNumber == nil then
    -- print("Note == nil")
    return
  end

  local velocity = noteVelocity + (math.random(-1,1) * (noteVelocityChaos * 128))
  if velocity > 0 then
    if velocity > 127 then
      velocity = 127
    end
    -- print("note: value", value, "(velocity", velocity, ") = midi", noteNumber)
    local voiceId = playNote(noteNumber, velocity, beat2ms(gateLengthBeats), nil, midiChannel)

    -- light the LED indicating which scale degree is being played 
    notePlayed = noteNumber
    ledWidgets[(notePlayed % 12) + 1].backgroundColour = colorLedOn
  end
end

--------------------------------------------------------------------------------
-- User Interface
--------------------------------------------------------------------------------

local backgroundColour = "303030" -- Light or Dark
local widgetBackgroundColour = "01011F" -- Dark
local widgetTextColour = "66ff99" -- Light
local labelTextColour = "black"
local labelBackgoundColour = "white"
-- local menuBackgroundColour = "01011F"
-- local menuArrowColour = "66" .. labelTextColour
-- local menuOutlineColour = "5f" .. widgetTextColour
-- local backgroundColourOff = "ff084486"
-- local backgroundColourOn = "ff02ACFE"
-- local textColourOff = "ff22FFFF"
-- local textColourOn = "efFFFFFF"

-- local colours = {
--   backgroundColour = backgroundColour,
--   widgetBackgroundColour = widgetBackgroundColour,
--   widgetTextColour = widgetTextColour,
--   labelTextColour = labelTextColour,
--   menuBackgroundColour = menuBackgroundColour,
--   menuArrowColour = menuArrowColour,
--   menuOutlineColour = menuOutlineColour,
--   backgroundColourOff = backgroundColourOff,
--   backgroundColourOn = backgroundColourOn,
--   textColourOff = textColourOff,
--   textColourOn = textColourOn,
-- }


local function formatPercent(value)
  return string.format("%0.1f %%", value)
end

--------------------------------------------------------------------------------
-- Panel Definitions
--------------------------------------------------------------------------------

setBackgroundColour(backgroundColour)

local sequencerPanel = Panel("Sequencer")
sequencerPanel.backgroundColour = backgroundColour
sequencerPanel.x = 10
sequencerPanel.y = 10
sequencerPanel.width = 700
sequencerPanel.height = 30

local settingsPanel = Panel("Settings")
settingsPanel.backgroundColour = "404040"
settingsPanel.x = sequencerPanel.x
settingsPanel.y = sequencerPanel.y + sequencerPanel.height + 5
settingsPanel.width = 700
settingsPanel.height = 100

local notePanel = Panel("Notes")
notePanel.backgroundColour = "404040"
notePanel.x = settingsPanel.x
notePanel.y = settingsPanel.y + settingsPanel.height + 5
notePanel.width = 700
notePanel.height = 100

-- Led Bank for Shift Register 

local LED_SIZE = 8
local LED_GAP  = 5

local ledPanel = Panel("LedPanel")
ledPanel.x = 275
ledPanel.y = 110
ledPanel.width = (MAX_SEQUENCE_LENGTH * (LED_SIZE + LED_GAP)) + 5
ledPanel.height = LED_SIZE + 4

for i = 1, MAX_SEQUENCE_LENGTH do
  local led = ledPanel:OnOffButton("Led"..i, false)
  led.visible = true
  led.interceptsMouseClicks = false
  led.persistent = false
  led.showLabel = false
  led.displayName = " "
  led.backgroundColourOff = "black" -- "darkgray"
  led.backgroundColourOn  = "lightblue" -- "orange" --  "lightgreen"
  if i <= 8 then 
    led.backgroundColourOn  = "red"
  end
  led.x = LED_GAP + ((i-1) * (LED_SIZE + LED_GAP))
  led.y = 2
  led.height = LED_SIZE
  led.width = LED_SIZE
  leds[i] = led
end

local valueLabel = Label("Value")
valueLabel.align = "right"
valueLabel.text = "<->"
valueLabel.textColour = "darkkhaki"
valueLabel.width = 30
valueLabel.x = ledPanel.x
valueLabel.y = ledPanel.y + ledPanel.height

local sequenceLengthMarkerWidget = OnOffButton("SequenceLengthMarker", false)
sequenceLengthMarkerWidget.visible = true
sequenceLengthMarkerWidget.interceptsMouseClicks = false
sequenceLengthMarkerWidget.persistent = false
sequenceLengthMarkerWidget.showLabel = false
sequenceLengthMarkerWidget.displayName = " "
sequenceLengthMarkerWidget.backgroundColourOff = "gray" -- "gold" -- "green" -- darkgray"
sequenceLengthMarkerWidget.backgroundColourOn  = "purple" -- "orange" --  "lightgreen"
sequenceLengthMarkerWidget.x = ledPanel.x + 5
sequenceLengthMarkerWidget.y = ledPanel.y + ledPanel.height + 1
sequenceLengthMarkerWidget.height = 3
sequenceLengthMarkerWidget.width = 8 -- (12 * (sequenceLength)) - 10 -- 8

local scaleEditWidget = notePanel:Label("ScaleEdit")
scaleEditWidget.text = "*"
scaleEditWidget.fontSize = 24
scaleEditWidget.textColour = "goldenrod"
scaleEditWidget.height = 30
scaleEditWidget.height = 30
scaleEditWidget.x = 165
scaleEditWidget.y = 3
scaleEditWidget.visible = false

for i = 1, 12 do
  local degreeWidget = notePanel:OnOffButton("Degree_"..i)
  degreeWidget.showLabel = false
  degreeWidget.displayName = " "
  degreeWidget.backgroundColourOff = colorKeyOff
  degreeWidget.backgroundColourOn = colorKeyOn
  degreeWidget.value = scaleEffective[i]
  degreeWidget.width = KEY_WIDTH
  degreeWidget.height = KEY_HEIGHT
  degreeWidget.x = SCALE_X + (keyboardLayout[i][1] * (KEY_WIDTH / 2)) + ((i-1) * 1)
  degreeWidget.y = SCALE_Y + (keyboardLayout[i][2] * (KEY_HEIGHT + 8 + KEY_LED_HEIGHT))

  degreeWidget.changed = function(self)
    setScaleDegree(i, self.value)
    scaleEditWidget.visible = true
  end

  degreeWidgets[i] = degreeWidget
end

for i = 1, 12 do
  local degreeLed = notePanel:Label("DegreeLed_"..i)
  degreeLed.interseptMouseClicks = false
  degreeLed.showLabel = false
  degreeLed.displayName = " "
  degreeLed.backgroundColour = "darkgray"
  degreeLed.width = KEY_LED_WIDTH
  degreeLed.height = KEY_LED_HEIGHT
  degreeLed.x = SCALE_X + (keyboardLayout[i][1] * (KEY_WIDTH / 2)) + ((i-1) * 1) + 3
  degreeLed.y = SCALE_Y + (keyboardLayout[i][2] * (KEY_HEIGHT + 8 + KEY_LED_HEIGHT)) + KEY_HEIGHT + 4

  ledWidgets[i] = degreeLed
end

populatePitchQuantizeMap()


local function setScale(scaleDegrees)
  for i = 1, 12 do
    scaleRaw[i] = false
  end
  for i = 1, #scaleDegrees do
    scaleRaw[ (scaleDegrees[i] % 12) + 1 ] = true -- disregard octaves
  end
  handleScaleChange()
end

local function setTonicNote(tonic)
  tonicNoteOffset = tonic
  handleScaleChange()
end

--------------------------------------------------------------------------------
-- Sequencer Panel
--------------------------------------------------------------------------------

local sequencerLabel = sequencerPanel:Label("Label")
sequencerLabel.text = "Turing Machine"
sequencerLabel.alpha = 0.5
sequencerLabel.backgroundColour = labelBackgoundColour
sequencerLabel.textColour = labelTextColour
sequencerLabel.fontSize = 22
sequencerLabel.width = 170
sequencerLabel.x = 0

local autoplayButton = sequencerPanel:OnOffButton("AutoPlay", false)
autoplayButton.backgroundColourOff = "#ff084486"
autoplayButton.backgroundColourOn = "#ff02ACFE"
autoplayButton.textColourOff = "#ff22FFFF"
autoplayButton.textColourOn = "#efFFFFFF"
autoplayButton.displayName = "Auto Play"
autoplayButton.tooltip = "Play automatically on transport"
autoplayButton.size = {80,22}
autoplayButton.x = 300
autoplayButton.y = 2

local playButton = sequencerPanel:OnOffButton("Play", false)
playButton.persistent = false
playButton.backgroundColourOff = "#ff084486"
playButton.backgroundColourOn = "#ff02ACFE"
playButton.textColourOff = "#ff22FFFF"
playButton.textColourOn = "#efFFFFFF"
playButton.displayName = "Play"
playButton.size = {80,22}
playButton.x = 410
playButton.y = 2
playButton.changed = function(self)
  if self.value == true then
    startPlaying()
  else
    stopPlaying()
  end
end

--------------------------------------------------------------------------------
-- Settings Panel
--------------------------------------------------------------------------------

local settingsLabel = settingsPanel:Label("SettingsLabel")
settingsLabel.text = "Shift Register"
settingsLabel.alpha = 0.75
settingsLabel.fontSize = 15
settingsLabel.width = 350
settingsLabel.x = 90
settingsLabel.y = 5
-- --- First row ---

local clockMenu = settingsPanel:Menu("Clock", tempoDivisionNames)
clockMenu.textColour = widgetTextColour
clockMenu.backgroundColour = widgetBackgroundColour
clockMenu.displayName = "Clock"
clockMenu.tooltip = "Note Production Rate"
clockMenu.width = 80
clockMenu.x = 5
clockMenu.y = 5 -- 85
clockMenu.changed = function(self)
  local numBeats = tempoDivisions[self.value][2]
  setClockRate(numBeats)
end
clockMenu:setValue(tableLookup(tempoDivisionNames, "1/8"), true)

local rateMultiplierWidget = settingsPanel:Knob("RateMultiplier", 1, 0.5, 2, false)
rateMultiplierWidget.displayName = "Mult"
rateMultiplierWidget.tooltip = "Clock Rate Multiplier"
rateMultiplierWidget.mapper = Mapper.Exponential
rateMultiplierWidget.outlineColour = "lightseagreen"
rateMultiplierWidget.x = 5
rateMultiplierWidget.y = 60
rateMultiplierWidget.height = 30
rateMultiplierWidget.changed = function(self)
  setClockRateMultiplier(1/self.value)
end

local invertProbabilityWidget = settingsPanel:NumBox("InvertProbability", 25, 0, 100, true)
invertProbabilityWidget.unit = Unit.Percent
invertProbabilityWidget.textColour = widgetTextColour
invertProbabilityWidget.backgroundColour = widgetBackgroundColour
invertProbabilityWidget.displayName = "Chaos"
invertProbabilityWidget.tooltip = "Probability of change per step" -- "Probability of recirculated value begin inverted"
invertProbabilityWidget.size = {163,20}
invertProbabilityWidget.x = clockMenu.x + clockMenu.width + 10
invertProbabilityWidget.y = 30
invertProbabilityWidget.changed = function(self)
  invertProbability = self.value * 0.01
end

local freezeButton = settingsPanel:OnOffButton("Freeze", false)
freezeButton.persistent = false
freezeButton.backgroundColourOff = "#ff084486"
freezeButton.backgroundColourOn = "#ff02ACFE"
freezeButton.textColourOff = "#ff22FFFF"
freezeButton.textColourOn = "#efFFFFFF"
freezeButton.displayName = "Freeze"
freezeButton.size = autoplayButton.size
freezeButton.x = invertProbabilityWidget.x + invertProbabilityWidget.width + 10
freezeButton.y = invertProbabilityWidget.y
freezeButton.changed = function(self)
  freeze = self.value
end

local function repaintShiftRegister()
  updateLeds()
  local value = getValue() -- this call is done twice .. can be optimized out by making 'value' a global
  valueLabel.text = tostring(value)
end

-- Second row 

local sequenceLengthWidget = settingsPanel:NumBox("SequenceLength", DEFAULT_SEQUENCE_LENGTH, 1, MAX_SEQUENCE_LENGTH, true)
sequenceLengthWidget.unit = Unit.Generic
sequenceLengthWidget.textColour = widgetTextColour
sequenceLengthWidget.backgroundColour = widgetBackgroundColour
sequenceLengthWidget.displayName = "Sequence Length"
sequenceLengthWidget.tooltip = "Nmber of bits in the shift register (1 .. "..MAX_SEQUENCE_LENGTH..")"
sequenceLengthWidget.size = {163,20}
sequenceLengthWidget.x = 95
sequenceLengthWidget.y = 60
sequenceLengthWidget.changed = function(self)
  setSequenceLength(self.value)

  valueLabel.x = ledPanel.x + ((LED_SIZE + LED_GAP) * valueLength) - valueLabel.width + 2
  sequenceLengthMarkerWidget.width = (LED_SIZE * valueLength) + (LED_GAP * (valueLength - 1))

  repaintShiftRegister()
end
sequenceLengthWidget:changed()

-- Third row

-- local noteRangeLabel = notePanel:Label("Pitch Range")
-- noteRangeLabel.height = 30
-- noteRangeLabel.x = 220
-- noteRangeLabel.y = 20
-- noteRangeLabel.outlineColour = colorKeyOn

local minKnob = notePanel:Knob("Min", DEFAULT_MIDI_NOTE_MIN, 0, 127, true)
minKnob.height = 35
minKnob.x = 190
minKnob.y = 55
minKnob.outlineColour = colorKeyOn

local maxKnob = notePanel:Knob("Max", DEFAULT_MIDI_NOTE_MAX, 0, 127, true)
maxKnob.height = 35
maxKnob.x = minKnob.x + 90
maxKnob.y = 55
maxKnob.outlineColour = colorKeyOn

minKnob.changed = function(self)
    self.displayText = formatNoteName(self.value)
    setMidiNoteRange(self.value, maxKnob.value)
end
maxKnob.changed = function(self)
    self.displayText = formatNoteName(self.value)
    setMidiNoteRange(minKnob.value, self.value)
end
minKnob:changed()
maxKnob:changed()

-- Velocity 

local velocityWidget = notePanel:Knob("Velocity", 100, 0, 127, true)
velocityWidget.displayName = "Velocity"
velocityWidget.tooltip = "MIDI Note velocity (nominal)"
velocityWidget.outlineColour = "green"
velocityWidget.x = 370
velocityWidget.y = 5
velocityWidget.changed = function(self)
  setNominalVelocity(self.value)
end
velocityWidget:changed()

local velocityChaosWidget = notePanel:Knob("VelocityChaos", 0, 0, 1, false)
velocityChaosWidget.Unit = Unit.Percent
velocityChaosWidget.displayName = "Vel Chaos"
velocityChaosWidget.tooltip = "MIDI Note velocity chaos %"
velocityChaosWidget.outlineColour = "green"
velocityChaosWidget.height = 40
velocityChaosWidget.x = velocityWidget.x + 25
velocityChaosWidget.y = velocityWidget.y + 50
velocityChaosWidget.changed = function(self)
  setVelocityChaos(self.value)
  velocityChaosWidget.displayText = formatPercent(self.value * 100)
end
velocityChaosWidget:changed()

-- Gate Length Percent

local gateLengthKnob = notePanel:Knob("GateLength", 100, 0, 400, false)
gateLengthKnob.mapper = Mapper.Quadratic
gateLengthKnob.displayName = "Gate Length"
gateLengthKnob.tooltip = "Gate Length (percent of clock rate)"
gateLengthKnob.outlineColour = "dodgerblue" -- "orange"
gateLengthKnob.x = 490
gateLengthKnob.y = 5
gateLengthKnob.changed = function(self)
  setGateLengthPercent(self.value * 0.01)
  gateLengthKnob.displayText = formatPercent(self.value)
end
gateLengthKnob:changed()

local skipChanceWidget = notePanel:Knob("SkipChance", 0, 0, 1, false)
skipChanceWidget.displayName = "Skip"
skipChanceWidget.tooltip = "Random skip note output"
skipChanceWidget.outlineColour = "red"
skipChanceWidget.x = 615
skipChanceWidget.y = 5
skipChanceWidget.changed = function(self)
  skipProbability = self.value
  skipChanceWidget.displayText = formatPercent(self.value * 100)
end
skipChanceWidget:changed()

local channelWidget = notePanel:Knob("Channel", 1, 1, 16, true)
channelWidget.Unit = Unit.Generic
channelWidget.displayName = "Channel"
channelWidget.tooltip = "MIDI Channel"
channelWidget.outlineColour = "blueviolet"
channelWidget.height = 40
channelWidget.x = 550
channelWidget.y = velocityChaosWidget.y
channelWidget.changed = function(self)
    midiChannel = self.value
end
channelWidget:changed()

local zeroesButton = settingsPanel:Button("ZeroesButton")
zeroesButton.triggeredOnMouseDown = true
zeroesButton.displayName = "Zeroes"
zeroesButton.tooltip = "Force 0s into the shift register"
zeroesButton.backgroundColourOff = "darkgreen" -- "#ff084486"
zeroesButton.backgroundColourOn = "lightgreen" -- "#ff02ACFE"
zeroesButton.textColourOff = "#ff22FFFF"
zeroesButton.textColourOn = "#efFFFFFF"
zeroesButton.width = 80
zeroesButton.x = 425
zeroesButton.y = freezeButton.y
zeroesButton.changed = function(self)
  forceZeroes = self.triggeredOnMouseDown
  -- print("Force Zeroes", forceZeroes, self.value)
  if self.triggeredOnMouseDown and not isPlaying then
    if not isPlaying then
      insertBit(0)
    end
    repaintShiftRegister()
  end
  self.triggeredOnMouseDown = not self.triggeredOnMouseDown
end

local onesButton = settingsPanel:Button("OnesButton")
onesButton.triggeredOnMouseDown = true
onesButton.displayName = "Ones"
onesButton.backgroundColourOff = "darkgreen" -- "#ff084486"
onesButton.backgroundColourOn = "lightgreen" -- "#ff02ACFE"
onesButton.textColourOff = "#ff22FFFF"
onesButton.textColourOn = "#efFFFFFF"
onesButton.tooltip = "Force 1s into the shift register"
onesButton.width = 80
onesButton.x = zeroesButton.x + zeroesButton.width + 10
onesButton.y = freezeButton.y
onesButton.changed = function(self)
  forceOnes = self.triggeredOnMouseDown
  -- print("Force Ones", forcetriggeredOnMouseDown
  if self.triggeredOnMouseDown and not isPlaying then
    insertBit(1)
    repaintShiftRegister()
  end
  self.triggeredOnMouseDown = not self.triggeredOnMouseDown
end

local randomFillButton = settingsPanel:Button("RandomFill")
randomFillButton.triggeredOnMouseDown = true
randomFillButton.persistent = false  -- TODO: is this needed ?
randomFillButton.displayName = "Rand Fill"
randomFillButton.tooltip = "Fill shift register with random values"
-- TODO: setButtonColors(randomFillButton)
randomFillButton.backgroundColourOff = "darkgreen" -- "#ff084486"
randomFillButton.backgroundColourOn = "lightgreen" -- "#ff02ACFE"
randomFillButton.textColourOff = "#ff22FFFF"
randomFillButton.textColourOn = "#efFFFFFF"
randomFillButton.width = 80
randomFillButton.x = onesButton.x + onesButton.width + 10
randomFillButton.y = freezeButton.y
randomFillButton.changed = function(self)
  fillShiftRegisterRandom()
  repaintShiftRegister()
end

local restoreButton = settingsPanel:Button("Restore")
restoreButton.triggeredOnMouseDown = true
restoreButton.persistent = false 
restoreButton.displayName = "Restore"
restoreButton.tooltip = "Restore shift register to captured value"
-- TODO: setButtonColors(resetButton)
restoreButton.backgroundColourOff = "rebeccapurple" -- "#ff084486"
restoreButton.backgroundColourOn = "purple" -- "#ff02ACFE"
restoreButton.textColourOff = "#ff22FFFF"
restoreButton.textColourOn = "#efFFFFFF"
restoreButton.width = 60
restoreButton.x = onesButton.x + 20
restoreButton.y = 5
restoreButton.changed = function(self)
  copySeedToShiftRegister()
  repaintShiftRegister()
end

local captureButton = settingsPanel:Button("Capture")
captureButton.triggeredOnMouseDown = true
captureButton.persistent = false 
captureButton.displayName = "Capture"
captureButton.tooltip = "Capture shift register values"
-- TODO: setButtonColors(grabButton)
captureButton.backgroundColourOff = "rebeccapurple" -- "#ff084486"
captureButton.backgroundColourOn = "purple" -- "#ff02ACFE"
captureButton.textColourOff = "#ff22FFFF"
captureButton.textColourOn = "#efFFFFFF"
captureButton.width = 60
captureButton.x = randomFillButton.x
captureButton.y = 5
captureButton.changed = function(self)
  copyShiftRegisterToSeed()
end


local scaleMenu = notePanel:Menu("Scale", scaleNames)
scaleMenu.width = 130
scaleMenu.textColour = "lightblue"
scaleMenu.backgroundColour = "black"
-- scaleMenu.textColour = colorKeyOn
scaleMenu.displayName = "Scale"
scaleMenu.tooltip = "Note Scale"
scaleMenu.showLabel = false
scaleMenu.height = 20
scaleMenu.value = 2 -- Major
scaleMenu.x = 35
scaleMenu.y = 5
scaleMenu.changed = function(self)
  setScale(scales[self.value][2])
  scaleEditWidget.visible = false
end
scaleMenu:changed()

local tonicNoteWidget = notePanel:NumBox("TonicNote", 1, 1, 12, true)
tonicNoteWidget.unit = Unit.Generic
tonicNoteWidget.textColour = "lightblue"
tonicNoteWidget.backgroundColour = widgetBackgroundColour
tonicNoteWidget.displayName = "Tonic Note"
tonicNoteWidget.tooltip = "Tonic Note"
tonicNoteWidget.showLabel = false
tonicNoteWidget.displayText = pitchNames[1] -- C 
tonicNoteWidget.size = {25,20}
tonicNoteWidget.x = 5 -- scaleMenu.x
tonicNoteWidget.y = 5 -- scaleMenu.y + scaleMenu.height + 10
tonicNoteWidget.changed = function(self)
    self.displayText = pitchNames[self.value]
    setTonicNote(self.value - 1)
end

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

function startPlaying()
  if isPlaying then
    return
  end
  run(sequenceRunner)
end

function stopPlaying()
  if not isPlaying then
    return
  end
  isPlaying = false
end

--------------------------------------------------------------------------------
-- Sequencer
--------------------------------------------------------------------------------

function sequenceRunner()
  isPlaying = false
  spawn(play)
end

function play()
  -- TODO: if clock > 1 bar, then start at next bar .. i.e. limit the wait time to beginning of next bar for first sync up 
  local nextBeatTime = round((getRunningBeatTime() + clockRateBeats) / clockRateBeats) * clockRateBeats
  if isTransportRunning then
    waitBeat(nextBeatTime - getRunningBeatTime())
  end

  isPlaying = true
  while isPlaying
  do
    -- round to nearest fraction of beatTime based on selected clock rate 
    nextBeatTime = round((getRunningBeatTime() + clockRateBeats) / clockRateBeats) * clockRateBeats
    updateShiftRegister()
    sendMidiNote()
    repaintShiftRegister()
    waitBeat(nextBeatTime - getRunningBeatTime())
  end
end

--------------------------------------------------------------------------------
-- Handle events
--------------------------------------------------------------------------------

function onTransport(isRunning)
  isTransportRunning = isRunning
  if autoplayButton.value == true then
    playButton:setValue(isRunning)
  end
end


-- TODO: consider adding a "play while keys held" option 
-- local numKeysHeld = 0

-- function onNote(e)
--   if autoplayButton.value == true then
--     postEvent(e)
--   else
--     playButton:setValue(true)
--     numKeysHeld = numKeysHeld + 1
--   end
-- end

-- function onRelease(e)
--   if autoplayButton.value == true then
--     postEvent(e)
--   else
--     numKeysHeld = numKeysHeld - 1
--     if numKeysHeld <= 0 then
--       playButton:setValue(false)
--       numKeysHeld = 0
--     end
--   end
-- end

-- local triggerWidget = MultiStateButton("Trigger", { "Key Held", "Transport", "Manual"})
-- triggerWidget.width = 80


--------------------------------------------------------------------------------
-- Save / Load
--------------------------------------------------------------------------------

function onSave()
  local seed = {}
  for _,v in ipairs(shiftRegisterSeed) do
    table.insert(seed, v)
  end
  return {seed}
end

function onLoad(data)
  local seed = data[1]
  for i,v in ipairs(seed) do
    shiftRegisterSeed[i] = v
  end
end
