--!strict
-- Тестовые враги для админ-меню: простая процедурная модель с Humanoid и тегом "Enemy" (как манекены карты, но
-- смертные: 300 HP, награды за убийство как обычно). Kind "Dummy" стоит на месте, "Mover" бродит — на нём видно,
-- как Fireball улетает в место, где цель была, а Meteor бьёт по отмеченному кругу.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatConfig =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("CombatConfig"))

local TestEnemy = {}

local FOLDER_NAME = "AdminEnemies"
local MAX_HEALTH = 300
local WANDER_RADIUS = { 10, 20 }

local function getFolder(): Folder
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	return created
end

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Сколько тестовых врагов сейчас в мире
function TestEnemy.count(): number
	return #getFolder():GetChildren()
end

function TestEnemy.clear()
	for _, child in getFolder():GetChildren() do
		child:Destroy()
	end
end

-- Создаёт врага; position — центр туловища над землёй (см. высоту HipHeight ниже)
function TestEnemy.spawn(kind: string, position: Vector3): Model
	local mover = kind == "Mover"
	local color = if mover then Color3.fromRGB(150, 90, 210) else Color3.fromRGB(205, 140, 70)

	local model = Instance.new("Model")
	model.Name = if mover then "Test Mover" else "Test Dummy"

	-- HumanoidRootPart (2x2x1) + туловище 2x4x1 + голова; HipHeight 1 => туловище стоит на земле
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), color, model)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 4, 1), color, model)
	local head = part("Head", Vector3.new(1.4, 1.4, 1.4), color:Lerp(Color3.new(1, 1, 1), 0.3), model)
	local cf = CFrame.new(position)
	root.CFrame = cf
	torso.CFrame = cf
	head.CFrame = cf * CFrame.new(0, 2.9, 0)
	for _, other in { torso, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = other
		weld.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 1
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.WalkSpeed = if mover then 10 else 0
	humanoid.DisplayName = model.Name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model

	model.PrimaryPart = root
	CollectionService:AddTag(model, CombatConfig.EnemyTag)
	model.Parent = getFolder()
	root:SetNetworkOwner(nil) -- физику ведёт сервер

	humanoid.Died:Once(function()
		Debris:AddItem(model, 3)
	end)

	if mover then
		task.spawn(function()
			while model.Parent and humanoid.Health > 0 do
				local angle = math.random() * math.pi * 2
				local distance = WANDER_RADIUS[1] + math.random() * (WANDER_RADIUS[2] - WANDER_RADIUS[1])
				humanoid:MoveTo(root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
				task.wait(2.5)
			end
		end)
	end
	return model
end

return TestEnemy
