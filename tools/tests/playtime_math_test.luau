-- Проверки PlaytimeMath вне Roblox. Запуск из корня репозитория: luau tools/tests/playtime_math_test.luau
local PlaytimeMath = require("../../src/shared/Gacha/PlaytimeMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local cfg = { StepSeconds = 600, StepPercent = 10, MaxPercent = 100 }

local at0 = PlaytimeMath.info(0, cfg)
check("no bonus at join", at0.steps == 0 and at0.percent == 0 and at0.bonus == 0)
check("first step in 600s", at0.nextIn == 600)
check("negative elapsed treated as 0", PlaytimeMath.info(-50, cfg).steps == 0)

local at599 = PlaytimeMath.info(599, cfg)
check("no step at 599s", at599.steps == 0 and at599.nextIn == 1)

local at600 = PlaytimeMath.info(600, cfg)
check("step at 600s", at600.steps == 1 and at600.percent == 10 and at600.bonus == 0.1)
check("next step counts from boundary", at600.nextIn == 600)

local at1250 = PlaytimeMath.info(1250, cfg)
check("two steps at 1250s => +0.2x", at1250.steps == 2 and at1250.bonus == 0.2)
check("nextIn at 1250s = 550", at1250.nextIn == 550)

local at6000 = PlaytimeMath.info(6000, cfg)
check("cap reached at 100 minutes", at6000.percent == 100 and at6000.bonus == 1 and at6000.capped)
check("no nextIn at cap", at6000.nextIn == nil)

local atLong = PlaytimeMath.info(100000, cfg)
check("stays capped", atLong.percent == 100 and atLong.steps > 10)
check("one step before cap not capped", PlaytimeMath.info(5400, cfg).capped == false)
