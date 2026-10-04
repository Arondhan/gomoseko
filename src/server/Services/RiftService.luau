--!strict
-- Rift (сервер): бесконечные волны врагов в отдельной арене. Один общий забег на сервер, игроки заходят и выходят
-- (портал в храме, плитка в меню). Машина состояний: Idle -> Lobby -> Wave N -> Intermission -> ... -> Ending -> Idle.
-- Сервер решает всё: состав волн (shared/Rift/WaveMath), спавн и ИИ врагов (Hub/EnemyFactory, RiftEnemyAI),
-- урон по игрокам, награды (кристаллы/Essence за волну и за убийства) и рекорд. Клиент только показывает состояние.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))
local WaveMath = require(Shared:WaitForChild("Rift"):WaitForChild("WaveMath"))
local Configs = Shared:WaitForChild("Configs")
local RiftConfig = require(Configs:WaitForChild("RiftConfig"))
local RingsConfig = require(Configs:WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Services = script.Parent
local CombatService = require(Services:WaitForChild("CombatService"))
local CurrencyService = require(Services:WaitForChild("CurrencyService"))
local DataService = require(Services:WaitForChild("DataService"))
local RiftEnemyAI = require(Services:WaitForChild("RiftEnemyAI"))
local Hub = script.Parent.Parent:WaitForChild("Hub")
local EnemyFactory = require(Hub:WaitForChild("EnemyFactory"))
local RiftArena = require(Hub:WaitForChild("RiftArena"))

local RiftService = {}

type PlayerRun = {
	kills: number,
	totalDamage: number,
	waveDamage: number,
	crystals: number,
	essence: number,
	died: RBXScriptConnection?,
}

local STEP = 0.25
local phase = "Idle"
local wave = 0
local clearedWave = 0
local phaseEndsAt = 0
local enraged = false
local waveTotal = 0
local runToken = 0
local waveSerial = 0
local nextStartWave = 1
local skipLobby = false
local pendingJump: number? = nil
local queue: { string } = {}
local waveHealthMultiplier = 1
local waveDamageMultiplier = 1

local runs: { [Player]: PlayerRun } = {}
local aliveEnemies: { [Model]: boolean } = {}
local aliveCount = 0

local arena: RiftArena.Arena? = nil
local enemiesFolder: Folder
local stateRemote: RemoteEvent
local resultRemote: RemoteEvent
local rewardRemote: RemoteEvent

local rng = Random.new()

---------------------------------------------------------------------------
-- Состояние и вспомогательные функции
---------------------------------------------------------------------------

local function playerCount(): number
	local count = 0
	for _ in runs do
		count += 1
	end
	return count
end

local function makeState(): Types.RiftState
	local scaling = RiftConfig.Scaling
	return {
		phase = phase,
		wave = wave,
		enemiesLeft = aliveCount + #queue,
		enemiesTotal = waveTotal,
		countdown = math.max(0, math.ceil(phaseEndsAt - os.clock())),
		players = playerCount(),
		enraged = enraged,
		chestWave = WaveMath.isChestWave(wave, scaling),
		bossWave = WaveMath.isBossWave(wave, scaling),
	}
end

local function broadcast()
	if next(runs) == nil then
		return
	end
	local state = makeState()
	for player in runs do
		stateRemote:FireClient(player, state)
	end
end

-- Живые игроки арены для ИИ врагов
local function getTargets(): { RiftEnemyAI.Target }
	local list: { RiftEnemyAI.Target } = {}
	for player in runs do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(list, { player = player, humanoid = humanoid, root = root })
		end
	end
	return list
end

local function hubSpawn(): CFrame
	return CFrame.new(Config.SPAWN_POSITION + Vector3.new(0, 4, 0))
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
	end
end

local function hasSkillRing(player: Player): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	for _, ringId in profile.Equipped do
		local ring = RingsConfig.Rings[ringId]
		if ring and ring.SkillId then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Враги
---------------------------------------------------------------------------

local function onEnemyGone(model: Model)
	if aliveEnemies[model] then
		aliveEnemies[model] = nil
		aliveCount -= 1
	end
	RiftEnemyAI.unregister(model)
end

local function spawnEnemy(kind: string)
	local stats = RiftConfig.Enemies[kind]
	local current = arena
	if not stats or not current then
		return
	end
	local angle = rng:NextNumber() * math.pi * 2
	local radius = RiftConfig.Arena.SpawnRadius
	local position = current.center
		+ Vector3.new(math.cos(angle) * radius, 2 * stats.Size + 0.5, math.sin(angle) * radius)
	local model = EnemyFactory.create(kind, position, waveHealthMultiplier, waveDamageMultiplier, enemiesFolder)
	if not model then
		return
	end
	aliveEnemies[model] = true
	aliveCount += 1
	RiftEnemyAI.register(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			onEnemyGone(model)
			Debris:AddItem(model, 2)
		end)
	end
	if enraged then
		if humanoid then
			humanoid.WalkSpeed *= RiftConfig.EnrageSpeedMultiplier
		end
	end
end

local function clearEnemies()
	table.clear(queue)
	for model in aliveEnemies do
		RiftEnemyAI.unregister(model)
		model:Destroy()
	end
	table.clear(aliveEnemies)
	aliveCount = 0
	for _, child in enemiesFolder:GetChildren() do
		child:Destroy()
	end
end

---------------------------------------------------------------------------
-- Игроки: вход, выход, итоги
---------------------------------------------------------------------------

local function sendIdle(player: Player)
	local idle: Types.RiftState = {
		phase = "Idle",
		wave = 0,
		enemiesLeft = 0,
		enemiesTotal = 0,
		countdown = 0,
		players = 0,
		enraged = false,
		chestWave = false,
		bossWave = false,
	}
	stateRemote:FireClient(player, idle)
end

local function recordBest(player: Player): boolean
	local profile = DataService.get(player)
	if profile and clearedWave > profile.Rift.BestWave then
		profile.Rift.BestWave = clearedWave
		return true
	end
	return false
end

-- Игрок выбыл из забега (вышел, погиб, покинул сервер): итоги ему, телепорт в хаб при добровольном выходе
local function removePlayer(player: Player, backToHub: boolean)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	if run.died then
		run.died:Disconnect()
	end
	player:SetAttribute("InRift", nil)
	if backToHub then
		teleport(player, hubSpawn())
	end
	local profile = DataService.get(player)
	local result: Types.RiftResult = {
		wave = clearedWave,
		kills = run.kills,
		crystals = run.crystals,
		essence = run.essence,
		best = if profile then profile.Rift.BestWave else 0,
		newBest = false,
	}
	if player.Parent then
		resultRemote:FireClient(player, result)
		sendIdle(player)
	end
end

local function enter(player: Player, force: boolean?): (boolean, string)
	if runs[player] then
		return false, "You are already in the Rift"
	end
	if phase == "Ending" then
		return false, "The Rift is resetting, try again in a few seconds"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0 and character and character:FindFirstChild("HumanoidRootPart")) then
		return false, "You cannot enter right now"
	end
	if not DataService.get(player) then
		return false, "Your data is still loading"
	end
	if not force and not hasSkillRing(player) then
		return false, "Wear a ring with a skill first (open Rings)"
	end
	local current = arena
	if not current then
		return false, "The Rift is not ready yet"
	end

	local run: PlayerRun = { kills = 0, totalDamage = 0, waveDamage = 0, crystals = 0, essence = 0, died = nil }
	runs[player] = run
	player:SetAttribute("InRift", true)
	run.died = humanoid.Died:Once(function()
		removePlayer(player, false) -- респавн вернёт игрока в хаб сам
	end)

	local angle = rng:NextNumber() * math.pi * 2
	local ring = RiftConfig.Arena.EntryRadius
	teleport(player, CFrame.new(current.center + Vector3.new(math.cos(angle) * ring, 4, math.sin(angle) * ring)))
	broadcast()
	return true, "Entered the Rift"
