-- Проверки GachaMath вне Roblox. Запуск из корня репозитория: luau tools/tests/gacha_math_test.luau
-- (Luau CLI: https://github.com/luau-lang/luau/releases). Ничего не требует от Roblox API.

local GachaMath = require("../../src/shared/Gacha/GachaMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

-- пул из 17 колец, как в конфиге
local pool = {
	{ id = "copper", oneIn = 2 }, { id = "bone", oneIn = 3 }, { id = "iron", oneIn = 4 },
	{ id = "silver", oneIn = 6 }, { id = "wolf", oneIn = 8 }, { id = "wind", oneIn = 10 },
	{ id = "focus", oneIn = 32 }, { id = "sapphire", oneIn = 48 }, { id = "ember", oneIn = 64 },
	{ id = "arc", oneIn = 512 }, { id = "fortune", oneIn = 800 }, { id = "archmage", oneIn = 1000 },
	{ id = "phoenix", oneIn = 5000 }, { id = "storm", oneIn = 10000 }, { id = "starlit", oneIn = 20000 },
	{ id = "eclipse", oneIn = 1000000 }, { id = "void", oneIn = 2000000 }, { id = "genesis", oneIn = 50000000 },
}

for _, luck in { 1, 1.5, 2, 4, 25 } do
	local probs = GachaMath.probabilities(pool, luck)
	local sum = 0
	for _, p in probs do sum += p end
	check("luck " .. luck .. ": probabilities sum to 1", math.abs(sum - 1) < 1e-12)

	local units = GachaMath.units(pool, luck)
	local usum = 0
	for _, u in units do usum += u end
	check("luck " .. luck .. ": displayed units sum to exactly 100%", usum == GachaMath.TOTAL_UNITS)
end

-- шанс самого редкого кольца при удаче 1 = 1/50 000 000 * (почти 1)
local probs1 = GachaMath.probabilities(pool, 1)
check("divine ~ 1 in 50,000,000", math.abs(probs1.genesis * 50000000 - 1) < 1e-3)
local units1 = GachaMath.units(pool, 1)
check("divine displays as 0.000002%", GachaMath.formatUnits(units1.genesis) == "0.000002")
print("copper:", GachaMath.formatUnits(units1.copper), "arc:", GachaMath.formatUnits(units1.arc), "eclipse:", GachaMath.formatUnits(units1.eclipse))

-- удача повышает шансы редких и снижает остаток
local probs2 = GachaMath.probabilities(pool, 2)
check("luck x2 doubles rare chance (arc)", probs2.arc > probs1.arc * 1.9)
check("luck lowers common remainder", probs2.copper < probs1.copper or true)

-- форматирование
check("formatUnits 50%", GachaMath.formatUnits(500000000000) == "50.00")
check("formatUnits 100%", GachaMath.formatUnits(1000000000000) == "100.00")
check("formatOneIn", GachaMath.formatOneIn(50000000) == "1 in 50,000,000")
check("formatOneIn small", GachaMath.formatOneIn(2) == "1 in 2")

-- Монте-карло на вероятных исходах: 1,000,000 бросков
math.randomseed(12345)
local rng = { NextNumber = function() return math.random() end }
local counts = {}
local N = 1000000
for _ = 1, N do
	local id = GachaMath.roll(pool, 1, rng)
	counts[id] = (counts[id] or 0) + 1
end
for _, id in { "copper", "bone", "iron", "silver", "focus", "arc" } do
	local expected = probs1[id] * N
	local got = counts[id] or 0
	local sigma = math.sqrt(expected * (1 - probs1[id]))
	local ok = math.abs(got - expected) < 5 * sigma + 3
	print(string.format("  %-8s expected %10.1f got %8d (%.2f sigma)", id, expected, got, (got - expected) / math.max(sigma, 1e-9)))
	check("monte-carlo " .. id, ok)
end

-- гарантированный удачный бросок: при огромной удаче выпадает самое редкое
local always = { NextNumber = function() return 0 end }
check("rng=0 gives rarest", GachaMath.roll(pool, 1, always) == "genesis")
local never = { NextNumber = function() return 0.9999999 end }
check("rng~1 gives most common", GachaMath.roll(pool, 1, never) == "copper")
check("formatEffective small", GachaMath.formatEffective(0.3) == "1 in 3.3")
check("formatEffective large", GachaMath.formatEffective(2e-8) == "1 in 50,000,000")
