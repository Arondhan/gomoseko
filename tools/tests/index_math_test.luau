-- Проверки IndexMath вне Roblox. Запуск из корня репозитория: luau tools/tests/index_math_test.luau
local IndexMath = require("../../src/shared/Gacha/IndexMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

check("percent 0 of 18", IndexMath.percent(0, 18) == 0)
check("percent 9 of 18 = 50", IndexMath.percent(9, 18) == 50)
check("percent full", IndexMath.percent(18, 18) == 100)
check("percent clamps above total", IndexMath.percent(20, 18) == 100)
check("percent empty pool safe", IndexMath.percent(0, 0) == 0)

-- 18 колец: 25% = 4.5 -> 5 колец; 50% = 9; 100% = 18
check("rings needed 25% of 18 = 5", IndexMath.ringsNeeded(18, 25) == 5)
check("rings needed 50% of 18 = 9", IndexMath.ringsNeeded(18, 50) == 9)
check("rings needed 100% of 18 = 18", IndexMath.ringsNeeded(18, 100) == 18)
check("rings needed 25% of 20 = 5 exactly", IndexMath.ringsNeeded(20, 25) == 5)

check("4 of 18 does not reach 25%", not IndexMath.reached(4, 18, 25))
check("5 of 18 reaches 25%", IndexMath.reached(5, 18, 25))
check("8 of 18 does not reach 50%", not IndexMath.reached(8, 18, 50))
check("9 of 18 reaches 50%", IndexMath.reached(9, 18, 50))
check("17 of 18 does not reach 100%", not IndexMath.reached(17, 18, 100))
check("18 of 18 reaches 100%", IndexMath.reached(18, 18, 100))
check("empty pool never reaches", not IndexMath.reached(0, 0, 25))
