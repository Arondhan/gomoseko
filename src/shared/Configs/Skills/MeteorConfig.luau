--!strict
-- Настройки скилла «Meteor»: метка на земле у цели, через Delay секунд с неба падает метеор и бьёт всех в круге Radius.
-- Удар приходится по точке, отмеченной в момент каста: цель, успевшая уйти, не пострадает.

local Types = require(script.Parent.Parent.Parent.Types)

local MeteorConfig: Types.SkillConfig = {
	Id = "Meteor",
	Name = "Meteor",
	Kind = "Meteor",

	-- Баланс
	CastRange = 80,
	Damage = 140,
	Radius = 18,
	Delay = 1.4,
	FallHeight = 90,
	Cooldown = 12,
	ManaCost = 60,
	CastTime = 0.8,
	DefaultKey = Enum.KeyCode.R,

	-- Визуал (клиент)
	Color = Color3.fromRGB(255, 70, 40),
	CoreColor = Color3.fromRGB(255, 200, 90),
	SoundId = "",
	SoundVolume = 1,
}

return MeteorConfig
