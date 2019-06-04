local H = wesnoth.require'lua/helper.lua'
local V = wml.variables
local W = wesnoth.wml_actions
local onEvent = wesnoth.require'lua/on_event'

-- The list of all unit types that we choose from.
local allTypes = {}

-- Choose a random unit type to be the given side's recruit.
local function setRandomRecruit(side)
  if V.randomUnits_allowRepeats then
    side.recruit = {allTypes[wesnoth.random(#allTypes)]}
  else
    local pool = H.get_variable_array('randomUnits_pool')
    if not pool[1] then
      for i, id in ipairs(allTypes) do
	pool[i] = {id = id}
      end
      H.set_variable_array('randomUnits_pool', pool)
    end
    local i = wesnoth.random(#pool)
    side.recruit = {pool[i].id}
    wesnoth.set_variable(('randomUnits_pool[%d]'):format(i - 1))
  end
end

-- This tag must contain a [units] tag. Store all unit types from [units] in the
-- Lua state for use when randomly choosing units.
function W.randomUnits_loadUnitTypes(cfg)
  for unitType in H.child_range(H.get_child(cfg, 'units'), 'unit_type') do
    table.insert(allTypes, unitType.id)
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
