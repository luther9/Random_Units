local onEvent = wesnoth.require'lua/on_event'
local H = wesnoth.require'lua/helper.lua'
local T = wml.tag
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

local function childRange(cfg, name)
  return forToIter(H.child_range(cfg, name))
end

local function ipairsIter(t)
  return forToIter(ipairs(t))
end

local function setRandomRecruit(side)
  local units = H.get_variable_array('random_units_type')
  W.set_recruit{
    side = side,
    recruit = units[wesnoth.random(#units)].id,
  }
end

function W.randomUnits_init(cfg)
  forEach(
  function(type)
    W.set_variables{
      name = 'random_units_type',
      mode = 'append',
      T.value{id = type.id},
    }
  end,
  childRange(H.get_child(cfg, 'units'), 'unit_type'))
  forEach(
    function(side) setRandomRecruit(side) end,
    ipairsIter(wesnoth.sides))
end

onEvent('recruit', function() setRandomRecruit(wesnoth.current.side) end)
