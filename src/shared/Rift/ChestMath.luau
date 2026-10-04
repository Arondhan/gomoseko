--!strict
-- Чистая математика сундуков Rift (без Roblox API — проверяется в CLI): проценты исходов (сумма ровно 100 %)
-- и выбор исхода по числу из [0, 1). Одни и те же проценты показываются игроку в окне Rift и используются сервером.

local ChestMath = {}

export type Outcome = {
	Id: string,
	Label: string,
	Weight: number,
	Crystals: number?,
	Essence: number?,
	Ring: boolean?,
}

function ChestMath.totalWeight(outcomes: { Outcome }): number
	local total = 0
	for _, outcome in outcomes do
		total += outcome.Weight
	end
	return total
end

-- Доли исходов в десятых долях процента (целые, сумма ровно 1000): метод наибольших остатков
function ChestMath.tenths(outcomes: { Outcome }): { number }
	local total = ChestMath.totalWeight(outcomes)
	local result: { number } = {}
	if total <= 0 then
		for i = 1, #outcomes do
			result[i] = 0
		end
		return result
	end
	local fractions: { { index: number, fraction: number } } = {}
	local assigned = 0
	for i, outcome in outcomes do
		local exact = outcome.Weight / total * 1000
		local whole = math.floor(exact)
		result[i] = whole
		assigned += whole
		table.insert(fractions, { index = i, fraction = exact - whole })
	end
	table.sort(fractions, function(a, b)
		if a.fraction ~= b.fraction then
			return a.fraction > b.fraction
		end
		return a.index < b.index
	end)
	for k = 1, 1000 - assigned do
		local entry = fractions[k]
		result[entry.index] += 1
	end
	return result
end

-- «60.0%» для показа
function ChestMath.formatTenths(tenths: number): string
	return string.format("%d.%d%%", tenths // 10, tenths % 10)
end

-- Выбор исхода: value в [0, 1)
function ChestMath.pick(outcomes: { Outcome }, value: number): Outcome
	local total = ChestMath.totalWeight(outcomes)
	local target = math.clamp(value, 0, 0.999999999) * total
	local running = 0
	for _, outcome in outcomes do
		running += outcome.Weight
		if target < running then
			return outcome
		end
	end
	return outcomes[#outcomes]
end

-- Сколько Crystals/Essence в награде на волне wave (рост WaveScale за волну сверх первой)
function ChestMath.scaled(base: number?, wave: number, waveScale: number): number
	if not base or base <= 0 then
		return 0
	end
	return math.floor(base * (1 + waveScale * math.max(0, wave - 1)) + 0.5)
end

return ChestMath
