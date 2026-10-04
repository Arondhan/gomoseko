--!strict
-- AFK Playtime Luck: за каждые GachaConfig.Playtime.StepSeconds непрерывного нахождения на сервере базовая удача
-- растёт на +StepPercent % (+0.1x), до MaxPercent (+1.0x). Время хранится только в памяти сервера — когда игрок
-- выходит, бонус сбрасывается (это и есть «непрерывность»). Клиент получает множитель через RemoteEvent
-- PlaytimeLuck (и при входе через LuckBoostsGet) только для показа; сам бонус считает сервер при каждом ролле.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlaytimeMath = require(Shared:WaitForChild("Gacha"):WaitForChild("PlaytimeMath"))
local GachaConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GachaConfig"))

local PlaytimeLuckService = {}

local joinedAt: { [Player]: number } = {}
local lastSteps: { [Player]: number } = {}
local offsets: { [Player]: number } = {} -- админ/тест: добавленные секунды «времени на сервере»
local remote: RemoteEvent

local config = GachaConfig.Playtime

local function info(player: Player): PlaytimeMath.Info
	local joined = joinedAt[player]
	return PlaytimeMath.info((if joined then os.clock() - joined else 0) + (offsets[player] or 0), config)
end

-- Полезная нагрузка для клиента
function PlaytimeLuckService.payload(player: Player): Types.PlaytimeLuck
	local current = info(player)
	return {
		steps = current.steps,
		percent = current.percent,
		bonus = current.bonus,
		maxBonus = config.MaxPercent / 100,
		stepBonus = config.StepPercent / 100,
		nextIn = current.nextIn,
	}
end

-- Бонус к удаче в процентах (для GachaService.computeLuck)
function PlaytimeLuckService.percent(player: Player): number
	return info(player).percent
end

-- Админ/тест: прибавить игроку seconds секунд проведённого на сервере времени
function PlaytimeLuckService.addOffset(player: Player, seconds: number)
	offsets[player] = (offsets[player] or 0) + seconds
end

local function track(player: Player)
	if joinedAt[player] then
		return
	end
	joinedAt[player] = os.clock()
	lastSteps[player] = 0
	player:SetAttribute("PlaytimeLuck", 0)
end

function PlaytimeLuckService.start()
	remote = Remotes.get("PlaytimeLuck") :: RemoteEvent

	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joinedAt[player] = nil
		lastSteps[player] = nil
		offsets[player] = nil
	end)

	-- раз в секунду проверяем смену шага; сообщаем клиенту только при изменении (и атрибут для отладки/UI)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in joinedAt do
				local current = info(player)
				if current.steps ~= lastSteps[player] then
					lastSteps[player] = current.steps
					player:SetAttribute("PlaytimeLuck", current.bonus)
					remote:FireClient(player, PlaytimeLuckService.payload(player))
				end
			end
		end
	end)
end

return PlaytimeLuckService
