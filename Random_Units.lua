local H = wesnoth.require'lua/helper.lua'
local W = wesnoth.wml_actions
local onEvent = wesnoth.require'lua/on_event'

-- The list of all unit types that we choose from.
local allTypes = {}

-- Choose a random unit type to be the given side's recruit.
local function setRandomRecruit(side)
  side.recruit = {allTypes[wesnoth.random(#allTypes)]}
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