end

local function leave(player: Player): (boolean, string)
	if not runs[player] then
		return false, "You are not in the Rift"
	end
	removePlayer(player, true)
	return true, "Left the Rift"
end

---------------------------------------------------------------------------
-- Забег
---------------------------------------------------------------------------

local function waitUntil(endsAt: number, token: number): boolean
	while os.clock() < endsAt and token == runToken and next(runs) ~= nil do
		task.wait(STEP)
	end
	return token == runToken and next(runs) ~= nil
end

-- Награда за зачищенную волну: по доле урона каждого игрока
local function payWave(waveNumber: number)
	local players = playerCount()
	local sum = 0
	for _, run in runs do
		sum += run.waveDamage
	end
	for player, run in runs do
		local share = if sum > 0 then run.waveDamage / sum else 1 / math.max(1, players)
		local crystals, essence = WaveMath.waveReward(waveNumber, share, players, RiftConfig.Rewards)
		if crystals > 0 then
			CurrencyService.add(player, "Crystals", crystals, "Gameplay", "rift_wave")
		end
		if essence > 0 then
			CurrencyService.add(player, "Essence", essence, "Gameplay", "rift_wave")
		end
		run.crystals += crystals
		run.essence += essence
		run.waveDamage = 0
		local reward: Types.RiftWaveReward = {
			wave = waveNumber,
			crystals = crystals,
			essence = essence,
			chest = WaveMath.isChestWave(waveNumber, RiftConfig.Scaling),
		}
		rewardRemote:FireClient(player, reward)
	end
