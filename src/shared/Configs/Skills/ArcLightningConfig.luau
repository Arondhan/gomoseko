--!strict
-- Настройки скилла «Arc Lightning» (цепная молния). Всё, что влияет на баланс и внешний вид, правится здесь.
-- Сервер читает числа (урон, радиусы, кулдаун), клиент — визуал (цвета, ширина, звук).

local Types = require(script.Parent.Parent.Parent.Types)

local ArcLightningConfig: Types.SkillConfig = {
	Id = "ArcLightning",
	Name = "Arc Lightning",

	-- Баланс
	CastRange = 60, -- макс. дистанция от кастера до первичной цели (studs)
	Damage = 35, -- урон по каждой пораженной цели
	MaxBounces = 5, -- число перескоков ПОСЛЕ первичного удара (всего целей <= 1 + MaxBounces)
	BounceRadius = 25, -- радиус поиска следующей цели от текущей (studs)
	BounceDelay = 0.17, -- пауза между прыжками, сек (рекомендуется 0.15–0.2)
	Cooldown = 3, -- перезарядка, сек
	ManaCost = 20,
	CastTime = 0.4, -- сек; 0 = мгновенный каст без cast bar
	DefaultKey = Enum.KeyCode.Q, -- быстрая клавиша (работает, пока кольцо надето)

	-- Визуал (клиент)
	Color = Color3.fromRGB(80, 160, 255), -- внешнее свечение
	CoreColor = Color3.fromRGB(235, 245, 255), -- яркое ядро
	Width = 1.4, -- ширина внешнего луча
	CoreWidth = 0.45, -- ширина ядра
	ZigzagSegments = 7, -- число изломов на одно звено
	ZigzagAmplitude = 1.6, -- максимальное боковое смещение излома (studs)
	FadeTime = 0.3, -- время растворения молнии
	SoundId = "", -- вставьте "rbxassetid://..." — пустая строка = без звука
	SoundVolume = 0.7,
}

return ArcLightningConfig
