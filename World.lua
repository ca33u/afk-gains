--[[
  Campfire world: ties the reminders to what your hero really has.

    drink or food in your bags   "You have Ice Cold Milk: share a drink"
    Basic Campfire known         "Light a Basic Campfire and sit by it"
    resting at an inn or city    "Your hero is resting at the inn"
    hero eating / drinking now   the matching reminder comes a bit early
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local W = {}
ns.World = W

W.CAMPFIRE_SPELL = 818 -- Basic Campfire (Cooking)
W.AURA = {
	drink = { ["Drink"] = true, ["Питье"] = true, ["Питьё"] = true },
	food = { ["Food"] = true, ["Пища"] = true, ["Еда"] = true },
}

local function Safe(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b, c, d, e, f, g = pcall(fn, ...)
	if not ok or (issecretvalue and issecretvalue(a)) then
		return nil
	end
	return a, b, c, d, e, f, g
end

------------------------------------------------------------------------
-- Bags: the first drink or food you carry (by its use: Drink / Food)
------------------------------------------------------------------------

local function SlotItem(bag, slot)
	if C_Container and C_Container.GetContainerItemID then
		return Safe(C_Container.GetContainerItemID, bag, slot)
	end
	return Safe(GetContainerItemID, bag, slot)
end

local function NumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return Safe(C_Container.GetContainerNumSlots, bag) or 0
	end
	return Safe(GetContainerNumSlots, bag) or 0
end

-- kind: "drink" | "food". Returns the item name or nil.
function W.InBags(kind)
	for bag = 0, 4 do
		for slot = 1, NumSlots(bag) do
			local id = SlotItem(bag, slot)
			if id then
				local spell = Safe(GetItemSpell, id)
				if spell and W.AURA[kind][spell] then
					return Safe(GetItemInfo, id) or spell
				end
			end
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Spells and buffs
------------------------------------------------------------------------

function W.KnowsCampfire()
	return (Safe(IsPlayerSpell, W.CAMPFIRE_SPELL) or Safe(IsSpellKnown, W.CAMPFIRE_SPELL)) and true or false
end

function W.Resting()
	return Safe(IsResting) and true or false
end

-- Is the hero eating or drinking right now? kind: "drink" | "food"
function W.HasAura(kind)
	for i = 1, 40 do
		local name
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local data = Safe(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
			if not data then
				break
			end
			name = data.name
		else
			name = Safe(UnitBuff, "player", i)
			if not name then
				break
			end
		end
		if type(name) == "string" and not (issecretvalue and issecretvalue(name)) and W.AURA[kind][name] then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- The hint for a reminder: something about your hero if we can, else nil
------------------------------------------------------------------------

function W.Hint(key)
	if key == "water" then
		if W.HasAura("drink") then
			return T("Your hero is drinking. Grab a glass too.")
		end
		local item = W.InBags("drink")
		if item then
			return string.format(T("You have %s in your bags: share a drink with your hero."), item)
		end
	elseif key == "meal" then
		if W.HasAura("food") then
			return T("Your hero is eating. How about you?")
		end
		local item = W.InBags("food")
		if item then
			return string.format(T("You have %s in your bags: eat together with your hero."), item)
		end
		if W.KnowsCampfire() then
			return T("Light a Basic Campfire and sit your hero by it.")
		end
	elseif key == "stand" or key == "read" then
		if W.Resting() then
			return T("Your hero is resting at the inn: a good moment.")
		end
		if key == "stand" and W.KnowsCampfire() then
			return T("Light a Basic Campfire and sit your hero by it.")
		end
	end
	return nil
end

-- The hero starts eating or drinking: bring that reminder forward when it
-- is due soon anyway (water within 30 min, a meal in its window).
W.EARLY = 30

function W.Nudge(now)
	local key
	if W.HasAura("drink") then
		key = "water"
	elseif W.HasAura("food") then
		key = "meal"
	end
	if not key then
		return nil
	end
	local left = C.MinutesLeft(key, now)
	if left ~= nil and left <= W.EARLY and not C.Locked(key, now) and not C.DB().off[key] and not C.DB().paused then
		if key == "meal" and not C.MealWindow(now) then
			return nil
		end
		return key
	end
	return nil
end
