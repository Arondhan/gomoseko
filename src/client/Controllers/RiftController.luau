--!strict
-- Клиентская часть Rift: состояние забега с сервера (фаза, волна, враги, таймеры), вход/выход, награды за волны и
-- итоги. Всё решает RiftService; здесь только показ. Находится ли игрок в арене, видно по атрибуту Player "InRift".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RiftController = {}

-- Fire(state) при каждом обновлении состояния
RiftController.changed = Instance.new("BindableEvent")
-- Fire(reward: RiftWaveReward) после зачищенной волны
RiftController.reward = Instance.new("BindableEvent")
-- Fire(result: RiftResult) когда игрок выбыл из забега (итоги)
RiftController.result = Instance.new("BindableEvent")

local localPlayer = Players.LocalPlayer
local state: Types.RiftState? = nil
local receivedAt = 0

function RiftController.getState(): Types.RiftState?
	return state
end

function RiftController.isInArena(): boolean
	return localPlayer:GetAttribute("InRift") == true
end

-- Секунд до конца лобби/перерыва с поправкой на время после последнего ответа сервера
function RiftController.countdown(): number
	if not state then
		return 0
	end
	return math.max(0, state.countdown - (os.clock() - receivedAt))
end

-- Состояние забега и личный рекорд (yield)
function RiftController.info(): Types.RiftInfo?
	local remote = Remotes.get("RiftGet") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer()
	end)
	if ok and type(result) == "table" and type(result.state) == "table" then
		return result :: Types.RiftInfo
	end
	return nil
end

local function act(action: string): (boolean, string)
	local remote = Remotes.get("RiftAction") :: RemoteFunction
	local ok, success, message = pcall(function()
		return remote:InvokeServer(action)
	end)
	if not ok then
		return false, "Connection problem, try again"
	end
	return success == true, tostring(message)
end

function RiftController.enter(): (boolean, string)
	return act("Enter")
end

function RiftController.leave(): (boolean, string)
	return act("Leave")
end

function RiftController.start()
	local stateRemote = Remotes.get("RiftState") :: RemoteEvent
	local rewardRemote = Remotes.get("RiftWaveReward") :: RemoteEvent
	local resultRemote = Remotes.get("RiftResult") :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(value: Types.RiftState)
		if type(value) == "table" and type(value.phase) == "string" then
			state = value
			receivedAt = os.clock()
			RiftController.changed:Fire(value)
		end
	end)
	rewardRemote.OnClientEvent:Connect(function(value: Types.RiftWaveReward)
		if type(value) == "table" and type(value.wave) == "number" then
			RiftController.reward:Fire(value)
		end
	end)
	resultRemote.OnClientEvent:Connect(function(value: Types.RiftResult)
		if type(value) == "table" and type(value.wave) == "number" then
			RiftController.result:Fire(value)
		end
	end)
end

return RiftController
