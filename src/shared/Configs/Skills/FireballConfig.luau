--!strict
-- Настройки скилла «Fireball»: огненный шар летит в цель и взрывается, бьёт всех врагов в радиусе взрыва.
-- Сервер читает числа (урон, радиус, скорость, перезарядка), клиент — цвета и звук.

local Types = require(script.Parent.Parent.Parent.Types)

local FireballConfig: Types.SkillConfig = {
	Id = "Fireball",
	Name = "Fireball",
	Kind = "Projectile",

	-- Баланс
	CastRange = 70,
	Damage = 55, -- урон по каждому врагу в радиусе взрыва
	ProjectileSpeed = 70, -- studs/сек
	ExplosionRadius = 10,
	Cooldown = 4,
	ManaCost = 25,
	CastTime = 0.5,
	DefaultKey = Enum.KeyCode.E,

	-- Визуал (клиент)
	Color = Color3.fromRGB(255, 120, 30),
	CoreColor = Color3.fromRGB(255, 230, 140),
	SoundId = "", -- пусто = звук из Sounds (FireballCast / Explosion)
	SoundVolume = 0.8,
}

return FireballConfig
