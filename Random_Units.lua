-- Copyright 2019-2020 Luther Thompson

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License (GPL3) as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- You have the following additional permission: You may convey the program in
-- object code form under the terms of sections 4 and 5 of GPL3 without being
-- bound by section 6 of GPL3.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

-- PURE FUNCTIONS

-- This library is not documented, but hopefully, it will work. It's in the
-- Wesnoth source at data/lua/functional.lua.
local fp <const> = wesnoth.require'lua/functional'

local function sum(array)
  return fp.reduce(array, '+')
end

local function findChoice(totalWeight, pool, f, i)
  local unitType = pool[i]
  local weight = f(unitType)
  if totalWeight <= weight then
    return unitType, i
  end
  return findChoice(totalWeight - weight, pool, f, i + 1)
end

local function keys(t)
  local array = {}
  for k in pairs(t) do
    table.insert(array, k)
  end
  return array
end

local function identity(...)
  return ...
end

-- IMPURE FUNCTIONS

local H = wesnoth.require'lua/helper.lua'
local V = wml.variables
local W = wesnoth.wml_actions
local onEvent = wesnoth.require'lua/on_event'

local function chooseBiased(pool, f)
  return findChoice(wesnoth.random(sum(fp.map(pool, f))), pool, f, 1)
end

local function chooseFair(pool)
  local i = wesnoth.random(#pool)
  return pool[i], i
end

-- Set a single recruit for side. unitType is a table with an id field. i is the
-- index to remove from the main pool. If i is false, don't remove the unit
-- type.
local function setRecruit(side, unitType, i)
  side.recruit = {unitType.id}
  if i then
    wesnoth.set_variable(('randomUnits_pool[%d]'):format(i - 1))
  end
end

-- Get the probability weight of the given unit type.
local function unitWeight(unitType)
  return 6 - wesnoth.unit_types[unitType.id].level
end

-- Choose a random unit type to be the given side's recruit. The argument is a
-- side.
local function setRandomRecruit(side, options)
  if not (options.allowRepeats or V.randomUnits_pool) then
    H.set_variable_array('randomUnits_pool', options.allTypes)
  end
  local pool =
    options.allowRepeats and options.allTypes
    or H.get_variable_array'randomUnits_pool'
  local choose = options.rarity and chooseBiased or chooseFair
  local removeChoice <const> = not options.allowRepeats
  if options.byLevel then
    local weightTable = {}
    for i, unitType in ipairs(pool) do
      local weight = unitWeight(unitType)
      local thisWeight = weightTable[weight] or {}
      table.insert(thisWeight, {i = i, id = unitType.id})
      weightTable[weight] = thisWeight
    end
    local unit = chooseFair(weightTable[choose(keys(weightTable), identity)])
    setRecruit(side, unit, removeChoice and unit.i)
  else
    local unit, i = choose(pool, unitWeight)
    setRecruit(side, unit, removeChoice and i)
  end
end

-- The list of all unit types that we choose from.
local allTypes <const> = {}
-- The wiki says that wesnoth.unit_types is not MP-safe, but nobody can figure
-- out how, since each scenario only loads the unit types it needs.
for id, unitType in pairs(wesnoth.unit_types) do
  if not unitType.__cfg.do_not_list then
    table.insert(allTypes, {id = id})
  end
end
table.sort(allTypes, function(a, b) return a.id < b.id end)

local options <const> = {
  allowRepeats = V.randomUnits_allowRepeats,
  rarity = V.randomUnits_rarity,
  byLevel = V.randomUnits_byLevel,
  allTypes = allTypes,
}

-- Initialize each side's recruit at the beginning of the scenario.
onEvent(
  'prestart',
  function()
    for _, side in ipairs(wesnoth.sides) do
      if side.recruit[1] then
	setRandomRecruit(side, options)
      end
    end
  end)

-- Each time a side recruits, replace its recruitable unit.
onEvent(
  'recruit',
  function() setRandomRecruit(wesnoth.sides[wesnoth.current.side], options) end)
