local H = wesnoth.require'lua/helper.lua'
local T = wml.tag
local W = wesnoth.wml_actions
local V = wml.variables

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

local function child_range(cfg, name)
	return forToIter(H.child_range(cfg, name))
end

local function ipairs_iter(t)
	return forToIter(ipairs(t))
end

local function set_random_recruit(side)
	local units = H.get_variable_array('random_units_type')
	W.set_recruit{
		side = side,
		recruit = units[wesnoth.random(#units)].id,
	}
end

function W.random_units_init(cfg)
	forEach(
		function(type)
			W.set_variables{
				name = 'random_units_type',
				mode = 'append',
				T.value{id = type.id},
			}
		end,
		child_range(H.get_child(cfg, 'units'), 'unit_type'))
	forEach(
		function(side) set_random_recruit(side) end,
		ipairs_iter(wesnoth.sides))
end

-- vim: noexpandtab shiftwidth=0
