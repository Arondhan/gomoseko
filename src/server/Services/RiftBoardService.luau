--!strict
-- Недельный лидерборд Rift («лучшая волна недели») через OrderedDataStore, общий для всех серверов, и недельная
-- награда по месту прошлой недели (выдаётся при входе, идемпотентно). Сервер сам решает, что отправлять.
-- Если DataStore недоступен (Studio без API Services) — таблица живёт в памяти этого сервера.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DpsMath = require(Shared:WaitForChild("Dps"):WaitForChild("DpsMath"))
local RiftConfig = require(Shared:WaitForChild("Configs"):WaitForChild("RiftConfig"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))

local RiftBoardService = {}

local board: { Types.RiftEntry } = {}
local source = "memory"
local nameCache: { [number]: string } = {}
local memory: { [number]: number } = {}
local memoryWeek = 0
local weeklyRemote: RemoteEvent

local function storeName(weekId: number): string
	return "RiftWeekly_" .. weekId
end

local function getStore(weekId: number): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName(weekId))
	end)
	return if ok then store else nil
end

local function resolveName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok and type(name) == "string" then name else "Player " .. userId
	return nameCache[userId]
end

-- Записать лучшую волну недели (только если лучше сохранённой)
function RiftBoardService.submit(userId: number, wave: number)
	local now = os.time()
	local weekId = DpsMath.weekId(now)
	if memoryWeek ~= weekId then
		memory = {}
		memoryWeek = weekId
	end
	memory[userId] = math.max(memory[userId] or 0, wave)

	task.spawn(function()
		local store = getStore(weekId)
		if not store then
			return
		end
		for attempt = 1, 3 do
			local ok = pcall(function()
				store:UpdateAsync(tostring(userId), function(old: any): any
					if type(old) == "number" and old >= wave then
						return nil
					end
					return wave
				end)
			end)
			if ok then
				return
			end
			task.wait(2 ^ attempt)
		end
	end)
end

local function fromMemory(): { Types.RiftEntry }
	local list: { { userId: number, score: number } } = {}
	for userId, score in memory do
		table.insert(list, { userId = userId, score = score })
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	local entries: { Types.RiftEntry } = {}
	for rank, item in list do
		if rank > RiftConfig.LeaderboardSize then
			break
		end
		table.insert(
			entries,
			{ rank = rank, userId = item.userId, name = resolveName(item.userId), score = item.score }
		)
	end
	return entries
end

local function refresh()
	local store = getStore(DpsMath.weekId(os.time()))
	local ok, page = false, nil :: any
	if store then
		ok, page = pcall(function()
			return store:GetSortedAsync(false, RiftConfig.LeaderboardSize):GetCurrentPage()
		end)
	end
	if ok and type(page) == "table" then
		local entries: { Types.RiftEntry } = {}
		for rank, item in page do
			local userId = tonumber(item.key)
			if userId then
				table.insert(entries, { rank = rank, userId = userId, name = resolveName(userId), score = item.value })
			end
		end
		board = entries
		source = "datastore"
	else
		board = fromMemory()
		source = "memory"
	end
end

function RiftBoardService.top(limit: number): ({ Types.RiftEntry }, string)
	local entries: { Types.RiftEntry } = {}
	for i = 1, math.min(limit, #board) do
		entries[i] = board[i]
	end
	return entries, source
end

-- Недельная награда по месту в прошлой неделе (при входе; только для игроков с сохраняемым профилем)
local function claimWeeklyReward(player: Player, profile: DataService.Profile)
	local lastWeek = DpsMath.weekId(os.time()) - 1
	if profile.Rift.LastWeekClaimed >= lastWeek or not DataService.isPersistent(player) then
		return
	end
	local store = getStore(lastWeek)
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, RiftConfig.LeaderboardSize):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return -- не получилось: попробуем при следующем входе
	end
	profile.Rift.LastWeekClaimed = lastWeek
	for rank, item in page do
		if tonumber(item.key) == player.UserId then
			local crystals = DpsMath.rewardForRank(rank, RiftConfig.WeeklyRewards)
			if crystals > 0 then
				CurrencyService.add(player, "Crystals", crystals, "TimedReward", "rift_weekly")
				weeklyRemote:FireClient(player, { rank = rank, crystals = crystals } :: Types.RiftWeekly)
			end
			return
		end
	end
end

function RiftBoardService.start()
	weeklyRemote = Remotes.get("RiftWeekly") :: RemoteEvent
	DataService.onLoaded(function(player, profile)
		task.spawn(claimWeeklyReward, player, profile)
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(RiftConfig.RefreshSeconds)
		end
	end)
end

return RiftBoardService
