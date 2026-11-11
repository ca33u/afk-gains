--[[
  AFK Gains steps: a pedometer for your hero.

  Counts the steps your hero takes on foot (walking, running, swimming);
  flights and mounts do not count. A walking step is about 0.76 m, a
  running stride about 1.65 m (a yard is 0.91 m), so 1.2 steps per yard
  when walking and 0.55 when running. Every time the hero starts to move
  counts as at least one step, so a single tap of a key is a step too.
  Today's steps and the total are in the rings' tooltip; every 10 000
  steps your hero asks how you are doing.
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local ST = {}
ns.Steps = ST

ST.WALK_PER_YARD = 0.9144 / 0.762 -- walking step 0.76 m
ST.RUN_PER_YARD = 0.9144 / 1.65   -- running stride 1.65 m
ST.RUN_SPEED = 4.5                -- yards per second: faster than this is running

-- Steps for `yards` covered at `speed` yards per second.
function ST.StepsFor(yards, speed)
	return yards * ((speed or 0) > ST.RUN_SPEED and ST.RUN_PER_YARD or ST.WALK_PER_YARD)
end
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

-- Adds `steps`; returns the milestone reached, if any.
function ST.Add(steps)
	if not steps or steps <= 0 then
		return nil
	end
	local s = ST.DB()
	local before = math.floor(s.today)
	s.today = s.today + steps
	s.total = (s.total or 0) + steps
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

local function Milestone(m)
	if m then
		local text = string.format(T("Your hero has walked %s steps today. And you?"), ST.Format(m))
		print("|cffff9a3cAFK Gains|r " .. text)
		if RaidNotice_AddMessage and RaidWarningFrame then
			pcall(RaidNotice_AddMessage, RaidWarningFrame, text, { r = 1, g = 0.6, b = 0.24 })
		end
	end
end

-- One stretch of movement: counted as it goes, at least one step in all.
ST.move = nil

function ST.Tick(dt)
	local speed = Safe(GetUnitSpeed, "player")
	if type(speed) ~= "number" or speed <= 0 or not ST.OnFoot() then
		return
	end
	local n = ST.StepsFor(speed * dt, speed)
	if ST.move then
		ST.move.steps = ST.move.steps + n
	end
	Milestone(ST.Add(n))
end

function ST.Started()
	ST.move = { steps = 0 }
end

function ST.Stopped()
	local mv = ST.move
	ST.move = nil
	if mv and mv.steps < 1 and ST.OnFoot() then
		Milestone(ST.Add(1 - mv.steps)) -- a single tap is one step
	end
end

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	acc = acc + (elapsed or 0)
	if acc < 0.1 then
		return
	end
	local dt = acc
	acc = 0
	ST.Tick(dt)
end)
driver:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_STARTED_MOVING" then
		ST.Started()
	else
		ST.Stopped()
	end
end)
pcall(driver.RegisterEvent, driver, "PLAYER_STARTED_MOVING")
pcall(driver.RegisterEvent, driver, "PLAYER_STOPPED_MOVING")
