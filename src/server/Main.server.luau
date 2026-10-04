--!strict
-- Бутстрап серверных сервисов: создаёт ремоуты и запускает сервисы (порядок важен: профили → валюты → бонусы → остальное).
-- Карта и манекены живут в отдельных скриптах (BuildHub, Dummies).

local Services = script.Parent:WaitForChild("Services")
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes"))

Remotes.init() -- ремоуты должны существовать до старта сервисов

require(Services:WaitForChild("DataService")).start() -- профили игроков (DataStore)
require(Services:WaitForChild("CurrencyService")).start()
require(Services:WaitForChild("OnboardingService")).start() -- обучение новых игроков
require(Services:WaitForChild("SettingsService")).start() -- громкость и качество графики
require(Services:WaitForChild("StatsService")).start() -- бонусы колец
require(Services:WaitForChild("PlayerStatsService")).start() -- мана, уровень, опыт
require(Services:WaitForChild("InventoryService")).start()
require(Services:WaitForChild("MonetizationService")).start() -- Robux-покупки и политика регионов
require(Services:WaitForChild("GachaService")).start()
require(Services:WaitForChild("DpsService")).start() -- DPS-арена и лидерборды
require(Services:WaitForChild("CombatService")).start()
