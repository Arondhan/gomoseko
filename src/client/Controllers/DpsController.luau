--!strict
-- Клиентская часть DPS-арены: прогресс текущего замера и итоги (события с сервера), запрос таблиц лидеров.
-- Счёт и награды считает сервер (DpsService); здесь только показ.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DpsController = {}

-- Fire(status: Types.DpsStatus) при каждом событии: Running / Finished / WeeklyReward
DpsController.status = Instance.new("BindableEvent")

function DpsController.getBoards(): Types.DpsBoardsResponse?
	local remote = Remotes.get("DpsGetBoards") :: RemoteFunction
	local ok, result = pcall(function()
		return remote:InvokeServer()
	end)
	if ok and type(result) == "table" then
		return result :: Types.DpsBoardsResponse
	end
	return nil
end

function DpsController.start()
	local remote = Remotes.get("DpsStatus") :: RemoteEvent
	remote.OnClientEvent:Connect(function(status: Types.DpsStatus)
		if type(status) == "table" and type(status.kind) == "string" then
			DpsController.status:Fire(status)
		end
	end)
end

return DpsController
