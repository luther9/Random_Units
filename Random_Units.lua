-- Cycle iter. First return value is the next iterator. Second return value is
-- an array containing the other values from iter.
local function iterate(iter)
  local values = {iter()}
  return table.remove(values, 1), values
end

-- Execute f for each set of values from iter.
local function forEach(f, iter)
  local iter_, values = iterate(iter)
  if iter_ then
    f(table.unpack(values))
    return forEach(f, iter_)
  end
end

-- Return an iterator with only the elements from iter where f returns true.
local function filter(f, iter)
  return function()
    local iter_, values = iterate(iter)
    if not iter_ then
      return
    end
    local nextIter = filter(f, iter_)
    if f(table.unpack(values)) then
      return nextIter, table.unpack(values)
    end
    return nextIter()
  end
end

-- Convert a for loop iterator to a functional iterator.
local function forToIter(f, state, var)
  return function()
    local values = {f(state, var)}
    local key = table.remove(values, 1)
    if key == nil then
      return
    end
    return forToIter(f, state, key), key, table.unpack(values)
  end
end

local H = wesnoth.require'lua/helper.lua'
local V = wml.variables
local W = wesnoth.wml_actions
local onEvent = wesnoth.require'lua/on_event'

-- The list of all unit types that we choose from.
local allTypes = {}

-- Choose a random unit type to be the given side's recruit. The argument is a
-- side number.
local function setRandomRecruit(side)
  if V.randomUnits_allowRepeats then
    side.recruit = {allTypes[wesnoth.random(#allTypes)].id}
  else
    if not wesnoth.get_variable'randomUnits_pool' then
      H.set_variable_array('randomUnits_pool', allTypes)
    end
    local pool = H.get_variable_array'randomUnits_pool'
    local i = wesnoth.random(#pool)
    side.recruit = {pool[i].id}
    wesnoth.set_variable(('randomUnits_pool[%d]'):format(i - 1))
  end
end

-- This tag must contain a [units] tag. Store all unit types from [units] in the
-- Lua state for use when randomly choosing units.
function W.randomUnits_loadUnitTypes(cfg)
  forEach(
    function(unitType)
      table.insert(allTypes, {id = unitType.id, weight = 6 - unitType.level})
    end,
    filter(
      function(unitType) return not unitType.do_not_list end,
      forToIter(H.child_range(H.get_child(cfg, 'units'), 'unit_type'))))
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
