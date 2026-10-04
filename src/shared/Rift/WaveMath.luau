--!strict
-- Чистая математика Rift (без Roblox API — проверяется в CLI): состав волны, масштаб HP/урона, награды.
-- Используется server/Services/RiftService.

local WaveMath = {}

export type Scaling = {
	CountBase: number,
	CountPerWave: number,
	HealthPerWave: number,
	DamagePerWave: number,
	CountPerExtraPlayer: number,
	HealthPerExtraPlayer: number,
	BossEvery: number,
	ChestEvery: number,
	RunnerFromWave: number,
	RunnerShare: number,
	BruteFromWave: number,
	BruteShare: number,
	BossMinionShare: number,
}

export type Rewards = {
	CrystalsBase: number,
	CrystalsPerWave: number,
	EssenceBase: number,
	EssencePerWave: number,
	FreeloaderMultiplier: number,
}

export type Composition = { Grunt: number, Runner: number, Brute: number, Boss: number }

function WaveMath.isBossWave(wave: number, scaling: Scaling): boolean
	return wave > 0 and wave % scaling.BossEvery == 0
end

function WaveMath.isChestWave(wave: number, scaling: Scaling): boolean
	return wave > 0 and wave % scaling.ChestEvery == 0
end

-- Сколько обычных врагов в волне (без босса) для данного числа игроков
local function baseCount(wave: number, players: number, scaling: Scaling): number
	local perWave = scaling.CountBase + scaling.CountPerWave * (wave - 1)
	local extra = 1 + scaling.CountPerExtraPlayer * math.max(0, players - 1)
	return math.max(1, math.floor(perWave * extra + 0.5))
end

-- Состав волны по типам врагов. Босс-волна: 1 Boss + доля обычного состава.
function WaveMath.composition(wave: number, players: number, scaling: Scaling): Composition
	local total = baseCount(wave, players, scaling)
	local boss = 0
	if WaveMath.isBossWave(wave, scaling) then
		boss = 1
		total = math.max(2, math.floor(total * scaling.BossMinionShare + 0.5))
	end
	local brute = if wave >= scaling.BruteFromWave then math.floor(total * scaling.BruteShare) else 0
	local runner = if wave >= scaling.RunnerFromWave then math.floor(total * scaling.RunnerShare) else 0
	local grunt = total - brute - runner
	return { Grunt = grunt, Runner = runner, Brute = brute, Boss = boss }
end

function WaveMath.totalEnemies(composition: Composition): number
	return composition.Grunt + composition.Runner + composition.Brute + composition.Boss
end

-- Множитель HP врагов: растёт с волной и с числом игроков
function WaveMath.healthMultiplier(wave: number, players: number, scaling: Scaling): number
	return (1 + scaling.HealthPerWave * (wave - 1)) * (1 + scaling.HealthPerExtraPlayer * math.max(0, players - 1))
end

-- Множитель урона врагов: только от волны (число игроков урон не меняет)
function WaveMath.damageMultiplier(wave: number, scaling: Scaling): number
	return 1 + scaling.DamagePerWave * (wave - 1)
end

-- Награда игроку за зачищенную волну. share — его доля урона в волне (0..1), players — игроков в арене.
-- Личный множитель: FreeloaderMultiplier (если не бил) .. 1 (если бил не меньше среднего).
function WaveMath.waveReward(wave: number, share: number, players: number, rewards: Rewards): (number, number)
	local fair = math.clamp(share * math.max(1, players), 0, 1)
	local multiplier = rewards.FreeloaderMultiplier + (1 - rewards.FreeloaderMultiplier) * fair
	local crystals = math.floor((rewards.CrystalsBase + rewards.CrystalsPerWave * (wave - 1)) * multiplier)
	local essence = math.floor((rewards.EssenceBase + rewards.EssencePerWave * (wave - 1)) * multiplier)
	return crystals, essence
end

return WaveMath
