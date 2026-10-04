--!strict
-- Вибрация геймпада (Roblox не даёт API вибрации телефона — только моторы контроллеров через HapticService).
-- Если вибрация не поддерживается или выключена в настройках — молча ничего не делает.

local HapticService = game:GetService("HapticService")

local Haptics = {}

local enabled = true
local pulseId = 0

function Haptics.setEnabled(value: boolean)
	enabled = value
end

local function supported(): boolean
	local ok, result = pcall(function()
		local pad = Enum.UserInputType.Gamepad1
		return HapticService:IsVibrationSupported(pad)
			and HapticService:IsMotorSupported(pad, Enum.VibrationMotor.Large)
	end)
	return ok and result == true
end

-- strength 0..1, duration в секундах
function Haptics.pulse(strength: number, duration: number)
	if not enabled or not supported() then
		return
	end
	pulseId += 1
	local id = pulseId
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, math.clamp(strength, 0, 1))
	end)
	task.delay(duration, function()
		if id == pulseId then
			pcall(function()
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
			end)
		end
	end)
end

return Haptics
