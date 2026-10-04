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
require(Services:WaitForChild("PlaytimeLuckService")).start() -- AFK-удача за время на сервере
require(Services:WaitForChild("LuckEventService")).start() -- Lucky Hour
require(Services:WaitForChild("GachaService")).start()
require(Services:WaitForChild("IndexService")).start() -- книга колец
require(Services:WaitForChild("OverheadTitleService")).start() -- титул над головой
require(Services:WaitForChild("DpsService")).start() -- DPS-арена и лидерборды
require(Services:WaitForChild("CombatService")).start()
require(Services:WaitForChild("RiftBoardService")).start() -- недельный лидерборд Rift
require(Services:WaitForChild("RiftService")).start() -- Rift: волны врагов в отдельной арене
require(Services:WaitForChild("AdminService")).start() -- админ-меню (только для админов, проверка на сервере)
