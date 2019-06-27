-- Execute f for each item in iter.
local function forEach(f, iter)
  local iter_, item = iter()
  if iter_ then
    f(item)
    return forEach(f, iter_)
  end
end

-- Return an iterator with only the elements from iter where f returns true.
local function filter(f, iter)
  return function()
    local iter_, item = iter()
    if not iter_ then
      return
    end
    local nextIter = filter(f, iter_)
    if f(item) then
      return nextIter, item
    end
    return nextIter()
  end
end

local function map(f, iter)
  return function()
    local iter_, item = iter()
    if not iter_ then
      return
    end
    return map(f, iter_), f(item)
  end
end

local function fold(f, iter, init)
  local iter_, item = iter()
  if not iter_ then
    return init
  end
  return fold(f, iter_, f(init, item))
end

local function sum(iter)
  return fold(function(a, b) return a + b end, iter, 0)
end

local function _ipairsIter(t, i)
  return function()
    local item = t[i]
    if item == nil then
      return
    end
    return _ipairsIter(t, i + 1), {i, item}
  end
end

-- Return an iterator that yields {index, value} pairs from array t.
local function ipairsIter(t)
  return _ipairsIter(t, 1)
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

local function arrayValues(t)
  return map(getter(2), ipairsIter(t))
end

-- Convert a for loop iterator to a functional iterator. Only yield the first
-- value from each iteration.
local function forToIter1(f, state, var)
  return function()
    local item = f(state, var)
    if item == nil then
      return
    end
    return forToIter1(f, state, item), item
  end
end

local H = wesnoth.require'lua/helper.lua'
local V = wml.variables
local W = wesnoth.wml_actions
local onEvent = wesnoth.require'lua/on_event'

-- The list of all unit types that we choose from. We must call
-- [randomUnits_loadUnitTypes] during the preload event to initialize it.
local allTypes = {}

local function findChoice(totalWeight, pool, i)
  local unitType = pool[i]
  local weight = unitType.weight
  if totalWeight <= weight then
    return unitType, i
  end
  return findChoice(totalWeight - weight, pool, i + 1)
end

local function randomTypeWeighted(pool)
  return findChoice(
    wesnoth.random(sum(map(getter('weight'), arrayValues(pool)))),
    pool,
    1)
end

local function randomTypeFair(pool)
  local i = wesnoth.random(#pool)
  return pool[i], i
end

local randomType = V.randomUnits_rarity and randomTypeWeighted or randomTypeFair

-- Choose a unit type from allTypes.
local function getRandomRecruitWithRepeats()
  return randomType(allTypes)
end

local function getRandomRecruitNoRepeats()
  if not V.randomUnits_pool then
    H.set_variable_array('randomUnits_pool', allTypes)
  end
  local unitType, i = randomType(H.get_variable_array'randomUnits_pool')
  wesnoth.set_variable(('randomUnits_pool[%d]'):format(i - 1))
  return unitType
end

local getRandomRecruit =
  V.randomUnits_allowRepeats and getRandomRecruitWithRepeats
  or getRandomRecruitNoRepeats

-- Choose a random unit type to be the given side's recruit. The argument is a
-- side number.
local function setRandomRecruit(side)
  side.recruit = {getRandomRecruit().id}
end

-- This tag must contain a [units] tag. Store all unit types from [units] in the
-- Lua state for use when randomly choosing units.
function W.randomUnits_loadUnitTypes(cfg)
  forEach(
    function(unitType)
      table.insert(allTypes, {id = unitType.id, weight = 6 - unitType.level})
    end,
    filter(
      negate(getter('do_not_list')),
      forToIter1(H.child_range(H.get_child(cfg, 'units'), 'unit_type'))))
end

-- Initialize each side's recruit at the beginning of the scenario.
onEvent(
  'prestart',
  function()
    for _, side in ipairs(wesnoth.sides) do
      setRandomRecruit(side)
    end
  end)

-- Each time a side recruits, replace its recruitable unit.
onEvent(
  'recruit',
  function() setRandomRecruit(wesnoth.sides[wesnoth.current.side]) end)
