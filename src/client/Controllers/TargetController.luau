--!strict
-- Таргет: клик/тап по врагу выбирает цель (она подсвечивается контуром и становится целью атаки); без выбранной цели
-- сервер сам бьёт ближайшего врага. Клик по пустому месту / смерть / исчезновение цели снимают выбор.
-- Цель — только модель с тегом "Enemy" и живым Humanoid. Урон и проверки всё равно делает сервер.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("CombatConfig"))

local TargetController = {}

-- Fire(model?) при смене цели (nil — цель снята)
TargetController.changed = Instance.new("BindableEvent")

local PICK_DISTANCE = 500
local OUTLINE_COLOR = Color3.fromRGB(255, 70, 50)

local localPlayer = Players.LocalPlayer
local target: Model? = nil
local highlight: Highlight? = nil
local connections: { RBXScriptConnection } = {}

local function isAliveEnemy(model: Instance?): boolean
	if not model or not model:IsA("Model") or not CollectionService:HasTag(model, CombatConfig.EnemyTag) then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and model:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Поднимаемся от кликнутой детали к модели-врагу
local function findEnemyModel(instance: Instance): Model?
	local current: Instance? = instance
	while current and current ~= Workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, CombatConfig.EnemyTag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

function TargetController.getTarget(): Model?
	return target
end

function TargetController.clear()
	if target == nil then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	target = nil
	TargetController.changed:Fire(nil)
end

function TargetController.select(model: Model)
	if model == target or not isAliveEnemy(model) then
		return
	end
	TargetController.clear()
	target = model

	local outline = Instance.new("Highlight")
	outline.Name = "TargetHighlight"
	outline.Adornee = model
	outline.FillTransparency = 1
	outline.OutlineColor = OUTLINE_COLOR
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	highlight = outline

	-- снимаем выбор, когда цель умерла или исчезла (например, манекен респавнится новой моделью)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(connections, humanoid.Died:Connect(TargetController.clear))
	end
	table.insert(
		connections,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				TargetController.clear()
			end
		end)
	)
	TargetController.changed:Fire(model)
end

-- Выбор по точке экрана (screenPoint — как GetMouseLocation, с учётом верхней панели): враг — выбираем, иначе снимаем
local function pickAt(screenPoint: Vector2)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if localPlayer.Character then
		params.FilterDescendantsInstances = { localPlayer.Character }
	end
	local result = Workspace:Raycast(ray.Origin, ray.Direction * PICK_DISTANCE, params)

	local model = result and findEnemyModel(result.Instance)
	if model and isAliveEnemy(model) then
		TargetController.select(model)
	else
		TargetController.clear()
	end
end

function TargetController.start()
	local touches: { [InputObject]: { position: Vector2, time: number } } = {}
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return -- клик по UI не должен менять цель
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pickAt(UserInputService:GetMouseLocation())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = { position = Vector2.new(input.Position.X, input.Position.Y), time = os.clock() }
		end
	end)
	-- тап на телефоне: короткое касание без сдвига (иначе это поворот камеры)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local start = touches[input]
		if not start then
			return
		end
		touches[input] = nil
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if os.clock() - start.time < 0.3 and (position - start.position).Magnitude < 12 then
			pickAt(position + GuiService:GetGuiInset())
		end
	end)
end

return TargetController
