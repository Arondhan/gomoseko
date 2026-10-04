-- Проверки PowerMath вне Roblox. Запуск из корня репозитория: luau tools/tests/power_math_test.luau
local PowerMath = require("../../src/shared/Combat/PowerMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local level = { MaxLevel = 60, DamagePctPerLevel = 2, BaseHealth = 100, HealthPerLevel = 6, ManaPerLevel = 1 }
local ring = { MaxLevel = 10, PassivePerLevel = 0.12, SkillDamagePctPerLevel = 8, EssenceBase = 8, GoldBase = 50, CostGrowth = 1.5 }

-- уровень игрока
check("level 1 has no bonus", PowerMath.levelDamagePct(1, level) == 0 and PowerMath.levelMaxMana(1, level) == 0)
check("level 1 base health", PowerMath.levelMaxHealth(1, level) == 100)
check("level 11 damage +20%", PowerMath.levelDamagePct(11, level) == 20)
check("level 11 health 160", PowerMath.levelMaxHealth(11, level) == 160)
check("level 11 mana +10", PowerMath.levelMaxMana(11, level) == 10)
check("level capped at 60", PowerMath.levelDamagePct(999, level) == 118)
check("level below 1 treated as 1", PowerMath.levelDamagePct(-5, level) == 0)
check("level bonus grows", PowerMath.levelDamagePct(30, level) > PowerMath.levelDamagePct(10, level))

-- уровень кольца
check("missing level is 1", PowerMath.ringLevel(nil, ring) == 1)
check("nan level is 1", PowerMath.ringLevel(0 / 0, ring) == 1)
check("ring level capped", PowerMath.ringLevel(99, ring) == 10)
check("stat multiplier at level 1", PowerMath.ringStatMultiplier(1, ring) == 1)
check("stat multiplier at level 6", math.abs(PowerMath.ringStatMultiplier(6, ring) - 1.6) < 1e-9)
check("stat multiplier capped", math.abs(PowerMath.ringStatMultiplier(50, ring) - 2.08) < 1e-9)
check("skill bonus at level 1", PowerMath.skillDamagePct(1, ring) == 0)
check("skill bonus at level 10", PowerMath.skillDamagePct(10, ring) == 72)

-- цена
local e1, g1 = PowerMath.upgradeCost(1, 1, ring)
check("common L1->2 costs 8 essence 50 gold", e1 == 8 and g1 == 50)
local e5, g5 = PowerMath.upgradeCost(5, 1, ring)
check("epic L1->2 costs 40/250", e5 == 40 and g5 == 250)
local e5b = PowerMath.upgradeCost(5, 2, ring)
check("epic L2->3 costs 60 essence", e5b == 60)
local prevE, prevG = 0, 0
for l = 1, 9 do
	local e, g = PowerMath.upgradeCost(2.5, l, ring)
	check("cost grows at level " .. l, e ~= nil and g ~= nil and e > prevE and g > prevG)
	prevE, prevG = e, g
end
local eMax, gMax = PowerMath.upgradeCost(5, 10, ring)
check("no upgrade at max level", eMax == nil and gMax == nil)
check("higher quality costs more", PowerMath.upgradeCost(12, 3, ring) > PowerMath.upgradeCost(2.5, 3, ring))
check("garbage level is treated as 1", PowerMath.upgradeCost(1, -4, ring) == 8)
