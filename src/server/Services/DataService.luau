--!strict
-- Сохранение данных игроков (DataStore) + доступ к профилю. Профиль — единый источник правды для валют,
-- колец, уровня, Gacha и квитанций покупок; остальные сервисы читают/пишут его через DataService.get().
--
-- Надёжность: мягкая блокировка сессии по JobId (два сервера не пишут один профиль), повторы загрузки, автосохранение,
-- сохранение при выходе и в BindToClose. Если DataStore недоступен (в Studio выключен «API Services») — работаем в
-- памяти с предупреждением (profile.persistent = false); тогда реальные Robux-покупки не подтверждаются.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GachaConfig"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))
local CombatConfig = require(Shared:WaitForChild("Configs"):WaitForChild("CombatConfig"))

local DataService = {}

local STORE_NAME = "PlayerData_v1"
local DATA_VERSION = 1
local LOCK_TIMEOUT = 120 -- сек: блокировку чужой сессии старше этого срока считаем протухшей
local LOAD_ATTEMPTS = 4
local AUTOSAVE_INTERVAL = 60

export type Profile = {
	Version: number,
	Currencies: { Gold: number, Crystals: number, Essence: number },
	Level: number,
	XP: number,
	Rings: { string }, -- уникальные кольца в инвентаре
	Equipped: { string }, -- по слотам 1..RingSlotCount, "" = пусто
	Gacha: { Rolls: number, LastFreeRoll: number, Recent: { { ringId: string, t: number } } },
	Boosts: { LuckPercent: number, LuckUntil: number },
	Receipts: { [string]: boolean },
	Onboarding: { Step: number, Done: boolean },
	Settings: { SfxVolume: number, LowQuality: boolean? },
	Session: { JobId: string, Time: number }?,
}

type Slot = {
	profile: Profile,
	persistent: boolean,
	saving: boolean,
	dirtyWhileSaving: boolean,
}

local store: DataStore? = nil
local slots: { [Player]: Slot } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

local function defaultEquipped(): { string }
	local equipped = {}
	for i = 1, CombatConfig.RingSlotCount do
		equipped[i] = ""
	end
	return equipped
end

local function defaults(): Profile
	return {
		Version = DATA_VERSION,
		Currencies = {
			Gold = GachaConfig.Starting.Gold,
			Crystals = GachaConfig.Starting.Crystals,
			Essence = 0,
		},
		Level = 1,
		XP = 0,
		Rings = table.clone(RingsConfig.StartingItems),
		Equipped = defaultEquipped(),
		Gacha = { Rolls = 0, LastFreeRoll = 0, Recent = {} },
		Boosts = { LuckPercent = 0, LuckUntil = 0 },
		Receipts = {},
		Onboarding = { Step = 1, Done = false },
		Settings = { SfxVolume = 1, LowQuality = nil },
		Session = nil,
	}
end

-- Дополняет загруженные данные недостающими полями из дефолтов (новые версии игры добавляют поля)
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" and #value == 0 then
			reconcile(target[key], value) -- словари вглубь; массивы не трогаем
		end
	end
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
	return store
end

local function key(player: Player): string
	return "Player_" .. player.UserId
end

-- Загрузка с блокировкой сессии. Возвращает (профиль, сохраняемый ли он).
local function load(player: Player): (Profile, boolean)
	local dataStore = getStore()
	if not dataStore then
		warn("[DataService] DataStore unavailable: data of player " .. player.Name .. " lives in memory only")
		return defaults(), false
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key(player), function(old: any)
				if type(old) == "table" and old.Session and old.Session.JobId ~= game.JobId then
					if os.time() - old.Session.Time < LOCK_TIMEOUT then
						lockedByOther = true
						return nil -- профиль занят другим сервером: отменяем запись
					end
				end
				local data: any = if type(old) == "table" then old else defaults()
				data.Session = { JobId = game.JobId, Time = os.time() }
				return data
			end)
		end)
		if ok and result ~= nil and not lockedByOther then
			reconcile(result, defaults())
			return result :: Profile, true
		end
		if ok and lockedByOther then
			warn(("[DataService] profile %s is locked by another server, attempt %d"):format(player.Name, attempt))
			task.wait(5)
		else
			warn(("[DataService] load error for %s (attempt %d): %s"):format(player.Name, attempt, tostring(result)))
			task.wait(2 ^ attempt)
		end
	end

	warn("[DataService] could not load profile of " .. player.Name .. ": using a temporary in-memory profile")
	return defaults(), false
end

-- Сохраняет профиль (release = true — снять блокировку сессии, при выходе). true — успех.
function DataService.save(player: Player, release: boolean?): boolean
	local slot = slots[player]
	local dataStore = getStore()
	if not slot or not slot.persistent or not dataStore then
		return false
	end
	if slot.saving then
		slot.dirtyWhileSaving = true
		return false
	end
	slot.saving = true
	local ok, err = pcall(function()
		dataStore:UpdateAsync(key(player), function(old: any)
			if type(old) == "table" and old.Session and old.Session.JobId ~= game.JobId then
				if os.time() - old.Session.Time < LOCK_TIMEOUT then
					return nil -- чужая сессия: не перезаписываем
				end
			end
			slot.profile.Session = if release then nil else { JobId = game.JobId, Time = os.time() }
			return slot.profile
		end)
	end)
	slot.saving = false
	if not ok then
		warn(("[DataService] save error for %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

-- Профиль игрока (nil, пока не загружен)
function DataService.get(player: Player): Profile?
	local slot = slots[player]
	return slot and slot.profile
end

-- true — данные реально сохраняются в DataStore (иначе только память)
function DataService.isPersistent(player: Player): boolean
	local slot = slots[player]
	return slot ~= nil and slot.persistent
end

-- Ждёт загрузки профиля (nil, если игрок вышел или истёк таймаут)
function DataService.waitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 60)
	while player.Parent and os.clock() < deadline do
		local profile = DataService.get(player)
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return DataService.get(player)
end

-- Вызывает callback для каждого уже загруженного профиля и для всех будущих
function DataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, slot in slots do
		task.spawn(callback, player, slot.profile)
	end
end

local function onPlayerAdded(player: Player)
	if slots[player] then
		return
	end
	local profile, persistent = load(player)
	if not player.Parent then
		-- игрок успел выйти, пока грузили: снимаем блокировку
		if persistent then
			slots[player] = { profile = profile, persistent = true, saving = false, dirtyWhileSaving = false }
			DataService.save(player, true)
			slots[player] = nil
		end
		return
	end
	slots[player] = { profile = profile, persistent = persistent, saving = false, dirtyWhileSaving = false }
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function onPlayerRemoving(player: Player)
	local slot = slots[player]
	if slot then
		DataService.save(player, true)
		slots[player] = nil
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- автосохранение
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in slots do
				task.spawn(DataService.save, player, false)
			end
		end
	end)

	-- сохранение при закрытии сервера (даём до 25 секунд)
	game:BindToClose(function()
		local pending = 0
		for player in slots do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	if RunService:IsStudio() then
		print(
			"[DataService] Studio: to persist data enable Game Settings > Security > Enable Studio Access to API Services"
		)
	end
end

return DataService
