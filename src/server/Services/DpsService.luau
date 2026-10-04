--!strict
-- DPS-арена: тренировочные манекены не умирают, игрок 30 секунд бьёт по ним, итог идёт в лидерборды
-- (дневной, недельный, всех времён) через OrderedDataStore — общие для всех серверов.
-- Счёт считает ТОЛЬКО сервер (CombatService сообщает нанесённый урон), клиент лишь показывает прогресс.
-- Если DataStore недоступен (Studio без API Services) — таблицы живут в памяти этого сервера.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DpsMath = require(Shared:WaitForChild("Dps"):WaitForChild("DpsMath"))
local DpsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DpsConfig"))

local Services = script.Parent
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))
local OnboardingService = require(Services:WaitForChild("OnboardingService"))
local PlayerStatsService = require(Services:WaitForChild("PlayerStatsService"))
local DpsBoard = require(script.Parent.Parent:WaitForChild("Hub"):WaitForChild("DpsBoard"))

local DpsService = {}

type Run = { startedAt: number, total: number, lastSent: number }

local PERIODS: { string } = { "daily", "weekly", "allTime" }
local PERIOD_TITLES: { [string]: string } = { daily = "Daily", weekly = "Weekly", allTime = "All time" }

local runs: { [Player]: Run } = {}
local statusRemote: RemoteEvent
local boards: Types.DpsBoards = { daily = {}, weekly = {}, allTime = {} }
local boardsSource = "memory"
local boardsUpdated = 0
local nameCache: { [number]: string } = {}
-- запасные таблицы в памяти (если DataStore недоступен): memory[period][userId] = score
local memory: { [string]: { [number]: number } } = { daily = {}, weekly = {}, allTime = {} }
local memoryDay = 0
local memoryWeek = 0

---------------------------------------------------------------------------
-- OrderedDataStore
---------------------------------------------------------------------------
local function storeName(period: string, now: number): string
	if period == "daily" then
		return "DpsDaily_" .. DpsMath.dayId(now)
	elseif period == "weekly" then
		return "DpsWeekly_" .. DpsMath.weekId(now)
	end
	return "DpsAllTime"
end

local function getStore(name: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then store else nil
end

-- Запись лучшего результата (только если он лучше сохранённого)
local function submit(userId: number, score: number)
	local now = os.time()
	-- память: на случай недоступного DataStore (и для быстрого отклика)
	if DpsMath.dayId(now) ~= memoryDay then
		memory.daily = {}
		memoryDay = DpsMath.dayId(now)
	end
	if DpsMath.weekId(now) ~= memoryWeek then
		memory.weekly = {}
		memoryWeek = DpsMath.weekId(now)
	end
	for _, period in PERIODS do
		memory[period][userId] = math.max(memory[period][userId] or 0, score)
	end

	for _, period in PERIODS do
		task.spawn(function()
			local store = getStore(storeName(period, now))
			if not store then
				return
			end
			for attempt = 1, 3 do
				local ok = pcall(function()
					store:UpdateAsync(tostring(userId), function(old: any): any
						if type(old) == "number" and old >= score then
							return nil -- уже есть результат не хуже
						end
						return score
					end)
				end)
				if ok then
					return
				end
				task.wait(2 ^ attempt)
			end
		end)
	end
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

local function fromMemory(period: string): { Types.DpsEntry }
	local list: { { userId: number, score: number } } = {}
	for userId, score in memory[period] do
		table.insert(list, { userId = userId, score = score })
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	local entries: { Types.DpsEntry } = {}
	for rank, item in list do
		if rank > DpsConfig.LeaderboardSize then
			break
		end
		table.insert(
			entries,
			{ rank = rank, userId = item.userId, name = resolveName(item.userId), score = item.score }
		)
	end
	return entries
end

-- Топ периода из DataStore (nil — не удалось)
local function fetchTop(period: string, now: number): { Types.DpsEntry }?
	local store = getStore(storeName(period, now))
	if not store then
		return nil
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, DpsConfig.LeaderboardSize):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return nil
	end
	local entries: { Types.DpsEntry } = {}
	for rank, item in page do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { rank = rank, userId = userId, name = resolveName(userId), score = item.value })
		end
	end
	return entries
end

local function refreshBoards()
	local now = os.time()
	local allOk = true
	local fresh: Types.DpsBoards = { daily = {}, weekly = {}, allTime = {} }
	for _, period in PERIODS do
		local entries = fetchTop(period, now)
		if entries then
			(fresh :: any)[period] = entries
		else
			allOk = false;
			(fresh :: any)[period] = fromMemory(period)
		end
	end
	boards = fresh
	boardsSource = if allOk then "datastore" else "memory"
	boardsUpdated = now
end

---------------------------------------------------------------------------
-- Замер
---------------------------------------------------------------------------
local function rollPeriods(profile: DataService.Profile, now: number)
	local dps = profile.Dps
	if dps.DayId ~= DpsMath.dayId(now) then
		dps.DayId = DpsMath.dayId(now)
		dps.DayBest = 0
	end
	if dps.WeekId ~= DpsMath.weekId(now) then
		dps.WeekId = DpsMath.weekId(now)
		dps.WeekBest = 0
	end
end

local function bestOf(profile: DataService.Profile): Types.DpsBest
	return { daily = profile.Dps.DayBest, weekly = profile.Dps.WeekBest, allTime = profile.Dps.Best }
end

