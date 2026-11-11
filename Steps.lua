--[[
  AFK Gains steps: a pedometer for your hero.

  Counts the steps your hero takes on foot (walking, running, swimming);
  flights and mounts do not count. A step is about 0.76 m and a yard
  0.91 m, so 1.2 steps per yard. Today's steps and the total are in the
  rings' tooltip; every 10 000 steps your hero asks how you are doing.
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local ST = {}
ns.Steps = ST

ST.PER_YARD = 0.9144 / 0.762
ST.MILESTONE = 10000

local function Safe(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a = pcall(fn, ...)
	if not ok or (issecretvalue and issecretvalue(a)) then
		return nil
	end
	return a
end

function ST.DB()
	local db = C.DB()
	db.steps = type(db.steps) == "table" and db.steps or { today = 0, total = 0 }
	local s = db.steps
	local day = C.clock.day(C.clock.now())
	if s.day ~= day then
		s.day, s.today = day, 0
	end
	return s
end

-- Is the hero on foot? (not on a flight, not mounted)
function ST.OnFoot()
	if Safe(UnitOnTaxi, "player") then
		return false
	end
	if Safe(IsMounted) then
		return false
	end
	return true
end

-- Adds `yards` walked; returns the milestone reached, if any.
function ST.Add(yards)
	if not yards or yards <= 0 then
		return nil
	end
	local s = ST.DB()
	local before = math.floor(s.today)
	s.today = s.today + yards * ST.PER_YARD
	s.total = (s.total or 0) + yards * ST.PER_YARD
	local m = math.floor(s.today / ST.MILESTONE)
	if m > math.floor(before / ST.MILESTONE) then
		return m * ST.MILESTONE
	end
	return nil
end

-- "12 345"
function ST.Format(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	acc = acc + (elapsed or 0)
	if acc < 0.25 then
		return
	end
	local dt = acc
	acc = 0
	local speed = Safe(GetUnitSpeed, "player")
	if type(speed) ~= "number" or speed <= 0 or not ST.OnFoot() then
		return
	end
	local m = ST.Add(speed * dt)
	if m then
		local text = string.format(T("Your hero has walked %s steps today. And you?"), ST.Format(m))
		print("|cffff9a3cAFK Gains|r " .. text)
		if RaidNotice_AddMessage and RaidWarningFrame then
			pcall(RaidNotice_AddMessage, RaidWarningFrame, text, { r = 1, g = 0.6, b = 0.24 })
		end
	end
end)
