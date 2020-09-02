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
    wesnoth.random(sum(map(getter'weight', pool))),
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
  for unitType in H.child_range(H.get_child(cfg, 'units'), 'unit_type') do
    if not unitType.do_not_list then
      table.insert(allTypes, {id = unitType.id, weight = 6 - unitType.level})
    end
  end
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
