-- Проверки ChestMath вне Roblox. Запуск из корня репозитория: luau tools/tests/chest_math_test.luau
local ChestMath = require("../../src/shared/Rift/ChestMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local normal = {
	{ Id = "crystals", Label = "c", Weight = 60 },
	{ Id = "essence", Label = "e", Weight = 30 },
	{ Id = "ring", Label = "r", Weight = 10 },
}
local function sum(list) local s = 0 for _, v in list do s += v end return s end

local t = ChestMath.tenths(normal)
check("tenths sum to exactly 1000", sum(t) == 1000)
check("60/30/10 -> 600/300/100", t[1] == 600 and t[2] == 300 and t[3] == 100)
check("format", ChestMath.formatTenths(600) == "60.0%" and ChestMath.formatTenths(75) == "7.5%")

-- неровные веса всё равно дают ровно 1000
local odd = { { Id = "a", Label = "", Weight = 1 }, { Id = "b", Label = "", Weight = 1 }, { Id = "c", Label = "", Weight = 1 } }
local to = ChestMath.tenths(odd)
check("1/1/1 sums to 1000", sum(to) == 1000)
check("1/1/1 differs by at most 1", math.max(to[1], to[2], to[3]) - math.min(to[1], to[2], to[3]) <= 1)
for n = 1, 12 do
	local list = {}
	for i = 1, n do list[i] = { Id = tostring(i), Label = "", Weight = i * 7 + 3 } end
	check("random weights n=" .. n .. " sum 1000", sum(ChestMath.tenths(list)) == 1000)
end
check("zero weights safe", sum(ChestMath.tenths({ { Id = "a", Label = "", Weight = 0 } })) == 0)

-- выбор по числу
check("0.0 picks first", ChestMath.pick(normal, 0).Id == "crystals")
check("0.59 picks first", ChestMath.pick(normal, 0.59).Id == "crystals")
check("0.60 picks second", ChestMath.pick(normal, 0.60).Id == "essence")
check("0.89 picks second", ChestMath.pick(normal, 0.89).Id == "essence")
check("0.90 picks third", ChestMath.pick(normal, 0.90).Id == "ring")
check("0.9999 picks third", ChestMath.pick(normal, 0.9999).Id == "ring")
check("1.0 clamps to last", ChestMath.pick(normal, 1.0).Id == "ring")

-- частоты совпадают с долями на большой выборке (детерминированная сетка)
local counts = { crystals = 0, essence = 0, ring = 0 }
local N = 10000
for i = 0, N - 1 do
	local o = ChestMath.pick(normal, i / N)
	counts[o.Id] += 1
end
check("grid frequencies match weights", counts.crystals == 6000 and counts.essence == 3000 and counts.ring == 1000)

-- масштаб наград по волне
check("scale wave 1 unchanged", ChestMath.scaled(40, 1, 0.05) == 40)
check("scale wave 5 +20%", ChestMath.scaled(40, 5, 0.05) == 48)
check("scale nil is zero", ChestMath.scaled(nil, 5, 0.05) == 0)
