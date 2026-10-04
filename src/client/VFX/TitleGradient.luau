--!strict
-- Анимация градиента на титулах над головой: бегущая волна цвета по тексту (UIGradient.Offset), радуга для самых
-- редких. Один общий цикл на все титулы; титулы дальше CULL_DISTANCE от камеры не обновляем (экономим CPU).
-- Градиенты создаёт сервер (server/Services/OverheadTitleService) и помечает тегом "RareTitleGradient".

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Rarity =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Gacha"):WaitForChild("Rarity"))

local TitleGradient = {}

local TAG = "RareTitleGradient"
local CULL_DISTANCE = 70
local WAVE_PERIOD = 1.8 -- секунд на один сдвиг волны
local RAINBOW_PERIOD = 4 -- секунд на полный круг оттенков

local tracked: { [UIGradient]: boolean } = {}

local function adorneePosition(gradient: UIGradient): Vector3?
	local gui = gradient:FindFirstAncestorOfClass("BillboardGui")
	local adornee = gui and gui.Adornee
	return if adornee and adornee:IsA("BasePart") then adornee.Position else nil
end

function TitleGradient.start()
	local function add(instance: Instance)
		if instance:IsA("UIGradient") then
			tracked[instance] = true
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		tracked[instance :: UIGradient] = nil
	end)
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end

	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		for gradient in tracked do
			if not gradient.Parent then
				tracked[gradient] = nil
				continue
			end
			local position = adorneePosition(gradient)
			if position and (position - camera.CFrame.Position).Magnitude <= CULL_DISTANCE then
				if gradient:GetAttribute("Rainbow") == true then
					gradient.Color = Rarity.rainbowSequence((now / RAINBOW_PERIOD) % 1)
				else
					-- палитра периодична (0.5), сдвиг от -0.25 до +0.25 — бесшовная волна
					gradient.Offset = Vector2.new(((now / WAVE_PERIOD) % 1) * 0.5 - 0.25, 0)
				end
			end
		end
	end)
end

return TitleGradient
