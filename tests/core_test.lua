-- AFK Gains logic outside the game: lua tests/core_test.lua
dofile("tests/stubs.lua")
LoadFile("Locale.lua")
LoadFile("Core.lua")
local C = NS.Core
local NOW, HOUR = 1000000, 10
local DAY = 0
C.clock = {
	now = function() return NOW end,
	day = function() return "d" .. DAY end,
	hour = function() return HOUR end,
}
local function Has(list, k) for _, v in ipairs(list) do if v == k then return true end end return false end

C.Start(NOW)
Check(#C.Due(NOW) == 1 and C.Due(NOW)[1] == "meal", "login at 10:00: only breakfast, timers start fresh")
HOUR = 12
Check(#C.Due(NOW) == 0, "12:00: nothing due")
NOW = NOW + 45 * 60
Check(Has(C.Due(NOW), "stand"), "45 min: stand up")
Check(not Has(C.Due(NOW), "pushups"), "bonus quests are never reminded")
C.Snooze("stand", NOW)
Check(not Has(C.Due(NOW), "stand") and C.MinutesLeft("stand", NOW) == 10, "later: back in 10 min")
NOW = NOW + 10 * 60
local closed = C.Complete("stand", NOW)
Check(closed and #closed == 0 and C.Locked("stand", NOW), "done: the tick is locked")
Check(C.Complete("stand", NOW) == nil, "clicking again does nothing")
Check(C.MinutesLeft("stand", NOW + 5 * 60) == 40, "locked until the timer runs out")
Check(not C.Locked("stand", NOW + 45 * 60) and Has(C.Due(NOW + 45 * 60), "stand"), "after 45 min it comes round again")
-- bonus
local xp = C.DB().xp
C.Complete("pushups", NOW)
Check(C.DB().xp - xp == 12 and C.Locked("pushups", NOW) and not C.Locked("squats", NOW), "push-ups: extra experience, squats still open")
Check(not C.Locked("pushups", NOW + 61 * 60), "bonus opens again after an hour")
NOW = NOW + 90 * 60
-- meals
HOUR = 13
Check(Has(C.Due(NOW), "meal"), "lunch window")
C.Complete("meal", NOW)
Check(C.Locked("meal", NOW) and not Has(C.Due(NOW), "meal"), "lunch eaten: locked")
HOUR = 18
NOW = NOW + 4 * 3600
Check(Has(C.Due(NOW), "meal") and not C.Locked("meal", NOW), "dinner is a new window")
HOUR = 16
-- natural pauses
local soon = C.Soon(NOW, 15)
Check(not Has(soon, "pushups"), "pauses never offer bonus quests")
C.DB().last.water = NOW - 80 * 60
Check(Has(C.Soon(NOW, 15), "water"), "a flight 10 min before water: offered early")
-- reading once a day
Check(Has(C.Due(NOW), "read"), "an hour into the session: read today")
C.Complete("read", NOW)
Check(C.Locked("read", NOW) and C.MinutesLeft("read", NOW) == nil and not Has(C.Due(NOW + 6 * 3600), "read"), "reading once a day")
-- rings and streak
for _, k in ipairs({ "stand", "squats", "water" }) do C.DB().doneAt[k] = nil end
C.Complete("stand", NOW); C.Complete("squats", NOW)
C.DB().doneAt.stand = nil; C.Complete("stand", NOW)
C.DB().doneAt.water = nil; C.Complete("water", NOW)
local _, have, goal = C.Progress("move")
Check(goal == 5 and have >= 5 and C.DB().closed.move, "move ring closes at 5")
Check(not C.DB().closed.mind, "mind ring: reading alone is 2 of 3")
C.Complete("breathe", NOW)
Check(C.DB().closed.mind and C.Locked("breathe", NOW), "a minute of breathing closes it")
Check(not Has(C.Due(NOW), "breathe5"), "the 4-minute bonus is never reminded")
C.DB().points.fuel = 5; C.DB().closed.fuel = true
Check(C.AllClosed(), "all three closed")
DAY = 1; C.Roll(NOW)
Check(C.DB().streak == 1, "streak 1")
DAY = 2; C.Roll(NOW)
Check(C.DB().streak == 1 and C.DB().grace, "one missed day is forgiven")
DAY = 3; C.Roll(NOW)
Check(C.DB().streak == 0, "two missed days in a row reset it")
Check(C.Goal("move") == 5, "goal unchanged after 2 misses")
DAY = 4; C.Roll(NOW)
Check(C.Goal("move") == 4, "a ring missed 3 days running gets a smaller goal")
Check(C.Goal("mind") == 2, "never below the minimum")
Check(C.Title(1) == "Apprentice" and C.Title(80) == "Journeyman" and C.Title(300) == "Artisan", "rank titles")

-- hints from the hero's bags, spells and buffs
LoadFile("World.lua")
local W = NS.World
local BAG = { [0] = { 159 } }
C_Container = {
	GetContainerNumSlots = function(bag) return BAG[bag] and #BAG[bag] or 0 end,
	GetContainerItemID = function(bag, slot) return BAG[bag] and BAG[bag][slot] end,
}
function GetItemSpell(id) return id == 159 and "Drink" or nil end
function GetItemInfo(id) return id == 159 and "Refreshing Spring Water" or nil end
local BUFFS = {}
function UnitBuff(_, i) return BUFFS[i] end
function IsResting() return false end
function IsPlayerSpell(id) return id == 818 end
Check(W.InBags("drink") == "Refreshing Spring Water" and W.InBags("food") == nil, "drink found in bags by its use")
Check(W.Hint("water"):find("Refreshing Spring Water", 1, true), "water hint names your drink")
Check(W.Hint("meal"):find("Basic Campfire", 1, true), "no food: light a campfire")
BUFFS[1] = "Drink"
Check(W.HasAura("drink") and W.Hint("water"):find("drinking", 1, true), "hero drinking: drink too")
C.DB().doneAt.water = nil
C.DB().last.water = NOW - 70 * 60
Check(W.Nudge(NOW) == "water", "hero drinks 20 min before the reminder: it comes early")
C.Complete("water", NOW)
Check(W.Nudge(NOW) == nil, "just drank: no nudge")
function IsResting() return true end
Check(W.Hint("stand"):find("inn", 1, true), "resting at an inn")

-- UI loads and runs
LoadFile("UI.lua")
GameTooltip.AddDoubleLine = function() end
Check(pcall(function()
	NS.UI.ShowToast("water")
	NS.UI.OfferBonus()
	NS.UI.Complete("water")
	NS.UI.ToggleList()
	NS.UI.Pause()
	SlashCmdList.AFKGAINS("every water 45")
	SlashCmdList.AFKGAINS("off read")
	SlashCmdList.AFKGAINS("pause")
	SlashCmdList.AFKGAINS("help")
end), "toast, bonus offer, list and commands run")
Check(C.DB().every.water == 45 and C.DB().paused, "commands change settings")
Check(pcall(NS.UI.BuildRings) and pcall(NS.UI.RefreshRings), "solid rings and level build and refresh")
local b0, p0 = NS.UI.BreathAt(0)
local b4 = NS.UI.BreathAt(4)
local b7, p7 = NS.UI.BreathAt(7)
local b10 = NS.UI.BreathAt(10)
Check(b0 < 0.01 and p0 == "in" and b4 > 0.99 and p7 == "out" and b7 > 0 and b7 < 1 and b10 < 0.01, "breathing ring: 4 s in, 6 s out")
Check(pcall(NS.UI.ShowToast, "breathe") and pcall(NS.UI.Guide, "breathe"), "breathing guide starts")
Check(NS.UI.Clock(75) == "1:15" and NS.UI.Clock(0) == "0:00" and NS.UI.Clock(-3) == "0:00", "countdown clock text")
Check(C.byKey.stand.sit == 60 and C.byKey.meal.sit == 900, "sit times: a minute up, a quarter hour to eat")
local doneCalled = false
Check(pcall(NS.UI.ShowToast, "water") and pcall(NS.UI.Countdown, "water", function() doneCalled = true end), "sit: countdown starts")
Check(NS.UI.ArcStep(0) == 0 and NS.UI.ArcStep(0.01) == 1 and NS.UI.ArcStep(0.5) == 6 and NS.UI.ArcStep(1) == 12 and NS.UI.ArcStep(2) == 12, "progress picks one of 12 arc pictures")

-- pedometer
LoadFile("Steps.lua")
local STP = NS.Steps
C.DB().steps = nil
Check(math.floor(STP.StepsFor(100, 2.5)) == 120, "walking: 100 yards = 120 steps")
Check(math.floor(STP.StepsFor(100, 7)) == 55, "running: 100 yards = 55 strides")
Check(STP.Add(120) == nil and math.floor(STP.DB().today) == 120, "steps added")
Check(STP.Add(9900) == 10000, "10 000 steps: the hero asks how you are doing")
local before = STP.DB().today
STP.Started(); STP.Stopped()
Check(STP.DB().today - before == 1, "a single tap counts as one step")
Check(STP.Format(12345) == "12 345" and STP.Format(999) == "999", "steps formatted")
function UnitOnTaxi() return true end
Check(STP.OnFoot() == false, "flights do not count")
UnitOnTaxi = nil
Report("core_test")