end

-- Одна волна. Возвращает "cleared" (зачищена), "jumped" (админ перепрыгнул волну) или "abort" (забег прерван)
local function runWave(token: number): string
	local scaling = RiftConfig.Scaling
	local players = math.max(1, playerCount())
	waveSerial += 1
	local serial = waveSerial
	enraged = false

	local composition = WaveMath.composition(wave, players, scaling)
	waveTotal = WaveMath.totalEnemies(composition)
	waveHealthMultiplier = WaveMath.healthMultiplier(wave, players, scaling)
	waveDamageMultiplier = WaveMath.damageMultiplier(wave, scaling)
	table.clear(queue)
	for _, kind in { "Boss", "Brute", "Runner", "Grunt" } do
		for _ = 1, (composition :: any)[kind] do
			table.insert(queue, kind)
		end
	end
	-- босс выходит первым, остальные перемешаны
	local boss = if composition.Boss > 0 then table.remove(queue, 1) else nil
	for i = #queue, 2, -1 do
		local j = rng:NextInteger(1, i)
		queue[i], queue[j] = queue[j], queue[i]
	end
	if boss then
		table.insert(queue, 1, boss)
	end
	phase = "Wave"
	phaseEndsAt = 0
	broadcast()

	-- спавнер: по одному, пока не заполнен лимит одновременных врагов
	task.spawn(function()
		while #queue > 0 and token == runToken and serial == waveSerial do
			if aliveCount < RiftConfig.MaxAliveEnemies then
				local kind = table.remove(queue, 1)
				if kind then
					spawnEnemy(kind)
				end
			end
			task.wait(RiftConfig.SpawnInterval)
		end
	end)

	local startedAt = os.clock()
	while token == runToken and next(runs) ~= nil do
		if pendingJump then
			clearEnemies()
			wave = pendingJump
			pendingJump = nil
			waveSerial += 1
			return "jumped"
		end
		if #queue == 0 and aliveCount == 0 then
			return "cleared"
		end
		if not enraged and os.clock() - startedAt > RiftConfig.WaveTimeoutSeconds then
			enraged = true
			RiftEnemyAI.enrage(RiftConfig.EnrageSpeedMultiplier)
		end
		task.wait(STEP)
	end
	return "abort"
end

local function healPlayers()
	for player in runs do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health =
				math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * RiftConfig.HealOnIntermission)
		end
	end
end

local function runLoop(token: number)
	-- лобби
	phase = "Lobby"
	local lobby = if skipLobby then 0 else RiftConfig.LobbySeconds
	skipLobby = false
	phaseEndsAt = os.clock() + lobby
	broadcast()
	if not waitUntil(phaseEndsAt, token) then
		phase = "Idle"
		return
	end

	wave = nextStartWave
	nextStartWave = 1
	clearedWave = wave - 1
	while token == runToken and next(runs) ~= nil do
		local result = runWave(token)
		if result == "abort" then
			break
		elseif result == "cleared" then
			clearedWave = wave
			for player in runs do
				recordBest(player)
			end
			payWave(wave)
			phase = "Intermission"
			phaseEndsAt = os.clock() + RiftConfig.IntermissionSeconds
			healPlayers()
			broadcast()
			if not waitUntil(phaseEndsAt, token) then
				break
			end
			wave += 1
		end
	end

	-- конец забега: убираем врагов, короткая пауза, арена свободна
	clearEnemies()
	if next(runs) ~= nil then
		for player in table.clone(runs) do
			removePlayer(player, true)
		end
	end
	phase = "Ending"
	phaseEndsAt = os.clock() + RiftConfig.EndSeconds
	local endsAt = phaseEndsAt
	while os.clock() < endsAt do
		task.wait(STEP)
	end
	phase = "Idle"
	wave = 0
	clearedWave = 0
	waveTotal = 0
	enraged = false
end

-- Забег стартует при первом входе игрока
local function ensureRun()
	if phase == "Idle" and next(runs) ~= nil then
		runToken += 1
		local token = runToken
		task.spawn(runLoop, token)
	end
end

---------------------------------------------------------------------------
-- Публичный API (меню, портал, админ)
---------------------------------------------------------------------------

