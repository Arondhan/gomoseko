-- Проверки AdminAccess вне Roblox. Запуск из корня репозитория: luau tools/tests/admin_access_test.luau
local AdminAccess = require("../../src/shared/AdminAccess")

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local config = { Enabled = true, AllowStudio = true, AllowOwner = true, UserIds = { 111, 222 } }

check("studio user allowed", AdminAccess.isAllowed(5, config, true, 999, true))
check("stranger in live game denied", not AdminAccess.isAllowed(5, config, false, 999, true))
check("owner allowed in live game", AdminAccess.isAllowed(999, config, false, 999, true))
check("group-owned place: creator id is not a user", not AdminAccess.isAllowed(999, config, false, 999, false))
check("listed user allowed", AdminAccess.isAllowed(222, config, false, 999, true))
check("disabled blocks everyone", not AdminAccess.isAllowed(222, { Enabled = false, AllowStudio = true, AllowOwner = true, UserIds = { 222 } }, true, 222, true))
check("studio switch off", not AdminAccess.isAllowed(5, { Enabled = true, AllowStudio = false, AllowOwner = true, UserIds = {} }, true, 999, true))
check("owner switch off", not AdminAccess.isAllowed(999, { Enabled = true, AllowStudio = false, AllowOwner = false, UserIds = {} }, false, 999, true))
check("creator id 0 never matches", not AdminAccess.isAllowed(0, config, false, 0, true))
