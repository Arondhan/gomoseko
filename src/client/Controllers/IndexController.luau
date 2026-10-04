--!strict
-- Клиентская часть Index (книга колец): состояние и получение наград. Всё решает сервер (IndexService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local IndexController = {}

-- Fire(state) после каждого обновления
IndexController.changed = Instance.new("BindableEvent")

local state: Types.IndexState? = nil

function IndexController.getState(): Types.IndexState?
	return state
end

local function setState(newState: Types.IndexState)
	state = newState
	IndexController.changed:Fire(newState)
end

-- Запросить состояние у сервера (yield)
function IndexController.refresh(): Types.IndexState?
	local remote = Remotes.get("IndexGet") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer()
	end)
	if ok and type(result) == "table" and type(result.discovered) == "table" then
		setState(result)
	end
	return state
end

-- Забрать награду за веху (yield): (успех, причина отказа)
function IndexController.claim(percent: number): (boolean, string?)
	local remote = Remotes.get("IndexClaim") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer(percent)
	end)
	if not ok or type(result) ~= "table" then
		return false, "Connection problem, try again"
	end
	local response = result :: Types.IndexClaimResponse
	if response.state then
		setState(response.state)
	end
	return response.ok, response.reason
end

function IndexController.start()
	task.spawn(IndexController.refresh)
end

return IndexController
