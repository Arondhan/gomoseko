--!strict
-- Определения колец и пул Gacha. OneIn — базовый шанс «1 из N» (при удаче ×1); самое частое кольцо
-- (наименьший OneIn) служит «остатком» — шансы остальных считаются от самого редкого (см. shared/Gacha/GachaMath).
-- Stats — пассивные бонусы надетых колец; SkillId — скилл, который даёт кольцо (Configs/Skills/<SkillId>Config).

local Types = require(script.Parent.Parent.Parent.Types)

local RingsConfig = {}

local function ring(def: Types.RingDef): Types.RingDef
	return def
end

local rings: { Types.RingDef } = {
	-- Common
	ring({
		Id = "ring_copper_band",
		Name = "Copper Band",
		Description = "A plain copper ring. Slightly widens your mana pool.",
		Color = Color3.fromRGB(184, 115, 51),
		Quality = "Common",
		OneIn = 2,
		Stats = { MaxMana = 5 },
	}),
	ring({
		Id = "ring_bone_ring",
		Name = "Bone Ring",
		Description = "Carved from an old bone. Mana returns a little faster.",
		Color = Color3.fromRGB(214, 206, 184),
		Quality = "Common",
		OneIn = 3,
		Stats = { ManaRegen = 0.3 },
	}),
	ring({
		Id = "ring_iron_loop",
		Name = "Iron Loop",
		Description = "Heavy and dependable. Your spells hit a little harder.",
		Color = Color3.fromRGB(140, 146, 156),
		Quality = "Common",
		OneIn = 4,
		Stats = { DamagePct = 3 },
	}),
	-- Uncommon
	ring({
		Id = "ring_silver_signet",
		Name = "Silver Signet",
		Description = "A polished signet that holds extra mana.",
		Color = Color3.fromRGB(200, 208, 220),
		Quality = "Uncommon",
		OneIn = 6,
		Stats = { MaxMana = 10 },
	}),
	ring({
		Id = "ring_wolf_fang",
		Name = "Wolf Fang Ring",
		Description = "A fang set in iron. Sharpens your spells.",
		Color = Color3.fromRGB(150, 170, 130),
		Quality = "Uncommon",
		OneIn = 8,
		Stats = { DamagePct = 6 },
	}),
	ring({
		Id = "ring_windstep",
		Name = "Windstep Ring",
		Description = "Light as air. Your spells reach farther.",
		Color = Color3.fromRGB(150, 220, 200),
		Quality = "Uncommon",
		OneIn = 10,
		Stats = { CastRange = 4 },
	}),
	-- Rare
	ring({
		Id = "ring_focus",
		Name = "Ring of Focus",
		Description = "Clears the mind. Spells recharge faster.",
		Color = Color3.fromRGB(90, 160, 230),
		Quality = "Rare",
		OneIn = 32,
		Stats = { CooldownReductionPct = 8 },
	}),
	ring({
		Id = "ring_sapphire_band",
		Name = "Sapphire Band",
		Description = "A deep blue gem brimming with mana.",
		Color = Color3.fromRGB(60, 110, 230),
		Quality = "Rare",
		OneIn = 48,
		Stats = { MaxMana = 25, ManaRegen = 1 },
	}),
	ring({
		Id = "ring_emberheart",
		Name = "Emberheart",
		Description = "A coal that never cools. Your spells burn hotter.",
		Color = Color3.fromRGB(240, 120, 60),
		Quality = "Rare",
		OneIn = 64,
		Stats = { DamagePct = 12 },
	}),
	ring({
		Id = "ring_ember_band",
		Name = "Ember Band",
		Description = "Hurls a Fireball that explodes and burns everything around the target.",
		SkillId = "Fireball",
		Color = Color3.fromRGB(255, 120, 30),
		Quality = "Rare",
		OneIn = 80,
		Stats = { DamagePct = 4 },
	}),
	-- Epic
	ring({
		Id = "ring_arc_lightning",
		Name = "Arc Lightning Ring",
		Description = "Lightning strikes the target and arcs to nearby enemies.",
		SkillId = "ArcLightning",
		Color = Color3.fromRGB(80, 160, 255),
		Quality = "Epic",
		OneIn = 512,
		Stats = {},
	}),
	ring({
		Id = "ring_fortune_band",
		Name = "Fortune Band",
		Description = "Lady Luck smiles on its wearer. Improves your summon luck.",
		Color = Color3.fromRGB(120, 220, 120),
		Quality = "Epic",
		OneIn = 800,
		Stats = { LuckPct = 10 },
	}),
	ring({
		Id = "ring_archmage",
		Name = "Ring of the Archmage",
		Description = "Worn by masters of the arcane.",
		Color = Color3.fromRGB(170, 100, 255),
		Quality = "Epic",
		OneIn = 1000,
		Stats = { DamagePct = 15, MaxMana = 40 },
	}),
	-- Legendary
	ring({
		Id = "ring_phoenix_ember",
		Name = "Phoenix Ember",
		Description = "Reborn in flame again and again.",
		Color = Color3.fromRGB(255, 150, 40),
		Quality = "Legendary",
		OneIn = 5000,
		Stats = { DamagePct = 20, ManaRegen = 2 },
	}),
	ring({
		Id = "ring_stormcaller",
		Name = "Stormcaller's Loop",
		Description = "Thunder answers its wearer.",
		Color = Color3.fromRGB(110, 190, 255),
		Quality = "Legendary",
		OneIn = 10000,
		Stats = { DamagePct = 25, CooldownReductionPct = 15 },
	}),
	ring({
		Id = "ring_starlit_signet",
		Name = "Starlit Signet",
		Description = "Forged from fallen starlight. Greatly improves summon luck.",
		Color = Color3.fromRGB(255, 240, 160),
		Quality = "Legendary",
		OneIn = 20000,
		Stats = { LuckPct = 20, ManaRegen = 2 },
	}),
	ring({
		Id = "ring_starfall",
		Name = "Starfall Ring",
		Description = "Marks the ground and calls a Meteor down from the sky. Enemies that stay in the circle burn.",
		SkillId = "Meteor",
		Color = Color3.fromRGB(255, 80, 50),
		Quality = "Legendary",
		OneIn = 7500,
		Stats = { DamagePct = 10, CastRange = 6 },
	}),
	-- Mythic
	ring({
		Id = "ring_eclipse",
		Name = "Eclipse Ring",
		Description = "A sliver of night wrapped around the finger.",
		Color = Color3.fromRGB(255, 70, 130),
		Quality = "Mythic",
		OneIn = 1000000,
		Stats = { DamagePct = 50, MaxMana = 60, CooldownReductionPct = 20 },
	}),
	ring({
		Id = "ring_voidheart",
		Name = "Voidheart Band",
		Description = "It hums with the silence between stars.",
		Color = Color3.fromRGB(150, 60, 220),
		Quality = "Mythic",
		OneIn = 2000000,
		Stats = { DamagePct = 40, ManaRegen = 4, LuckPct = 30 },
	}),
	-- Divine
	ring({
		Id = "ring_genesis",
		Name = "Genesis Ring",
		Description = "The first ring ever made. Few have ever seen it.",
		Color = Color3.fromRGB(255, 232, 150),
		Quality = "Divine",
		OneIn = 50000000,
		Stats = { DamagePct = 100, CooldownReductionPct = 30, LuckPct = 50, MaxMana = 100 },
	}),
}

RingsConfig.List = rings

RingsConfig.Rings = {} :: { [string]: Types.RingDef }
for _, def in rings do
	RingsConfig.Rings[def.Id] = def
end

-- Кольцо, которое игрок получает при первом входе
RingsConfig.StartingItems = { "ring_arc_lightning" } :: { string }

return RingsConfig
