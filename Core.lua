--[[
  AFK Gains core: small real-life quests while you play, three daily rings
  and a "profession" of your own that levels as you complete them.

  Built on what research says works for habits:
    * tiny actions often (a minute on your feet every ~45 min beats a long
      break every few hours), the minimum always counts
    * a reward right away (sound, ring, experience), one click to log it
    * no punishment: one missed day does not break the streak, "Later"
      costs nothing, a ring you keep missing quietly gets a smaller goal
    * reminders at natural pauses of the game (UI.lua / World.lua)

  Rings (reset every day):
    Move   stand up (+ bonus push-ups / squats for extra experience)
    Fuel   water, meals
    Mind   read today, breathe for a minute (+ bonus: four minutes more)

  No frames here (tests/core_test.lua).
]]

local _, ns = ...

local C = {}
ns.Core = C

C.RINGS = {
	{ key = "move", goal = 5, min = 2, color = { 1, 0.5, 0.17 } },
	{ key = "fuel", goal = 5, min = 2, color = { 0.25, 0.68, 1 } },
	{ key = "mind", goal = 3, min = 2, color = { 0.75, 0.38, 0.98 } },
}

-- every:   minutes between reminders (and before it can be done again)
-- windows: local hours (meals)
-- daily:   once a day, `after` minutes into your session
-- bonus:   never reminded on its own; extra experience when you do it
-- sit:     seconds the hero sits by the fire while you go and do it
-- guided:  seconds of the breathing guide
C.QUESTS = {
	{ key = "stand", ring = "move", points = 1, xp = 5, every = 45, sit = 60, icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
	{ key = "pushups", ring = "move", points = 1, xp = 12, every = 60, bonus = true, icon = "Interface\\Icons\\Ability_Warrior_Charge" },
	{ key = "squats", ring = "move", points = 1, xp = 12, every = 60, bonus = true, icon = "Interface\\Icons\\Ability_Warrior_Revenge" },
	{ key = "water", ring = "fuel", points = 1, xp = 4, every = 90, sit = 30, icon = "Interface\\Icons\\INV_Drink_07" },
	{ key = "meal", ring = "fuel", points = 2, xp = 10, sit = 900, windows = { { 8, 11 }, { 13, 15 }, { 18, 21 } }, icon = "Interface\\Icons\\INV_Misc_Food_15" },
	{ key = "read", ring = "mind", points = 2, xp = 15, daily = true, after = 60, sit = 600, icon = "Interface\\Icons\\INV_Misc_Book_09" },
	{ key = "breathe", ring = "mind", points = 1, xp = 8, daily = true, after = 30, guided = 60, icon = "Interface\\Icons\\Spell_Nature_Sleep" },
	{ key = "breathe5", ring = "mind", points = 1, xp = 15, daily = true, bonus = true, guided = 240, icon = "Interface\\Icons\\Spell_Holy_MindSooth" },
}

C.byKey = {}
for _, q in ipairs(C.QUESTS) do
	C.byKey[q.key] = q
end

C.MAX_RANK = 300
C.XP_PER_RANK = 10
C.SNOOZE = 10    -- minutes for "Later"
C.MEAL_GAP = 180 -- minutes before a meal can be logged again
C.MISS_DAYS = 3  -- days a ring stays open before its goal shrinks

-- tests replace these
C.clock = {
	now = function() return time() end,
	day = function(t) return date("%Y-%m-%d", t) end,
	hour = function(t) return tonumber(date("%H", t)) end,
}

------------------------------------------------------------------------
-- Saved state
------------------------------------------------------------------------

function C.DB()
	AFKGainsDB = type(AFKGainsDB) == "table" and AFKGainsDB or {}
	local db = AFKGainsDB
	db.xp = db.xp or 0
	db.last = db.last or {}     -- timer start per quest
	db.doneAt = db.doneAt or {} -- last time each quest was done
	db.snooze = db.snooze or {}
	db.meals = db.meals or {}
	db.off = db.off or {}
	db.every = db.every or {}
	db.points = db.points or {}
	db.closed = db.closed or {}
	db.today = db.today or {}
	db.goal = db.goal or {}
	db.miss = db.miss or {}
	db.streak = db.streak or 0
	return db
end

function C.Goal(ring)
	for _, r in ipairs(C.RINGS) do
		if r.key == ring then
			local g = C.DB().goal[ring]
			return type(g) == "number" and g or r.goal
		end
	end
	return 1
end

-- New day: rings start over. The streak counts days you played; one
-- missed day is forgiven, two in a row reset it. A ring missed several
-- days running gets a goal one smaller (never below its minimum).
function C.Roll(now)
	local db = C.DB()
	local today = C.clock.day(now)
	if db.day == today then
		return false
	end
	if db.day then
		local all = true
		for _, r in ipairs(C.RINGS) do
			if db.closed[r.key] then
				db.miss[r.key] = 0
			else
				all = false
				db.miss[r.key] = (db.miss[r.key] or 0) + 1
				if db.miss[r.key] >= C.MISS_DAYS then
					db.goal[r.key] = math.max(r.min, C.Goal(r.key) - 1)
					db.miss[r.key] = 0
				end
			end
		end
		if all then
			db.streak = db.streak + 1
			db.grace = nil
		elseif not db.grace and db.streak > 0 then
			db.grace = true -- forgiven once
		else
			db.streak, db.grace = 0, nil
		end
	end
	db.day, db.points, db.closed, db.meals, db.today = today, {}, {}, {}, {}
	return true
end

-- At login nothing is due at once: interval quests start counting now.
function C.Start(now)
	local db = C.DB()
	C.Roll(now)
	for _, q in ipairs(C.QUESTS) do
		if q.every then
			db.last[q.key] = now
		end
	end
	db.snooze = {}
	C.session = now
end

------------------------------------------------------------------------
-- State of a quest
------------------------------------------------------------------------

function C.Every(q)
	local v = C.DB().every[q.key]
	return type(v) == "number" and v > 0 and v or q.every
end

-- The meal window you are in now (index), or nil.
function C.MealWindow(now)
	local h = C.clock.hour(now)
	for i, w in ipairs(C.byKey.meal.windows) do
		if h >= w[1] and h < w[2] then
			return i
		end
	end
	return nil
end

-- Done and not yet ready again: the tick stays on, the button is locked
-- until the timer runs out (no clicking it a hundred times).
function C.Locked(key, now)
	local db = C.DB()
	local q = C.byKey[key]
	if not q then
		return true
	end
	if q.daily then
		return db.today[key] == true
	end
	local at = db.doneAt[key]
	if not at then
		return false
	end
	if q.windows then
		local w = C.MealWindow(now)
		return (w and db.meals[w]) or now - at < C.MEAL_GAP * 60
	end
	return now - at < C.Every(q) * 60
end

function C.IsDue(key, now)
	local db = C.DB()
	local q = C.byKey[key]
	if not q or q.bonus or db.off[key] or db.paused then
		return false
	end
	if (db.snooze[key] or 0) > now or C.Locked(key, now) then
		return false
	end
	if q.windows then
		local w = C.MealWindow(now)
		return w ~= nil and not db.meals[w]
	end
	if q.daily then
		return now - (C.session or now) >= (q.after or 0) * 60
	end
	return now - (db.last[key] or now) >= C.Every(q) * 60
end

-- Due quests, in list order.
function C.Due(now)
	C.Roll(now)
	local out = {}
	for _, q in ipairs(C.QUESTS) do
		if C.IsDue(q.key, now) then
			out[#out + 1] = q.key
		end
	end
	return out
end

-- Minutes until the quest comes up (0 = now, nil = off / done for today).
function C.MinutesLeft(key, now)
	local db = C.DB()
	local q = C.byKey[key]
	if not q or db.off[key] then
		return nil
	end
	local snooze = (db.snooze[key] or 0) - now
	if q.windows then
		if C.IsDue(key, now) then
			return 0
		end
		local h = C.clock.hour(now)
		for i, w in ipairs(q.windows) do
			if h < w[1] and not db.meals[i] then
				return (w[1] - h) * 60
			end
		end
		return nil
	end
	if q.daily then
		if db.today[key] then
			return nil
		end
		local left = (q.after or 0) * 60 - (now - (C.session or now))
		return math.max(0, math.ceil(math.max(left, snooze) / 60))
	end
	local from = db.last[key] or now
	if q.bonus then
		from = db.doneAt[key] or (now - C.Every(q) * 60)
	end
	local left = C.Every(q) * 60 - (now - from)
	return math.max(0, math.ceil(math.max(left, snooze) / 60))
end

-- Quests that come up within `minutes` (for natural pauses in the game:
-- a flight, the inn, leaving a dungeon). Bonus quests are not included.
function C.Soon(now, minutes)
	C.Roll(now)
	local out = {}
	for _, q in ipairs(C.QUESTS) do
		if not q.bonus and not C.DB().paused and not C.Locked(q.key, now) then
			local m = C.MinutesLeft(q.key, now)
			if m and m <= minutes then
				if not q.windows or C.MealWindow(now) then
					out[#out + 1] = q.key
				end
			end
		end
	end
	return out
end

------------------------------------------------------------------------
-- Doing quests
------------------------------------------------------------------------

-- Marks a quest done. Returns the rings closed by it and whether your
-- rank went up, or nil when it is locked (already done this round).
function C.Complete(key, now)
	local db = C.DB()
	local q = C.byKey[key]
	if not q then
		return nil
	end
	C.Roll(now)
	if C.Locked(key, now) then
		return nil
	end
	local before = C.Rank()
	db.last[key] = now
	db.doneAt[key] = now
	db.snooze[key] = nil
	db.today[key] = true
	if q.windows then
		local w = C.MealWindow(now)
		if w then
			db.meals[w] = true
		end
	end
	db.points[q.ring] = (db.points[q.ring] or 0) + q.points
	db.xp = db.xp + q.xp
	local closed = {}
	for _, r in ipairs(C.RINGS) do
		if r.key == q.ring and not db.closed[r.key] and db.points[r.key] >= C.Goal(r.key) then
			db.closed[r.key] = true
			closed[#closed + 1] = r.key
		end
	end
	return closed, C.Rank() > before
end

function C.Snooze(key, now, minutes)
	C.DB().snooze[key] = now + (minutes or C.SNOOZE) * 60
end

-- 0..1 for each ring today
function C.Progress(ring)
	local db = C.DB()
	local goal = C.Goal(ring)
	return math.min(1, (db.points[ring] or 0) / goal), db.points[ring] or 0, goal
end

function C.AllClosed()
	local db = C.DB()
	for _, r in ipairs(C.RINGS) do
		if not db.closed[r.key] then
			return false
		end
	end
	return true
end

------------------------------------------------------------------------
-- Your own profession: Self-care 1..300
------------------------------------------------------------------------

C.TITLES = {
	{ 1, "Apprentice" },
	{ 75, "Journeyman" },
	{ 150, "Expert" },
	{ 225, "Artisan" },
}

function C.Rank()
	return math.min(C.MAX_RANK, 1 + math.floor(C.DB().xp / C.XP_PER_RANK))
end

function C.Title(rank)
	local t = C.TITLES[1][2]
	for _, e in ipairs(C.TITLES) do
		if (rank or C.Rank()) >= e[1] then
			t = e[2]
		end
	end
	return t
end

return C
