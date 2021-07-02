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

-- Return an array with only the elements from a where f returns true.
local function filter(f, a)
  local new = {}
  for _, v in ipairs(a) do
    if f(v) then
      table.insert(new, v)
    end
  end
  return new
end

local function map(f, a)
  local new = {}
  for i, v in ipairs(a) do
    new[i] = f(v)
  end
  return new
end

local function fold(f, a, init)
  local function h(init, i)
    local v = a[i]
    if v == nil then
      return init
    end
    return h(f(init, v), i + 1)
  end
  return h(init, 1)
end

local function sum(iter)
  return fold(function(a, b) return a + b end, iter, 0)
end

-- Return a function that takes a table and returns the value that key points
-- to.
local function getter(key)
  return function(t)
    return t[key]
  end
end

-- Return a function that passes its arguments to f and negates the result.
local function negate(f)
  return function(...)
    return not f(...)
  end
end

local function findChoice(totalWeight, pool, f, i)
  local unitType = pool[i]
  local weight = f(unitType)
  if totalWeight <= weight then
    return unitType, i
  end
  return findChoice(totalWeight - weight, pool, f, i + 1)
end

-- A level-based probability weight.
local function levelWeight(level)
  return 6 - level
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

-- The list of all unit types that we choose from. We must call
-- [randomUnits_loadUnitTypes] during the preload event to initialize it.
local allTypes = {}

local function chooseBiased(pool, f)
  return findChoice(wesnoth.random(sum(map(f, pool))), pool, f, 1)
end

local function chooseFair(pool)
  local i = wesnoth.random(#pool)
  return pool[i], i
end

-- Set a single recruit for side. unitType is a table with an id field. i is the
-- index to remove from the main pool.
local function setRecruit(side, unitType, allowRepeats, i)
  side.recruit = {unitType.id}
  if not allowRepeats then
    wesnoth.set_variable(('randomUnits_pool[%d]'):format(i - 1))
  end
end

-- Choose a random unit type to be the given side's recruit. The argument is a
-- side.
local function setRandomRecruit(side, options)
  if not (options.allowRepeats or V.randomUnits_pool) then
    H.set_variable_array('randomUnits_pool', allTypes)
  end
  local pool =
    options.allowRepeats and allTypes or H.get_variable_array'randomUnits_pool'
  local choose = options.rarity and chooseBiased or chooseFair
  if options.byLevel then
    local weightTable = {}
    for i, unitType in ipairs(pool) do
      local weight = unitType.weight
      local thisWeight = weightTable[weight] or {}
      table.insert(thisWeight, {i = i, id = unitType.id})
      weightTable[weight] = thisWeight
    end
    local unit = chooseFair(weightTable[choose(keys(weightTable), identity)])
    setRecruit(side, unit, options.allowRepeats, unit.i)
  else
    local unit, i = choose(pool, getter'weight')
    setRecruit(side, unit, options.allowRepeats, i)
  end
end

local options = {
  allowRepeats = V.randomUnits_allowRepeats,
  rarity = V.randomUnits_rarity,
  byLevel = V.randomUnits_byLevel,
}

-- This tag must contain a [units] tag. Store all unit types from [units] in the
-- Lua state for use when randomly choosing units.
function W.randomUnits_loadUnitTypes(cfg)
  for unitType in H.child_range(H.get_child(cfg, 'units'), 'unit_type') do
    if not unitType.do_not_list then
      local id = unitType.id
      table.insert(
	allTypes,
	{
	  id = id,
	  weight = levelWeight(wesnoth.unit_types[id].level),
	})
    end
  end
end

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
