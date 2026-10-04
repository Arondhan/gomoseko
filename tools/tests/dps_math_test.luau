-- Проверки DpsMath вне Roblox. Запуск из корня репозитория: luau tools/tests/dps_math_test.luau
local DpsMath = require("../../src/shared/Dps/DpsMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

-- счёт и формат
check("score 4630/30 = 154.3 dps", DpsMath.score(4630, 30) == 1543)
check("format 1543 -> 154.3", DpsMath.format(1543) == "154.3")
check("score zero duration safe", DpsMath.score(100, 0) == 0)
check("score rounds", DpsMath.score(100, 30) == 33)

-- дни и недели (UTC)
check("epoch day 0", DpsMath.dayId(0) == 0)
check("day boundary", DpsMath.dayId(86399) == 0 and DpsMath.dayId(86400) == 1)
-- 1970-01-05 00:00 UTC (понедельник) = день 4 -> начало недели 1; 1970-01-04 (воскресенье) ещё неделя 0
check("sunday before first monday", DpsMath.weekId(3 * 86400 + 100) == 0)
check("first monday starts week 1", DpsMath.weekId(4 * 86400) == 1)
check("sunday ends week 1", DpsMath.weekId(10 * 86400 + 86399) == 1)
check("next monday starts week 2", DpsMath.weekId(11 * 86400) == 2)
-- 2024-01-01 00:00 UTC — понедельник (1704067200): неделя меняется ровно в этот момент
check("2024-01-01 monday boundary", DpsMath.weekId(1704067200) == DpsMath.weekId(1704067200 - 1) + 1)
check("secondsToDayEnd at midnight", DpsMath.secondsToDayEnd(86400) == 86400)
check("secondsToDayEnd 1s before", DpsMath.secondsToDayEnd(86399) == 1)
check("secondsToWeekEnd at monday 00:00", DpsMath.secondsToWeekEnd(1704067200) == 7 * 86400)
check("secondsToWeekEnd 1s before", DpsMath.secondsToWeekEnd(1704067200 - 1) == 1)

-- награды
local tiers = { { MaxRank = 1, Crystals = 500 }, { MaxRank = 3, Crystals = 300 }, { MaxRank = 10, Crystals = 150 }, { MaxRank = 50, Crystals = 50 } }
check("rank 1", DpsMath.rewardForRank(1, tiers) == 500)
check("rank 2", DpsMath.rewardForRank(2, tiers) == 300)
check("rank 3", DpsMath.rewardForRank(3, tiers) == 300)
check("rank 10", DpsMath.rewardForRank(10, tiers) == 150)
check("rank 11", DpsMath.rewardForRank(11, tiers) == 50)
check("rank 50", DpsMath.rewardForRank(50, tiers) == 50)
check("rank 51 gets nothing", DpsMath.rewardForRank(51, tiers) == 0)
check("rank 0 invalid", DpsMath.rewardForRank(0, tiers) == 0)
