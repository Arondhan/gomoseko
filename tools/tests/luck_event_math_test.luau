-- Проверки LuckEventMath вне Roblox. Запуск из корня репозитория: luau tools/tests/luck_event_math_test.luau
local LuckEventMath = require("../../src/shared/Gacha/LuckEventMath")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local cfg = { Period = 1800, Duration = 300 }

local start = LuckEventMath.status(3600, cfg)
check("window starts at multiple of period", start.active and start.endsIn == 300 and start.startsIn == 0)
check("endsAt = now + endsIn", start.endsAt == 3900)

local mid = LuckEventMath.status(3600 + 120, cfg)
check("mid-window", mid.active and mid.endsIn == 180)

local lastSecond = LuckEventMath.status(3600 + 299, cfg)
check("last second active", lastSecond.active and lastSecond.endsIn == 1)

local after = LuckEventMath.status(3600 + 300, cfg)
check("inactive right after window", not after.active and after.startsIn == 1500 and after.endsAt == 0)

local before = LuckEventMath.status(3600 + 1799, cfg)
check("one second before next window", not before.active and before.startsIn == 1)

check("epoch 0 is in a window", LuckEventMath.status(0, cfg).active)
check("consistent across servers (pure function)", LuckEventMath.status(123456789, cfg).active == LuckEventMath.status(123456789, cfg).active)
