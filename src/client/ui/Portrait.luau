--!strict
-- Круглый портрет персонажа/врага через ViewportFrame (в CanvasGroup с UICorner, чтобы получился круг).
-- Клонирует модель, вычищает скрипты/GUI/Humanoid, ставит камеру перед лицом (по LookVector HumanoidRootPart).
-- Если клон не удался (Archivable=false и т.п.) — портрет остаётся пустым, UI продолжает работать.

local Theme = require(script.Parent.Theme)

local Portrait = {}

local CAMERA_DISTANCE = 3.4
local CAMERA_FOV = 38
local FACE_OFFSET = Vector3.new(0, -0.15, 0) -- смотрим чуть ниже центра головы, чтобы влезли плечи

export type Portrait = {
	frame: CanvasGroup,
	setModel: (model: Model?) -> (),
}

-- Классы, которые в портрете не нужны (логика, интерфейс, эффекты)
local STRIP_CLASSES = {
	"BaseScript",
	"BillboardGui",
	"SurfaceGui",
	"Highlight",
	"Humanoid",
	"Sound",
	"ForceField",
	"ClickDetector",
	"ProximityPrompt",
	"ParticleEmitter",
	"PointLight",
	"Beam",
}

local function strip(model: Instance)
	for _, descendant in model:GetDescendants() do
		for _, className in STRIP_CLASSES do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

function Portrait.new(parent: Instance, size: number, position: UDim2, anchor: Vector2?): Portrait
	local circle = Theme.new("CanvasGroup", {
		Name = "Portrait",
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.PanelTop,
		BorderSizePixel = 0,
	}, parent)
	Theme.corner(circle, size)

	local viewport = Theme.new("ViewportFrame", {
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(34, 38, 52),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 244, 225),
	}, circle)
	Theme.gradient(viewport, 90, Color3.fromRGB(58, 64, 84), Color3.fromRGB(22, 24, 34))

	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local current: Instance? = nil

	local function setModel(model: Model?)
		if current then
			current:Destroy()
			current = nil
		end
		if not model then
			return
		end
		local wasArchivable = model.Archivable
		model.Archivable = true
		local clone = model:Clone()
		model.Archivable = wasArchivable
		if not clone then
			return
		end
		strip(clone)
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		clone.Parent = viewport
		current = clone

		local head = clone:FindFirstChild("Head")
		local root = clone:FindFirstChild("HumanoidRootPart")
		if not (head and head:IsA("BasePart")) then
			return
		end
		local facing = if root and root:IsA("BasePart") then root.CFrame.LookVector else head.CFrame.LookVector
		local focus = head.Position + FACE_OFFSET
		camera.CFrame = CFrame.lookAt(focus + facing * CAMERA_DISTANCE + Vector3.new(0, 0.15, 0), focus)
		viewport.LightDirection = -facing + Vector3.new(0.3, -0.4, 0)
	end

	return { frame = circle, setModel = setModel }
end

return Portrait
