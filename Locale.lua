--[[
  AFK Gains: translations. English text is the key; other languages map it.
]]

local _, ns = ...

local L = {
	ruRU = {
		-- rings
		["Move"] = "Движение",
		["Fuel"] = "Заправка",
		["Mind"] = "Голова",
		-- quests: name and a hint from the game world
		["Stand up and stretch"] = "Встань и потянись",
		["Your hero runs all day. Your turn."] = "Герой бегает весь день. Твоя очередь.",
		["Read today"] = "Почитай сегодня",
		["At least 5 pages, the rest is up to you. Your hero can wait at the inn."] = "Хотя бы 5 страниц, дальше как пойдёт. Герой подождёт в таверне.",
		["Your hero is resting at the inn: a good moment."] = "Герой отдыхает в таверне: самое время.",
		["You have %s in your bags: share a drink with your hero."] = "У вас в сумках есть %s: выпейте вместе с героем.",
		["You have %s in your bags: eat together with your hero."] = "У вас в сумках есть %s: поешьте вместе с героем.",
		["Light a Basic Campfire and sit your hero by it."] = "Разожгите «Простой костёр» и посадите героя рядом.",
		["Your hero is drinking. Grab a glass too."] = "Герой пьёт. Возьми стакан и ты.",
		["Your hero is eating. How about you?"] = "Герой ест. А ты?",
		["Self-care level up: %d!"] = "Новый уровень заботы о себе: %d!",
		["Drink a glass of water"] = "Выпей стакан воды",
		["Your hero drinks to restore mana. So should you."] = "Герой пьёт, чтобы восстановить ману. Ты тоже.",
		["Time to eat"] = "Пора поесть",
		["Set your hero by the fire with food: Well Fed for both of you."] = "Поставь героя у костра с едой: «Сытость» вам обоим.",
		["Stand up for a minute"] = "Встань на минуту",
		["Look out of the window while you are up. Your hero can rest too: /sit by a campfire."] = "Пока стоишь, посмотри в окно. Герой тоже может передохнуть: /sit у костра.",
		["Walk around for a minute"] = "Пройдись минутку",
		["Roll your neck and shoulders: the mouse hand needs it most."] = "Разомни шею и плечи: руке с мышкой это нужнее всего.",
		["Bonus: 10 push-ups"] = "Бонус: 10 отжиманий",
		["Bonus: 10 squats"] = "Бонус: 10 приседаний",
		["Extra experience. Only if you feel like it."] = "Дополнительный опыт. Только если есть настроение.",
		["Nice! Up for a bonus?"] = "Молодец! Бонус?",
		["Push-ups or squats give extra experience."] = "Отжимания или приседания дают дополнительный опыт.",
		["Push-ups"] = "Отжался",
		["Squats"] = "Присел",
		["Not now"] = "Не сейчас",
		["Done for today"] = "Сделано на сегодня",
		["Bonus"] = "Бонус",
		["+%d experience"] = "+%d опыта",
		["Breathe for a minute"] = "Подыши минуту",
		["Sit your hero by the fire and sit with them: in through the nose, a long slow breath out."] = "Посади героя у костра и посиди с ним: вдох носом, длинный медленный выдох.",
		["Bonus: 4 more minutes"] = "Бонус: ещё 4 минуты",
		["Start"] = "Начать",
		["Breathe in"] = "Вдох",
		["Breathe out"] = "Выдох",
		["Stop"] = "Хватит",
		["Keep going"] = "Продолжить",
		["Well done. Four more minutes for a bonus?"] = "Отлично. Ещё 4 минуты за бонус?",
		["The full five minutes is what the study used."] = "Пять минут — столько дышали в исследовании.",
		["Your hero rests by the fire. Time left: %s"] = "Герой отдыхает у костра. Осталось: %s",
		["Time is up. Press Done when you are back."] = "Время вышло. Нажми «Готово», когда вернёшься.",
		["Your hero has walked %s steps today. And you?"] = "Твой герой прошёл сегодня %s шагов. А ты?",
		["Your hero's steps today"] = "Шаги героя сегодня",
		["All time"] = "Всего",
		-- toast and widget
		["Done"] = "Готово",
		["Later"] = "Позже",
		["Sit"] = "Сесть",
		["Ring closed: %s!"] = "Кольцо закрыто: %s!",
		["All three rings closed. You are Well Rested."] = "Все три кольца закрыты. Вы хорошо отдохнули.",
		["Self-care"] = "Забота о себе",
		["Apprentice"] = "Ученик",
		["Journeyman"] = "Подмастерье",
		["Expert"] = "Умелец",
		["Artisan"] = "Мастер",
		["now"] = "сейчас",
		["in %d min"] = "через %d мин",
		["off"] = "выкл",
		["on"] = "вкл",
		["Streak: %d days"] = "Серия: %d дн.",
		["Click: quests  ·  Drag: move"] = "Клик: квесты  ·  Тяни: переместить",
		["Reminders paused."] = "Напоминания на паузе.",
		["Reminders back on."] = "Напоминания снова включены.",
		["Commands: /gains show | pause | test | every <quest> <min> | off <quest> | on <quest>"] = "Команды: /gains show | pause | test | every <квест> <мин> | off <квест> | on <квест>",
		["Quests: stand, pushups, squats, water, meal, read, breathe"] = "Квесты: stand, pushups, squats, water, meal, read, breathe",
		["%s: every %d min"] = "%s: каждые %d мин",
		["Today"] = "Сегодня",
	},
}

local active = L[GetLocale and GetLocale() or "enUS"] or {}

function ns.T(s)
	return active[s] or s
end

ns.TEXT = {
	stand = { "Stand up for a minute", "Look out of the window while you are up. Your hero can rest too: /sit by a campfire." },
	pushups = { "Bonus: 10 push-ups", "Extra experience. Only if you feel like it." },
	squats = { "Bonus: 10 squats", "Extra experience. Only if you feel like it." },
	water = { "Drink a glass of water", "Your hero drinks to restore mana. So should you." },
	meal = { "Time to eat", "Set your hero by the fire with food: Well Fed for both of you." },
	read = { "Read today", "At least 5 pages, the rest is up to you. Your hero can wait at the inn." },
	breathe = { "Breathe for a minute", "Sit your hero by the fire and sit with them: in through the nose, a long slow breath out." },
	breathe5 = { "Bonus: 4 more minutes", "Extra experience. Only if you feel like it." },
}
ns.VARIANTS = {
	stand = {
		{ "Stand up for a minute", "Look out of the window while you are up. Your hero can rest too: /sit by a campfire." },
		{ "Walk around for a minute", "Your hero runs all day. Your turn." },
		{ "Stand up and stretch", "Roll your neck and shoulders: the mouse hand needs it most." },
	},
}
ns.RING_NAME = { move = "Move", fuel = "Fuel", mind = "Mind" }
