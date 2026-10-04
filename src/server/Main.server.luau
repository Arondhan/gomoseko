--!strict
-- Бутстрап серверных сервисов боя: создаёт ремоуты и запускает сервисы.
-- Карта и манекены живут в отдельных скриптах (BuildHub, Dummies).

local Services = script.Parent:WaitForChild("Services")
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

Remotes.init() -- ремоуты должны существовать до старта сервисов

require(Services:WaitForChild("PlayerStatsService")).start()
require(Services:WaitForChild("InventoryService")).start()
require(Services:WaitForChild("CombatService")).start()
