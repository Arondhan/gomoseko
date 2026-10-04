--!strict
-- Фабрика врагов Rift: процедурная модель (Humanoid + тело + голова, без внешних ассетов) с тегом "Enemy", чтобы по
-- ней били все скиллы (CombatService). Характеристики типа — Configs/RiftConfig.Enemies, умножаются на масштаб
-- волны. Врагов двигает server/Services/RiftEnemyAI (общий цикл), здесь только создание модели.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local CombatConfig = require(Configs:WaitForChild("CombatConfig"))
local RiftConfig = require(Configs:WaitForChild("RiftConfig"))

local EnemyFactory = {}

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

-- kind: "Grunt" | "Runner" | "Brute" | "Boss"; position — центр туловища над землёй (см. HipHeight)
function EnemyFactory.create(
	kind: string,
	position: Vector3,
	healthMultiplier: number,
	damageMultiplier: number,
	parent: Instance
): Model?
	local stats = RiftConfig.Enemies[kind]
	if not stats then
		return nil
	end
	local s = stats.Size
	local color = stats.Color

	local model = Instance.new("Model")
	model.Name = stats.Name

	-- HumanoidRootPart (2s x 2s x s) + туловище 2s x 4s x s + голова; HipHeight = s => туловище стоит на земле
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1) * s, color, model)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 4, 1) * s, color, model)
	local head = part("Head", Vector3.one * 1.4 * s, color:Lerp(Color3.new(1, 1, 1), 0.3), model)
	local cf = CFrame.new(position)
	root.CFrame = cf
	torso.CFrame = cf
	head.CFrame = cf * CFrame.new(0, 2.9 * s, 0)
	for _, other in { torso, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = other
		weld.Parent = root
	end

	local maxHealth = math.max(1, math.floor(stats.Health * healthMultiplier))
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = s
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = stats.Speed
	humanoid.DisplayName = stats.Name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	humanoid.Parent = model

	-- параметры для ИИ и наград (атрибуты читаются RiftEnemyAI / RiftService)
	model:SetAttribute("RiftEnemy", true)
	model:SetAttribute("EnemyType", kind)
	model:SetAttribute("Damage", stats.Damage * damageMultiplier)
	model:SetAttribute("AttackRange", stats.AttackRange)
	model:SetAttribute("AttackCooldown", stats.AttackCooldown)
	model:SetAttribute("KillCrystals", stats.KillCrystals)

	model.PrimaryPart = root
	CollectionService:AddTag(model, CombatConfig.EnemyTag)
	model.Parent = parent
	root:SetNetworkOwner(nil) -- физику ведёт сервер
	return model
end

return EnemyFactory
