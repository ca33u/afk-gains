--[[
  AFK Gains UI: three rings you can drag anywhere (your level in the middle),
  a reminder toast at the top of the screen, and the quest list on click.

  Reminders come at natural pauses of the game when they are due soon:
  a flight, arriving at an inn or a city, leaving a dungeon, your hero
  sitting down to eat or drink. A timer is the fallback. Never in combat.

  /gains                 show or hide the rings
  /gains pause           pause / resume reminders
  /gains test            show a reminder now
  /gains every water 60  change how often a quest comes up
  /gains off water       turn a quest off (on to bring it back)
]]

local _, ns = ...
local T = ns.T
local C = ns.Core

local U = {}
ns.UI = U

local P = "|cffff9a3cAFK Gains|r "
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil

U.SOON = 15 -- minutes: at a natural pause, bring forward what is due this soon

local function Now()
	return C.clock.now()
end

local function Sound(kit, fallback)
	if PlaySound then
		pcall(PlaySound, (SOUNDKIT and SOUNDKIT[kit]) or fallback)
	end
end

local function RingName(key)
	return T(ns.RING_NAME[key] or key)
end

local function Busy()
	return InCombatLockdown and InCombatLockdown()
end

------------------------------------------------------------------------
-- Quest row: icon, name, when it comes, and a square Warcraft button to
-- mark it done (a tick stays in it until the quest comes round again).
------------------------------------------------------------------------

function U.NewRow(parent, q, font)
	local r = CreateFrame("Frame", nil, parent)
	r:SetHeight(28)
	r.key = q.key
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(20, 20)
	r.icon:SetPoint("LEFT")
	r.icon:SetTexture(q.icon)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.text = r:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	r.text:SetPoint("LEFT", 28, 0)
	r.text:SetJustifyH("LEFT")
	r.text:SetWordWrap(false)
	r.when = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	r.when:SetPoint("RIGHT", -36, 0)
	r.text:SetPoint("RIGHT", r.when, "LEFT", -6, 0)
	-- done button: our own square, dark red with a gold frame, a gold tick
	-- inside when done (no game button underneath, so nothing shows through)
	local b = CreateFrame("Button", nil, r)
	b:SetSize(24, 24)
	b:SetPoint("RIGHT", 0, 0)
	b.frame = b:CreateTexture(nil, "BACKGROUND")
	b.frame:SetAllPoints()
	b.frame:SetColorTexture(0.85, 0.66, 0.22, 1)
	b.inner = b:CreateTexture(nil, "BORDER")
	b.inner:SetPoint("TOPLEFT", 2, -2)
	b.inner:SetPoint("BOTTOMRIGHT", -2, 2)
	b.inner:SetColorTexture(0.38, 0.05, 0.03, 1)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 2, -2)
	hl:SetPoint("BOTTOMRIGHT", -2, 2)
	hl:SetColorTexture(1, 0.8, 0.3, 0.18)
	b.tick = b:CreateTexture(nil, "OVERLAY")
	b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	b.tick:SetSize(26, 26)
	b.tick:SetPoint("CENTER", 1, 1)
	b.tick:Hide()
	r.check = b
	r.check:SetScript("OnClick", function()
		if not C.Locked(q.key, Now()) then
			U.Complete(q.key)
		end
	end)
	r.check:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(T(ns.TEXT[q.key][1]))
		GameTooltip:AddLine(string.format(T("+%d experience"), q.xp), 1, 0.82, 0)
		GameTooltip:Show()
	end)
	r.check:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

function U.UpdateRow(r, now)
	local q = C.byKey[r.key]
	local db = C.DB()
	local locked = C.Locked(r.key, now)
	local m = C.MinutesLeft(r.key, now)
	r.text:SetText(T(ns.TEXT[r.key][1]))
	r.check.tick:SetShown(locked)
	local when
	if db.off[r.key] then
		when = T("off")
	elseif locked then
		if q.daily or (q.windows and not m) then
			when = T("Done for today")
		elseif m and m > 0 then
			when = string.format(T("in %d min"), m)
		else
			when = ""
		end
	elseif q.bonus or (q.optIn and not db.used[r.key]) then
		when = "|cffffd100" .. T("Bonus") .. "|r"
	elseif m == 0 then
		when = "|cffffd100" .. T("now") .. "|r"
	elseif m then
		when = string.format(T("in %d min"), m)
	else
		when = ""
	end
	r.when:SetText(when)
	r:SetAlpha(db.off[r.key] and 0.4 or (locked and 0.6 or 1))
