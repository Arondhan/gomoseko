--!strict
-- Просмотр модели целиком в ViewportFrame (для окна персонажа): клон персонажа без скриптов/GUI,
-- камера по размеру модели, вращение перетаскиванием мыши. Если клонирование не удалось — окно просто пустое.

local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local ModelView = {}

local CAMERA_FOV = 30
local DISTANCE_PADDING = 1.15
local ROTATE_SPEED = 0.012 -- радиан на пиксель

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

export type View = {
	frame: ViewportFrame,
	setModel: (model: Model?) -> (),
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

function ModelView.new(parent: Instance, size: UDim2, position: UDim2): View
	local viewport = Theme.new("ViewportFrame", {
		Name = "ModelView",
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(34, 38, 52),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 244, 225),
	}, parent)
	Theme.corner(viewport, 8)
	Theme.gradient(viewport, 90, Color3.fromRGB(58, 64, 84), Color3.fromRGB(20, 22, 32))

	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local current: Model? = nil
	local yaw = 0
	local focus = Vector3.zero
	local distance = 10

	local function updateCamera()
		local rotation = CFrame.Angles(0, yaw, 0)
		local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, distance))
		camera.CFrame = CFrame.lookAt(focus + offset + Vector3.new(0, 0.4, 0), focus)
	end

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

		local cf, extents = clone:GetBoundingBox()
		focus = cf.Position
		local height = math.max(extents.Y, extents.X)
		distance = (height / 2) / math.tan(math.rad(CAMERA_FOV / 2)) * DISTANCE_PADDING
		-- модель смотрит вдоль LookVector корня: ставим камеру спереди
		local root = clone:FindFirstChild("HumanoidRootPart")
		local lookVector = if root and root:IsA("BasePart") then root.CFrame.LookVector else cf.LookVector
		yaw = math.atan2(lookVector.X, lookVector.Z)
		viewport.LightDirection = Vector3.new(-0.4, -0.6, -0.7)
		updateCamera()
	end

	-- вращение: тянем мышью по окну
	local dragging = false
	local lastX = 0
	viewport.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			lastX = input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= (input.Position.X - lastX) * ROTATE_SPEED
			lastX = input.Position.X
			updateCamera()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	return { frame = viewport, setModel = setModel }
end

return ModelView
