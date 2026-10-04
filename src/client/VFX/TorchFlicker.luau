--!strict
-- Мерцание факелов и фонарей: все PointLight с тегом "Torch" слегка меняют яркость и радиус по шуму.
-- Выполняется только на клиенте (на сервере не реплицируется), для далёких источников пропускается.
-- Базовые значения лежат в атрибутах BaseBrightness / BaseRange (их ставит server/Hub/Atmosphere.torchLight).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TorchFlicker = {}

local TAG = "Torch"
local MAX_DISTANCE = 160 -- дальше этого расстояния до камеры источник не мерцает
local SLOW = 2.2 -- скорость плавного колебания
local FAST = 9 -- скорость дрожания

type Entry = {
	light: PointLight,
	baseBrightness: number,
	baseRange: number,
	phase: number,
	part: BasePart?,
}

local entries: { [PointLight]: Entry } = {}

local function add(instance: Instance)
	if not instance:IsA("PointLight") then
		return
	end
	local parent = instance.Parent
	local baseBrightness = instance:GetAttribute("BaseBrightness")
	local baseRange = instance:GetAttribute("BaseRange")
	entries[instance] = {
		light = instance,
		baseBrightness = if type(baseBrightness) == "number" then baseBrightness else instance.Brightness,
		baseRange = if type(baseRange) == "number" then baseRange else instance.Range,
		phase = math.random() * 100,
		part = if parent and parent:IsA("BasePart") then parent else nil,
	}
end

function TorchFlicker.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		if instance:IsA("PointLight") then
			entries[instance] = nil
		end
	end)

	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local origin = camera.CFrame.Position
		local t = os.clock()
		for light, entry in entries do
			if not light.Parent then
				entries[light] = nil
			elseif not entry.part or (entry.part.Position - origin).Magnitude <= MAX_DISTANCE then
				local slow = math.noise(t * SLOW + entry.phase, entry.phase * 1.3) -- примерно -0.5..0.5
				local fast = math.noise(t * FAST + entry.phase, 0.5)
				local factor = 1 + slow * 0.35 + fast * 0.12
				light.Brightness = entry.baseBrightness * factor
				light.Range = entry.baseRange * (0.95 + factor * 0.05)
			end
		end
	end)
end

return TorchFlicker