end

------------------------------------------------------------------------
-- Rings: three solid rings drawn from ready-made textures (Media/Rings,
-- made by tools/rings.py): a dark track and the filled arc in twelve
-- steps with the colour gradient baked in. Two textures per ring, nothing
-- to recalculate. Your level sits in the middle in Warcraft's serif
-- font (Morpheus, the quest-title font).
------------------------------------------------------------------------

local SIZE = 84
local STEPS = 12
local RING_PATH = "Interface\\AddOns\\AFKGains\\Media\\Rings\\"
local LEVEL_FONT = "Fonts\\MORPHEUS.TTF"
local widget

-- Which of the twelve arc pictures shows progress p (0..1); 0 = none.
function U.ArcStep(p)
	if not p or p <= 0 then
		return 0
	end
	return math.max(1, math.min(STEPS, math.floor(p * STEPS + 0.5)))
end

local function BuildRings()
	widget = CreateFrame("Button", "AFKGainsRings", UIParent)
	widget:SetSize(SIZE, SIZE)
	widget:SetFrameStrata("MEDIUM")
	widget:SetClampedToScreen(true)
	widget:SetMovable(true)
	widget:RegisterForDrag("LeftButton")
	widget:SetScript("OnDragStart", widget.StartMoving)
	widget:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		C.DB().pos = { point, x, y }
	end)
	widget.rings = {}
	for _, r in ipairs(C.RINGS) do
		local track = widget:CreateTexture(nil, "BACKGROUND")
		track:SetAllPoints()
		track:SetTexture(RING_PATH .. r.key .. "_track")
		local arc = widget:CreateTexture(nil, "ARTWORK")
		arc:SetAllPoints()
		widget.rings[#widget.rings + 1] = { key = r.key, arc = arc }
	end
	widget.level = widget:CreateFontString(nil, "OVERLAY")
	-- a font object first, so the text still shows if Morpheus is missing
	widget.level:SetFontObject("GameFontNormalLarge")
	pcall(widget.level.SetFont, widget.level, LEVEL_FONT, 22, "OUTLINE")
	widget.level:SetTextColor(1, 0.82, 0.25)
	widget.level:SetPoint("CENTER", 0, -1)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine("|cffff9a3cAFK Gains|r  " .. T("Today"))
		for _, r in ipairs(C.RINGS) do
			local _, have, goal = C.Progress(r.key)
			GameTooltip:AddDoubleLine(RingName(r.key), have .. "/" .. goal, r.color[1], r.color[2], r.color[3], 1, 1, 1)
		end
		local rank = C.Rank()
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine(T("Self-care") .. " (" .. T(C.Title(rank)) .. ")", rank .. "/" .. C.MAX_RANK, 1, 0.82, 0, 1, 1, 1)
		if C.DB().streak > 0 then
			GameTooltip:AddLine(string.format(T("Streak: %d days"), C.DB().streak), 0.7, 0.7, 0.7)
		end
		if ns.Steps then
			local st = ns.Steps.DB()
			GameTooltip:AddDoubleLine(T("Your hero's steps today"), ns.Steps.Format(st.today), 0.7, 0.7, 0.7, 1, 1, 1)
			GameTooltip:AddDoubleLine(T("All time"), ns.Steps.Format(st.total), 0.5, 0.5, 0.5, 0.8, 0.8, 0.8)
		end
		GameTooltip:AddLine(T("Click: quests  ·  Drag: move"), 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
	widget:SetScript("OnClick", function() U.ToggleList() end)
	local pos = C.DB().pos
	if type(pos) == "table" and pos[1] then
		widget:SetPoint(pos[1], UIParent, pos[1], pos[2] or 0, pos[3] or 0)
	else
		widget:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -230, -20)
	end
end

U.BuildRings = BuildRings

function U.RefreshRings()
	if not widget then
		return
	end
	for _, ring in ipairs(widget.rings) do
		local k = U.ArcStep(C.Progress(ring.key))
		if k > 0 then
			ring.arc:SetTexture(RING_PATH .. ring.key .. "_" .. k)
			ring.arc:Show()
		else
			ring.arc:Hide()
		end
	end
	widget.level:SetText(C.Rank())
	widget:SetShown(not C.DB().hidden)
end

------------------------------------------------------------------------
-- Quest list (click the rings)
------------------------------------------------------------------------

local list

local function BuildList()
	list = CreateFrame("Frame", "AFKGainsList", UIParent, BACKDROP)
	local ROW, HEAD = 30, 24
	list:SetSize(320, 30 + #C.QUESTS * ROW + #C.RINGS * HEAD)
	list:SetFrameStrata("DIALOG")
	list:SetClampedToScreen(true)
	-- the game's own dialog frame: dark parchment with the gold border
	if list.SetBackdrop then
		list:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	-- quests grouped under a small heading per ring, in the ring's colour,
	-- with the ring's count on the right
	list.rows, list.heads = {}, {}
	local y = -16
	for _, ring in ipairs(C.RINGS) do
		local h = list:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h:SetPoint("TOPLEFT", 18, y - 6)
		h:SetTextColor(ring.color[1], ring.color[2], ring.color[3])
		local count = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		count:SetPoint("TOPRIGHT", -18, y - 6)
		local line = list:CreateTexture(nil, "ARTWORK")
		line:SetHeight(1)
		line:SetPoint("LEFT", h, "RIGHT", 6, 0)
		line:SetPoint("RIGHT", count, "LEFT", -6, 0)
		line:SetColorTexture(ring.color[1], ring.color[2], ring.color[3], 0.35)
		list.heads[#list.heads + 1] = { ring = ring.key, text = h, count = count }
		y = y - HEAD
		for _, q in ipairs(C.QUESTS) do
			if q.ring == ring.key then
				local row = U.NewRow(list, q, "GameFontHighlightSmall")
				row:SetPoint("TOPLEFT", 18, y)
				row:SetPoint("RIGHT", -16, 0)
				list.rows[#list.rows + 1] = row
				y = y - ROW
			end
		end
	end
	-- an obvious way out: the game's red close button in the corner
	local close = CreateFrame("Button", nil, list, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() list:Hide() end)
	list:Hide()
	if UISpecialFrames then
		table.insert(UISpecialFrames, "AFKGainsList")
	end
end

-- A click anywhere outside the list (and outside the rings) closes it.
local outside = CreateFrame("Frame")
outside:SetScript("OnEvent", function()
	if not (list and list:IsShown()) then
		return
	end
	local over = MouseIsOver and (MouseIsOver(list) or (widget and MouseIsOver(widget)))
	if not over then
		list:Hide()
	end
end)
pcall(outside.RegisterEvent, outside, "GLOBAL_MOUSE_DOWN")

function U.RefreshList()
	if not (list and list:IsShown()) then
		return
	end
	local now = Now()
	for _, h in ipairs(list.heads) do
		local _, have, goal = C.Progress(h.ring)
		h.text:SetText(RingName(h.ring))
		h.count:SetText(have .. "/" .. goal)
	end
	for _, row in ipairs(list.rows) do
		U.UpdateRow(row, now)
	end
end

function U.ToggleList()
	if not list then
		BuildList()
	end
	if list:IsShown() then
		list:Hide()
		return
	end
	list:ClearAllPoints()
	list:SetPoint("TOPRIGHT", widget, "BOTTOMRIGHT", 0, -4)
	list:Show()
	U.RefreshList()
end

function U.RefreshAll()
	U.RefreshRings()
	U.RefreshList()
end

------------------------------------------------------------------------
-- Toast: one reminder at a time, with up to three buttons
------------------------------------------------------------------------

local toast

local function Button(parent, w)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	return b
end

local function BuildToast()
	toast = CreateFrame("Frame", "AFKGainsToast", UIParent, BACKDROP)
	toast:SetSize(380, 74)
	toast:SetPoint("TOP", UIParent, "TOP", 0, -110)
	toast:SetFrameStrata("DIALOG")
	if toast.SetBackdrop then
		toast:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		toast:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
		toast:SetBackdropBorderColor(1, 0.6, 0.24, 0.8)
	end
	toast.icon = toast:CreateTexture(nil, "ARTWORK")
	toast.icon:SetSize(40, 40)
	toast.icon:SetPoint("TOPLEFT", 10, -10)
	toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	toast.title:SetPoint("TOPLEFT", 58, -10)
	toast.title:SetPoint("RIGHT", -30, 0)
	toast.title:SetJustifyH("LEFT")
	toast.hint = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	toast.hint:SetPoint("TOPLEFT", 58, -28)
	toast.hint:SetPoint("RIGHT", -10, 0)
	toast.hint:SetJustifyH("LEFT")
	toast.close = CreateFrame("Button", nil, toast, "UIPanelCloseButton")
	toast.close:SetSize(24, 24)
	toast.close:SetPoint("TOPRIGHT", -2, -2)
	toast.close:SetScript("OnClick", function()
		if toast.key and C.byKey[toast.key] then
			C.Snooze(toast.key, Now())
		end
		toast:Hide()
	end)
	toast.b = { Button(toast, 90), Button(toast, 90), Button(toast, 90) }
	toast.b[1]:SetPoint("BOTTOMRIGHT", -10, 8)
	toast.b[2]:SetPoint("RIGHT", toast.b[1], "LEFT", -4, 0)
	toast.b[3]:SetPoint("RIGHT", toast.b[2], "LEFT", -4, 0)
	toast:Hide()
end

-- buttons: list of { label, fn }, the first is the rightmost
local function Fill(key, icon, title, hint, buttons)
	if not toast then
		BuildToast()
	end
	toast:SetScript("OnUpdate", nil)
	toast.key = key
	toast.icon:SetTexture(icon)
	toast.title:SetText(title)
	toast.hint:SetText(hint)
	for i, b in ipairs(toast.b) do
		local spec = buttons[i]
		if spec then
			b:SetText(spec[1])
			b:SetScript("OnClick", spec[2])
			b:Show()
		else
			b:Hide()
		end
	end
	toast:SetHeight(math.max(74, 44 + (toast.hint:GetStringHeight() or 12) + 24))
	toast:Show()
end

function U.ShowToast(key)
	local q = C.byKey[key]
	if not q then
		return
	end
	local text = ns.TEXT[key]
	local variants = ns.VARIANTS and ns.VARIANTS[key]
	if variants then
		text = variants[math.random(#variants)]
	end
	local hint = ns.World and ns.World.Hint(key)
	if q.guided then
		Fill(key, q.icon, T(text[1]), T(text[2]), {
			{ T("Start"), function() U.Guide(key) end },
			{ T("Later"), function()
				C.Snooze(key, Now())
				toast:Hide()
			end },
			-- the hero sits by the fire and the breathing starts
			{ T("Sit"), function()
				U.Sit()
				U.Guide(key)
			end },
		})
		Sound("IG_QUEST_LIST_OPEN", 875)
		return
	end
	local function Done()
		toast:Hide()
		U.Complete(key)
		if key == "stand" then
			U.OfferBonus()
		end
	end
	Fill(key, q.icon, T(text[1]), hint or T(text[2]), {
		{ T("Done"), Done },
		{ T("Later"), function()
			C.Snooze(key, Now())
			toast:Hide()
		end },
		-- the hero sits by the fire while you go and do it; a countdown shows
		-- how long, and you press Done when you are back
		{ T("Sit"), function()
			U.Sit()
			U.Countdown(key, Done)
		end },
	})
	Sound("IG_QUEST_LIST_OPEN", 875)
end

-- "m:ss" for seconds
function U.Clock(sec)
	sec = math.max(0, math.ceil(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- The hero sits; the toast counts down the quest's time. Done can be
-- pressed any time; when the time is up a chime sounds.
function U.Countdown(key, done)
	local q = C.byKey[key]
	if not (q and toast) then
		return
	end
	local total = q.sit or 60
	local started = GetTime and GetTime() or 0
	local chimed = false
	local text = toast.title:GetText()
	local function Stop()
		toast:SetScript("OnUpdate", nil)
	end
	Fill(key, q.icon, text, string.format(T("Your hero rests by the fire. Time left: %s"), U.Clock(total)), {
		{ T("Done"), function()
			Stop()
			done()
		end },
		{ T("Later"), function()
			Stop()
			C.Snooze(key, Now())
			toast:Hide()
		end },
	})
	toast:SetScript("OnUpdate", function()
		local left = total - ((GetTime and GetTime() or 0) - started)
		if left > 0 then
			toast.hint:SetText(string.format(T("Your hero rests by the fire. Time left: %s"), U.Clock(left)))
		elseif not chimed then
			chimed = true
			toast.hint:SetText(T("Time is up. Press Done when you are back."))
			Sound("READY_CHECK", 8960)
		end
	end)
end

function U.Sit()
	if DoEmote then
		pcall(DoEmote, "SIT")
	end
end

-- After standing up: push-ups or squats for extra experience, if not done lately.
function U.OfferBonus()
	local now = Now()
	local buttons = {}
	for _, k in ipairs({ "squats", "pushups" }) do
		if not C.Locked(k, now) and not C.DB().off[k] then
			buttons[#buttons + 1] = { T(k == "squats" and "Squats" or "Push-ups"), function()
				toast:Hide()
				U.Complete(k)
			end }
		end
	end
	if #buttons == 0 then
		return
	end
	buttons[#buttons + 1] = { T("Not now"), function() toast:Hide() end }
	Fill("bonus", C.byKey.pushups.icon, T("Nice! Up for a bonus?"), T("Push-ups or squats give extra experience."), buttons)
end

------------------------------------------------------------------------
-- Breathing guide: a ring grows while you breathe in (4 s) and shrinks
-- while you breathe out (6 s). When the time is up the quest is done.
------------------------------------------------------------------------

U.INHALE, U.EXHALE = 4, 6

-- 0..1 size of the ring `t` seconds into the exercise, and the phase.
function U.BreathAt(t)
	local cycle = U.INHALE + U.EXHALE
	local x = t % cycle
	if x < U.INHALE then
		local k = x / U.INHALE
		return 0.5 - 0.5 * math.cos(k * math.pi), "in"
	end
	local k = (x - U.INHALE) / U.EXHALE
	return 0.5 + 0.5 * math.cos(k * math.pi), "out"
end

function U.Guide(key)
	local q = C.byKey[key]
	if not (q and q.guided and toast) then
		return
	end
	if not toast.breath then
		toast.breath = toast:CreateTexture(nil, "OVERLAY")
		toast.breath:SetTexture("Interface\\AddOns\\AFKGains\\Media\\Rings\\fuel_12")
		toast.breath:SetPoint("CENTER", toast.icon, "CENTER")
	end
	toast.icon:SetAlpha(0.15)
	toast.breath:Show()
	local started = GetTime and GetTime() or 0
	local function Stop()
		toast:SetScript("OnUpdate", nil)
		toast.breath:Hide()
		toast.icon:SetAlpha(1)
	end
	Fill(key, q.icon, T("Breathe in"), "", { { T("Stop"), function()
		Stop()
		toast:Hide()
	end } })
	toast.breath:Show()
	toast.icon:SetAlpha(0.15)
	toast:SetScript("OnUpdate", function()
		local t = (GetTime and GetTime() or 0) - started
		local left = q.guided - t
		if left <= 0 then
			Stop()
			toast:Hide()
			U.Complete(key)
			if key == "breathe" and not C.Locked("breathe5", Now()) and not C.DB().off.breathe5 then
				Fill("bonus", C.byKey.breathe5.icon, T("Well done. Four more minutes for a bonus?"), T("The full five minutes is what the study used."), {
					{ T("Keep going"), function() U.Guide("breathe5") end },
					{ T("Not now"), function() toast:Hide() end },
				})
			end
			return
		end
		local size, phase = U.BreathAt(t)
		local px = 18 + size * 46
		toast.breath:SetSize(px, px)
		toast.title:SetText(T(phase == "in" and "Breathe in" or "Breathe out"))
		toast.hint:SetText(string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60)))
	end)
end

------------------------------------------------------------------------
-- Completing and the clock
------------------------------------------------------------------------

function U.Complete(key)
	local closed, ranked = C.Complete(key, Now())
	if not closed then
		U.RefreshAll()
		return
	end
	Sound("IG_QUEST_LIST_COMPLETE", 878)
	local q = C.byKey[key]
	if UIErrorsFrame and UIErrorsFrame.AddMessage then
		pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, string.format(T("+%d experience"), q.xp), 1, 0.82, 0)
	end
	for _, ring in ipairs(closed) do
		print(P .. "|cffffd100" .. string.format(T("Ring closed: %s!"), RingName(ring)) .. "|r")
		if RaidNotice_AddMessage and RaidWarningFrame then
			pcall(RaidNotice_AddMessage, RaidWarningFrame, string.format(T("Ring closed: %s!"), RingName(ring)), { r = 1, g = 0.6, b = 0.24 })
		end
	end
	if #closed > 0 and C.AllClosed() then
		print(P .. "|cff40ff40" .. T("All three rings closed. You are Well Rested.") .. "|r")
	end
	if ranked then
		local text = string.format(T("Self-care level up: %d!"), C.Rank())
		print(P .. "|cff7fbfff" .. text .. "|r")
		if RaidNotice_AddMessage and RaidWarningFrame then
			pcall(RaidNotice_AddMessage, RaidWarningFrame, text, { r = 1, g = 0.82, b = 0.2 })
		end
		Sound("LEVELUP", 888)
	end
	if toast and toast:IsShown() and toast.key == key then
		toast:Hide()
	end
	U.RefreshAll()
end

-- Shows the first quest in `keys` unless busy or a toast is up.
function U.Offer(keys)
	if not keys[1] or Busy() or (toast and toast:IsShown()) then
		return false
	end
	U.ShowToast(keys[1])
	return true
end

-- Every 30 s: the timer fallback.
function U.Tick()
	U.RefreshAll()
	U.Offer(C.Due(Now()))
end

-- A natural pause in the game: bring forward what is due soon.
function U.Pause()
	U.Offer(C.Soon(Now(), U.SOON))
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local wasInInstance = false

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		C.Start(Now())
		BuildRings()
		U.RefreshRings()
		if C_Timer and C_Timer.NewTicker then
			C_Timer.NewTicker(30, U.Tick)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- out of combat: a reminder that waited can show now
		if C_Timer and C_Timer.After then
			C_Timer.After(3, U.Tick)
		end
	elseif event == "PLAYER_CONTROL_LOST" then
		-- taking a flight
		if C_Timer and C_Timer.After then
			C_Timer.After(2, function()
				if UnitOnTaxi and UnitOnTaxi("player") then
					U.Pause()
				end
			end)
		end
	elseif event == "PLAYER_UPDATE_RESTING" then
		if IsResting and IsResting() then
			U.Pause()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		local inside = IsInInstance and IsInInstance()
		if wasInInstance and not inside and C_Timer and C_Timer.After then
			C_Timer.After(3, U.Pause) -- out of a dungeon
		end
		wasInInstance = inside and true or false
	elseif event == "UNIT_AURA" then
		local key = ns.World and ns.World.Nudge(Now())
		-- once per half hour at most, so every sip does not pop it again
		local tag = key and (key .. math.floor(Now() / 1800))
		if key and U.nudged ~= tag and U.Offer({ key }) then
			U.nudged = tag
		end
	end
end)
ev:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_CONTROL_LOST", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD" }) do
	pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent or ev.RegisterEvent, ev, "UNIT_AURA", "player")

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------

SLASH_AFKGAINS1 = "/gains"
SLASH_AFKGAINS2 = "/afkgains"
SlashCmdList = SlashCmdList or {}
SlashCmdList.AFKGAINS = function(msg)
	local db = C.DB()
	local cmd, a, b = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)")
	if cmd == "" or cmd == "show" then
		db.hidden = not db.hidden
		U.RefreshRings()
	elseif cmd == "pause" then
		db.paused = not db.paused
		print(P .. T(db.paused and "Reminders paused." or "Reminders back on."))
	elseif cmd == "test" then
		U.ShowToast("stand")
	elseif cmd == "every" and C.byKey[a] and tonumber(b) then
		db.every[a] = math.max(5, tonumber(b))
		print(P .. string.format(T("%s: every %d min"), T(ns.TEXT[a][1]), db.every[a]))
	elseif (cmd == "off" or cmd == "on") and C.byKey[a] then
		db.off[a] = cmd == "off" or nil
		print(P .. T(ns.TEXT[a][1]) .. ": " .. T(cmd))
		U.RefreshAll()
	else
		print(P .. T("Commands: /gains show | pause | test | every <quest> <min> | off <quest> | on <quest>"))
		print(P .. T("Quests: stand, pushups, squats, water, meal, pet, read, breathe"))
	end
end