function RiftService.enter(player: Player): (boolean, string)
	local ok, message = enter(player)
	if ok then
		ensureRun()
	end
	return ok, message
end

function RiftService.leave(player: Player): (boolean, string)
	return leave(player)
end

-- Админ/тест: войти без проверки кольца и начать с волны n сразу (если забег уже идёт — перепрыгнуть на волну n)
function RiftService.adminJump(player: Player, startWave: number): (boolean, string)
	local n = math.max(1, math.floor(startWave))
	if phase == "Idle" then
		nextStartWave = n
		skipLobby = true
	elseif phase == "Ending" then
		return false, "The Rift is resetting, try again in a few seconds"
	else
		pendingJump = n
	end
	if not runs[player] then
		local ok, message = enter(player, true)
		if not ok then
			if phase == "Idle" then
				nextStartWave, skipLobby = 1, false
			end
			pendingJump = nil
			return false, message
		end
	end
	ensureRun()
	return true, string.format("Rift: wave %d", n)
end

-- Админ/тест: убить всех врагов текущей волны (волна засчитается зачищенной)
function RiftService.killAll()
	table.clear(queue)
	for model in aliveEnemies do
		RiftEnemyAI.unregister(model)
		model:Destroy()
	end
	table.clear(aliveEnemies)
	aliveCount = 0
end

function RiftService.start()
	stateRemote = Remotes.get("RiftState") :: RemoteEvent
	resultRemote = Remotes.get("RiftResult") :: RemoteEvent
	rewardRemote = Remotes.get("RiftWaveReward") :: RemoteEvent
	local getRemote = Remotes.get("RiftGet") :: RemoteFunction
	local actionRemote = Remotes.get("RiftAction") :: RemoteFunction

	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "RiftEnemies"
	enemiesFolder.Parent = Workspace
	arena = RiftArena.build(RiftConfig.Arena)
	RiftEnemyAI.setTargetProvider(getTargets)
	RiftEnemyAI.start()

	getRemote.OnServerInvoke = function(player: Player): Types.RiftInfo
		local profile = DataService.get(player)
		return {
			state = makeState(),
			inArena = runs[player] ~= nil,
			best = if profile then profile.Rift.BestWave else 0,
			weekBest = if profile then profile.Rift.WeekBest else 0,
		}
	end
	actionRemote.OnServerInvoke = function(player: Player, action: any): (boolean, string)
		if action == "Enter" then
			return RiftService.enter(player)
		elseif action == "Leave" then
			return leave(player)
		end
		return false, "Unknown action"
	end

	-- вклад в волну и бонусные награды за убийства (события CombatService; чужие враги и манекены игнорируются)
	CombatService.enemyDamaged.Event:Connect(function(player: Player, model: Model, amount: number)
		local run = runs[player]
		if run and model:GetAttribute("RiftEnemy") == true then
			run.waveDamage += amount
			run.totalDamage += amount
		end
	end)
	CombatService.enemyKilled.Event:Connect(function(player: Player, model: Model)
		local run = runs[player]
		if not (run and model:GetAttribute("RiftEnemy") == true) then
			return
		end
		run.kills += 1
		local crystals = (model:GetAttribute("KillCrystals") :: number?) or 1
		run.crystals += crystals -- обычная награда за убийство уже даёт 1 кристалл; добавляем разницу
		local bonus = crystals - 1
		if bonus > 0 then
			CurrencyService.add(player, "Crystals", bonus, "Gameplay", "rift_kill")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayer(player, false)
	end)

	-- порталы: вход в хабе (ProximityPrompt на PortalCyan) и выход в арене
	task.spawn(function()
		while not Workspace:GetAttribute("HubReady") do
			Workspace:GetAttributeChangedSignal("HubReady"):Wait()
		end
		local hub = Workspace:FindFirstChild("MainHub")
		local portal = hub and hub:FindFirstChild("PortalCyan", true)
		if portal and portal:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Enter the Rift"
			prompt.ObjectText = "Rift"
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt.Parent = portal
			prompt.Triggered:Connect(function(player: Player)
				local ok, message = RiftService.enter(player)
				if not ok then
					player:SetAttribute("RiftMessage", message .. "|" .. tostring(os.clock()))
				end
			end)
		end
	end)
	local current = arena
	if current then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Leave the Rift"
		prompt.ObjectText = "Exit"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = current.exitPortal
		prompt.Triggered:Connect(function(player: Player)
			leave(player)
		end)
	end

	-- состояние клиентам раз в STEP секунд, пока кто-то в арене
	task.spawn(function()
		while true do
			task.wait(STEP)
			broadcast()
		end
	end)
end

return RiftService
