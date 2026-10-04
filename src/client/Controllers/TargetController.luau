--!strict
-- Таргет-система в стиле WoW: ЛКМ по врагу выбирает цель, Tab — ближайшая цель (повтор — следующая),
-- клик по пустому месту / смерть / исчезновение цели снимают выбор. Выбранная цель подсвечивается контуром.
-- Цель — только модель с тегом "Enemy" и живым Humanoid. Урон и проверки всё равно делает сервер.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
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
local notify: (string) -> () = function() end -- сообщение игроку (ui/Notice), задаётся в start()
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

local function myRoot(): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
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

-- Tab (как в WoW): враги, видимые на экране в радиусе TabTargetRange, по возрастанию расстояния.
-- Tab — ближайший / следующий по кругу, Shift+Tab — предыдущий. Если подходящих нет — сообщение игроку.
local function cycleTarget(backwards: boolean)
	local root = myRoot()
	local camera = Workspace.CurrentCamera
	if not (root and camera) then
		return
	end
	local list: { { model: Model, dist: number } } = {}
	for _, instance in CollectionService:GetTagged(CombatConfig.EnemyTag) do
		if isAliveEnemy(instance) then
			local model = instance :: Model
			local enemyRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart
			local dist = (enemyRoot.Position - root.Position).Magnitude
			if dist <= CombatConfig.TabTargetRange then
				local _, onScreen = camera:WorldToViewportPoint(enemyRoot.Position)
				if onScreen then
					table.insert(list, { model = model, dist = dist })
				end
			end
		end
	end
	if #list == 0 then
		notify("Нет целей поблизости")
		return
	end
	table.sort(list, function(a, b)
		return a.dist < b.dist
	end)

	-- позиция текущей цели в списке (0 — цели нет или она не попала в список)
	local currentIndex = 0
	for i, entry in list do
		if entry.model == target then
			currentIndex = i
			break
		end
	end
	local nextIndex
	if backwards then
		nextIndex = if currentIndex <= 1 then #list else currentIndex - 1
	else
		nextIndex = currentIndex % #list + 1
	end
	TargetController.select(list[nextIndex].model)
end

-- ЛКМ: луч от курсора. Враг — выбираем, всё остальное — снимаем цель.
local function pickUnderCursor()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

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

-- notifyCallback получает текст сообщения («Нет целей поблизости»)
function TargetController.start(notifyCallback: ((string) -> ())?)
	if notifyCallback then
		notify = notifyCallback
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return -- клик по UI не должен менять цель
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pickUnderCursor()
		end
	end)

	-- ContextActionService на высоком приоритете, чтобы Tab не открывал стандартный список игроков
	ContextActionService:BindActionAtPriority("TargetCycle", function(_, state)
		if state == Enum.UserInputState.Begin then
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			cycleTarget(shift)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Tab)
end

return TargetController
