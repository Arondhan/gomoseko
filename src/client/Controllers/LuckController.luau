--!strict
-- Клиентская копия бонусов удачи, которые считает сервер: AFK Playtime Luck и Lucky Hour. Только для показа в UI —
-- реальный бонус сервер берёт сам при каждом ролле. Времена приходят относительными (секунды) и досчитываются
-- локально по os.clock() с момента получения.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local LuckController = {}

-- Fire() при любом обновлении (смена шага AFK-удачи, начало/конец Lucky Hour)
LuckController.changed = Instance.new("BindableEvent")
-- Fire(status) только при смене состояния Lucky Hour (для баннера и уведомления)
LuckController.eventChanged = Instance.new("BindableEvent")

local playtime: Types.PlaytimeLuck? = nil
local playtimeAt = 0
local event: Types.LuckEventStatus? = nil
local eventAt = 0

function LuckController.getPlaytime(): Types.PlaytimeLuck?
	return playtime
end

-- Секунд до следующего шага AFK-удачи (nil — максимум или данных нет)
function LuckController.playtimeNextIn(): number?
	if not playtime or playtime.nextIn == nil then
		return nil
	end
	return math.max(0, playtime.nextIn - (os.clock() - playtimeAt))
end

-- Состояние Lucky Hour с поправкой на прошедшее время (remaining — секунд до конца, если активно, иначе до начала)
function LuckController.getEvent(): { active: boolean, remaining: number, percent: number, name: string }?
	if not event then
		return nil
	end
	local elapsed = os.clock() - eventAt
	local remaining = math.max(0, (if event.active then event.endsIn else event.startsIn) - elapsed)
	return { active = event.active, remaining = remaining, percent = event.percent, name = event.name }
end

local function setPlaytime(value: Types.PlaytimeLuck)
	playtime = value
	playtimeAt = os.clock()
	LuckController.changed:Fire()
end

local function setEvent(value: Types.LuckEventStatus, announce: boolean)
	local was = event
	event = value
	eventAt = os.clock()
	LuckController.changed:Fire()
	if announce or (was ~= nil and was.active ~= value.active) then
		LuckController.eventChanged:Fire(value)
	end
end

function LuckController.start()
	local playtimeRemote = Remotes.get("PlaytimeLuck") :: RemoteEvent
	local eventRemote = Remotes.get("LuckEvent") :: RemoteEvent
	playtimeRemote.OnClientEvent:Connect(function(value: Types.PlaytimeLuck)
		if type(value) == "table" and type(value.bonus) == "number" then
			setPlaytime(value)
		end
	end)
	eventRemote.OnClientEvent:Connect(function(value: Types.LuckEventStatus)
		if type(value) == "table" and type(value.active) == "boolean" then
			setEvent(value, true)
		end
	end)
	task.spawn(function()
		local getRemote = Remotes.get("LuckBoostsGet") :: RemoteFunction
		local ok, result = pcall(function()
			return getRemote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			if type(result.playtime) == "table" then
				setPlaytime(result.playtime)
			end
			if type(result.event) == "table" then
				setEvent(result.event, result.event.active) -- зашли посреди Lucky Hour — сразу покажем баннер
			end
		end
	end)
end

return LuckController
