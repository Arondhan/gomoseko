-- Проверки WaveMath вне Roblox. Запуск из корня репозитория: luau tools/tests/wave_math_test.luau
local WaveMath = require("../../src/shared/Rift/WaveMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local scaling = {
	CountBase = 4, CountPerWave = 1.0, HealthPerWave = 0.12, DamagePerWave = 0.08,
	CountPerExtraPlayer = 0.5, HealthPerExtraPlayer = 0.5, BossEvery = 10, ChestEvery = 5,
	RunnerFromWave = 3, RunnerShare = 0.25, BruteFromWave = 6, BruteShare = 0.15, BossMinionShare = 0.5,
}
local rewards = { CrystalsBase = 5, CrystalsPerWave = 2, EssenceBase = 1, EssencePerWave = 1, FreeloaderMultiplier = 0.5 }

-- босс и сундуки
check("wave 10 is boss", WaveMath.isBossWave(10, scaling))
check("wave 20 is boss", WaveMath.isBossWave(20, scaling))
check("wave 9 is not boss", not WaveMath.isBossWave(9, scaling))
check("wave 0 is not boss", not WaveMath.isBossWave(0, scaling))
check("wave 5 is chest", WaveMath.isChestWave(5, scaling))
check("wave 10 is chest too", WaveMath.isChestWave(10, scaling))
check("wave 7 is not chest", not WaveMath.isChestWave(7, scaling))

-- состав
local w1 = WaveMath.composition(1, 1, scaling)
check("wave 1: only grunts", w1.Grunt == 4 and w1.Runner == 0 and w1.Brute == 0 and w1.Boss == 0)
local w3 = WaveMath.composition(3, 1, scaling)
check("wave 3: runners appear", w3.Runner >= 1 and w3.Brute == 0)
local w6 = WaveMath.composition(6, 1, scaling)
check("wave 6: brutes appear", w6.Brute >= 1)
local w10 = WaveMath.composition(10, 1, scaling)
check("wave 10: exactly one boss", w10.Boss == 1)
check("wave 10 has minions", WaveMath.totalEnemies(w10) > 1)

-- сумма типов = всего, ничего не теряется
for wave = 1, 60 do
	for players = 1, 4 do
		local c = WaveMath.composition(wave, players, scaling)
		check(("composition parts are non-negative w%d p%d"):format(wave, players), c.Grunt >= 0 and c.Runner >= 0 and c.Brute >= 0 and c.Boss >= 0 and WaveMath.totalEnemies(c) >= 1)
	end
end

-- рост со временем (без босс-волн)
local function normal(wave) return WaveMath.totalEnemies(WaveMath.composition(wave, 1, scaling)) end
check("more enemies on wave 8 than wave 2", normal(8) > normal(2))
check("co-op has more enemies", WaveMath.totalEnemies(WaveMath.composition(5, 3, scaling)) > normal(5))

-- масштаб
check("health x1 on wave 1", WaveMath.healthMultiplier(1, 1, scaling) == 1)
check("health grows per wave", WaveMath.healthMultiplier(11, 1, scaling) > WaveMath.healthMultiplier(2, 1, scaling))
check("health grows per extra player", math.abs(WaveMath.healthMultiplier(1, 3, scaling) - 2) < 1e-9)
check("damage x1 on wave 1", WaveMath.damageMultiplier(1, scaling) == 1)
check("damage ignores players and grows per wave", math.abs(WaveMath.damageMultiplier(11, scaling) - 1.8) < 1e-9)

-- награды
local c1, e1 = WaveMath.waveReward(1, 1, 1, rewards)
check("wave 1 solo reward", c1 == 5 and e1 == 1)
local c10, e10 = WaveMath.waveReward(10, 1, 1, rewards)
check("wave 10 solo reward grows", c10 == 23 and e10 == 10)
local cFree = WaveMath.waveReward(10, 0, 2, rewards)
check("freeloader gets half", cFree == 11)
local cFair = WaveMath.waveReward(10, 0.5, 2, rewards)
check("fair share gets full reward", cFair == 23)
local cDouble = WaveMath.waveReward(10, 0.9, 2, rewards)
check("more than fair does not exceed full", cDouble == 23)
