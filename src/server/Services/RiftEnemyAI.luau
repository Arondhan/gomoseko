--!strict
-- ИИ врагов Rift: ОДИН общий цикл на всех врагов (шаг STEP секунд). Каждый враг идёт к ближайшему живому игроку
-- в арене (прямая линия — арена открытая, без PathfindingService) и бьёт его ближним ударом по кулдауну.
-- Параметры берутся из атрибутов модели (Damage, AttackRange, AttackCooldown), см. Hub/EnemyFactory.

local RunService = game:GetService("RunService")

local RiftEnemyAI = {}

local STEP = 0.25

type Enemy = { model: Model, humanoid: Humanoid, root: BasePart, nextAttack: number }
export type Target = { player: Player, humanoid: Humanoid, root: BasePart }

local enemies: { [Model]: Enemy } = {}
local getTargets: () -> { Target } = function()
	return {}
end
local accumulator = 0

-- Откуда брать живых игроков в арене (задаёт RiftService)
function RiftEnemyAI.setTargetProvider(provider: () -> { Target })
	getTargets = provider
end

function RiftEnemyAI.register(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		enemies[model] = { model = model, humanoid = humanoid, root = root, nextAttack = 0 }
	end
end

function RiftEnemyAI.unregister(model: Model)
	enemies[model] = nil
end

-- Ускорить всех живых врагов (волна затянулась)
function RiftEnemyAI.enrage(multiplier: number)
	for _, enemy in enemies do
		enemy.humanoid.WalkSpeed *= multiplier
	end
end

local function nearest(position: Vector3, targets: { Target }): (Target?, number)
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local distance = (target.root.Position - position).Magnitude
		if distance < bestDistance then
			best = target
			bestDistance = distance
		end
	end
	return best, bestDistance
end

local function step()
	local targets = getTargets()
	local now = os.clock()
	for model, enemy in enemies do
		if enemy.humanoid.Health <= 0 or model.Parent == nil then
			enemies[model] = nil
			continue
		end
		local target, distance = nearest(enemy.root.Position, targets)
		if not target then
			enemy.humanoid:Move(Vector3.zero)
			continue
		end
		local range = (model:GetAttribute("AttackRange") :: number?) or 4.5
		if distance <= range then
			enemy.humanoid:Move(Vector3.zero)
			if now >= enemy.nextAttack then
				enemy.nextAttack = now + ((model:GetAttribute("AttackCooldown") :: number?) or 1.2)
				target.humanoid:TakeDamage((model:GetAttribute("Damage") :: number?) or 5)
			end
		else
			enemy.humanoid:MoveTo(target.root.Position)
		end
	end
end

function RiftEnemyAI.start()
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= STEP then
			accumulator = 0
			step()
		end
	end)
end

return RiftEnemyAI
