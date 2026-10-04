--!strict
-- Lucky Hour: событие удачи по расписанию (GachaConfig.LuckEvent). Расписание детерминированно по unix-времени
-- (LuckEventMath), поэтому все серверы совпадают без MessagingService. Сервер объявляет начало/конец всем клиентам;
-- GachaService добавляет бонус как бесплатный источник удачи (виден в разбивке удачи и в таблице шансов).
-- Здесь же отвечает на LuckBoostsGet: одним запросом клиент получает и AFK-удачу, и состояние Lucky Hour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LuckEventMath = require(Shared:WaitForChild("Gacha"):WaitForChild("LuckEventMath"))
local GachaConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GachaConfig"))

local PlaytimeLuckService = require(script.Parent:WaitForChild("PlaytimeLuckService"))

local LuckEventService = {}

local config = GachaConfig.LuckEvent
local overrideEndsAt = 0 -- админ: принудительный Lucky Hour до этого unix-времени (0 — нет)

local function currentStatus(): LuckEventMath.Status
	local now = os.time()
	local status = LuckEventMath.status(now, config)
	if not status.active and now < overrideEndsAt then
		return { active = true, endsIn = overrideEndsAt - now, startsIn = 0, endsAt = overrideEndsAt }
	end
	return status
end

-- Админ/тест: включить Lucky Hour на seconds секунд на этом сервере (0 — выключить принудительное окно)
function LuckEventService.setOverride(seconds: number)
	overrideEndsAt = if seconds > 0 then os.time() + seconds else 0
end

function LuckEventService.status(): Types.LuckEventStatus
	local status = currentStatus()
	return {
		name = config.Name,
		active = status.active,
		endsIn = status.endsIn,
		startsIn = status.startsIn,
		percent = config.Percent,
	}
end

-- Бонус к удаче в процентах прямо сейчас (0 вне окна)
function LuckEventService.percent(): number
	return if currentStatus().active then config.Percent else 0
end

function LuckEventService.start()
	local eventRemote = Remotes.get("LuckEvent") :: RemoteEvent
	local boostsRemote = Remotes.get("LuckBoostsGet") :: RemoteFunction

	boostsRemote.OnServerInvoke = function(player: Player): Types.LuckBoosts
		return { playtime = PlaytimeLuckService.payload(player), event = LuckEventService.status() }
	end

	-- рассылаем смену состояния (начало и конец окна)
	task.spawn(function()
		local wasActive = LuckEventService.status().active
		while true do
			task.wait(1)
			local status = LuckEventService.status()
			if status.active ~= wasActive then
				wasActive = status.active
				eventRemote:FireAllClients(status)
			end
		end
	end)
end

return LuckEventService
