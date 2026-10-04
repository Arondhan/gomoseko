--!strict
-- Клиентская часть Gacha: состояние призыва с сервера (кристаллы, удача, шансы, таймер бесплатного ролла),
-- запрос ролла и редкие находки других игроков. Никакой игровой логики здесь нет — всё решает GachaService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local GachaController = {}

-- Fire(state) после каждого обновления состояния
GachaController.stateChanged = Instance.new("BindableEvent")
-- Fire(announce) когда кто-то нашёл очень редкое кольцо
GachaController.announced = Instance.new("BindableEvent")

local state: Types.GachaState? = nil
local fetchedAt = 0

function GachaController.getState(): Types.GachaState?
	return state
end

-- Сколько секунд осталось до бесплатного ролла (с учётом времени, прошедшего с последнего ответа сервера)
function GachaController.freeRollIn(): number
	if not state then
		return 0
	end
	return math.max(0, state.freeRollIn - (os.clock() - fetchedAt))
end

local function setState(newState: Types.GachaState)
	state = newState
	fetchedAt = os.clock()
	GachaController.stateChanged:Fire(newState)
end

-- Запросить состояние у сервера (yield)
function GachaController.refresh(): Types.GachaState?
	local remote = Remotes.get("GachaGetState") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer()
	end)
	if ok and type(result) == "table" then
		setState(result)
		return result
	end
	return state
end

-- Призыв (yield). count: 1 или multiCount; free = true — бесплатный ролл
function GachaController.roll(count: number, free: boolean): Types.GachaRollResponse
	local remote = Remotes.get("GachaRoll") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(count, free)
	end)
	if not ok or type(result) ~= "table" then
		return { ok = false, reason = "Connection problem, try again" }
	end
	local response = result :: Types.GachaRollResponse
	if response.state then
		setState(response.state)
	end
	return response
end

function GachaController.start()
	local announce = Remotes.get("GachaAnnounce") :: RemoteEvent
	announce.OnClientEvent:Connect(function(info: Types.GachaAnnounce)
		if type(info) == "table" and type(info.ringId) == "string" then
			GachaController.announced:Fire(info)
		end
	end)
	task.spawn(GachaController.refresh)
end

return GachaController
