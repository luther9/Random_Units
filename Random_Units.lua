local onEvent = wesnoth.require'lua/on_event'
local H = wesnoth.require'lua/helper.lua'
local W = wesnoth.wml_actions

local function forEach(f, iter)
  return (function(iter, ...)
    if iter then
      f(...)
      return forEach(f, iter)
    end
  end)(iter())
end

local function forToIter(iter, state, key)
  return function()
    return (function(key, ...)
      if not key then
	return
      end
      return forToIter(iter, state, key), key, ...
    end)(iter(state, key))
  end
end

local Array = {

  ipairs = function(self)
    return forToIter(ipairs(self))
  end,

}

local function childRange(cfg, name)
  return forToIter(H.child_range(cfg, name))
end

-- The list of all unit types that we choose from.
local allTypes = {}

local function setRandomRecruit(side)
  W.set_recruit{
    side = side,
    recruit = allTypes[wesnoth.random(#allTypes)]
  }
end

-- This tag must contain a [units] tag. Store all unit types from [units] in the
-- Lua state for use when randomly choosing units.
function W.randomUnits_loadUnitTypes(cfg)
  forEach(
    function(type)
      table.insert(allTypes, type.id)
    end,
    childRange(H.get_child(cfg, 'units'), 'unit_type'))
end

-- Initialize each side's recruit at the beginning of the scenario.
onEvent(
  'prestart',
  function()
    forEach(
      function(side) setRandomRecruit(side) end,
      Array.ipairs(wesnoth.sides))
  end)

-- Each time a side recruits, replace its recruitable unit.
onEvent('recruit', function() setRandomRecruit(wesnoth.current.side) end)