local function finishRun(player: Player, run: Run)
	runs[player] = nil
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	rollPeriods(profile, now)

	local duration = DpsConfig.TestDuration
	local score = DpsMath.score(run.total, duration)
	local dps = profile.Dps
	local newBest = score > dps.DayBest
	dps.DayBest = math.max(dps.DayBest, score)
	dps.WeekBest = math.max(dps.WeekBest, score)
	dps.Best = math.max(dps.Best, score)
	submit(player.UserId, score)

	-- награды за замер
	local rewards = DpsConfig.TestRewards
	local gold = math.floor(run.total / 100) * rewards.GoldPer100Damage
	local crystals = rewards.Crystals
	if dps.LastRewardDay ~= dps.DayId then
		dps.LastRewardDay = dps.DayId
		crystals += rewards.FirstOfDayCrystals
	end
	CurrencyService.add(player, "Gold", gold, "Gameplay", "dps_test")
	CurrencyService.add(player, "Crystals", crystals, "Gameplay", "dps_test")
	PlayerStatsService.addXp(player, rewards.Xp)
	OnboardingService.notify(player, "DpsTest")

	local status: Types.DpsStatus = {
		kind = "Finished",
		duration = duration,
		total = run.total,
		dps = score,
		best = bestOf(profile),
		newBest = newBest,
		xp = rewards.Xp,
		gold = gold,
		crystals = crystals,
	}
	statusRemote:FireClient(player, status)
end

-- Игрок нанёс урон по манекену (вызывает CombatService). Первый удар запускает 30-секундный замер.
function DpsService.recordHit(player: Player, damage: number)
	local now = os.clock()
	local run = runs[player]
	if not run then
		run = { startedAt = now, total = 0, lastSent = 0 }
		runs[player] = run
	end
	run.total += damage
end

---------------------------------------------------------------------------
-- Недельная награда по месту в прошлой неделе (при входе)
---------------------------------------------------------------------------
local function claimWeeklyReward(player: Player, profile: DataService.Profile)
	local lastWeek = DpsMath.weekId(os.time()) - 1
	if profile.Dps.LastWeekClaimed >= lastWeek or not DataService.isPersistent(player) then
		return
	end
	local store = getStore("DpsWeekly_" .. lastWeek)
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, DpsConfig.LeaderboardSize):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return -- не получилось: попробуем при следующем входе
	end
	profile.Dps.LastWeekClaimed = lastWeek
	for rank, item in page do
		if tonumber(item.key) == player.UserId then
			local crystals = DpsMath.rewardForRank(rank, DpsConfig.WeeklyRewards)
			if crystals > 0 then
				CurrencyService.add(player, "Crystals", crystals, "TimedReward", "dps_weekly")
				statusRemote:FireClient(
					player,
					{ kind = "WeeklyReward", rank = rank, crystals = crystals } :: Types.DpsStatus
				)
			end
			return
		end
	end
end

---------------------------------------------------------------------------
-- Запуск
---------------------------------------------------------------------------
local function getBoards(player: Player): Types.DpsBoardsResponse
	local profile = DataService.get(player)
	local best: Types.DpsBest = { daily = 0, weekly = 0, allTime = 0 }
	if profile then
		rollPeriods(profile, os.time())
		best = bestOf(profile)
	end
	local now = os.time()
	return {
		boards = boards,
		best = best,
		source = boardsSource,
		updated = boardsUpdated,
		dayEndsIn = DpsMath.secondsToDayEnd(now),
		weekEndsIn = DpsMath.secondsToWeekEnd(now),
	}
end

function DpsService.start()
	statusRemote = Remotes.get("DpsStatus") :: RemoteEvent;
	(Remotes.get("DpsGetBoards") :: RemoteFunction).OnServerInvoke = getBoards

	DataService.onLoaded(function(player, profile)
		task.spawn(claimWeeklyReward, player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
	end)

	-- ход замеров: рассылаем прогресс и завершаем по истечении времени
	task.spawn(function()
		while true do
			local now = os.clock()
			for player, run in runs do
				local elapsed = now - run.startedAt
				if elapsed >= DpsConfig.TestDuration then
					finishRun(player, run)
				elseif now - run.lastSent >= DpsConfig.StatusInterval then
					run.lastSent = now
					local status: Types.DpsStatus = {
						kind = "Running",
						elapsed = elapsed,
						duration = DpsConfig.TestDuration,
						total = run.total,
						dps = DpsMath.score(run.total, math.max(elapsed, 1)),
					}
					statusRemote:FireClient(player, status)
				end
			end
			task.wait(0.1)
		end
	end)

	-- таблицы лидеров и физическая доска в хабе
	task.spawn(function()
		while not Workspace:GetAttribute("HubReady") do
			Workspace:GetAttributeChangedSignal("HubReady"):Wait()
		end
		local model = Workspace:FindFirstChild("MainHub") and Workspace.MainHub:FindFirstChild("DpsBoard")
		local shown = 0
		local lastRefresh = 0
		while true do
			if os.clock() - lastRefresh >= DpsConfig.RefreshSeconds then
				lastRefresh = os.clock()
				refreshBoards()
			end
			if model and model:IsA("Model") then
				local period = PERIODS[shown % #PERIODS + 1]
				DpsBoard.render(
					model,
					PERIOD_TITLES[period],
					(boards :: any)[period],
					if boardsSource == "memory" then "this server" else nil
				)
				shown += 1
			end
			task.wait(DpsConfig.BoardCycleSeconds)
		end
	end)
end

return DpsService
