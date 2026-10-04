-- Логика тренировочных манекенов: урон (касание Tool / клик), HP-бар, респавн.
-- Модели манекенов создаёт BuildHub в Workspace.MainHub.Dummies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local settings = Config.Dummies

-- ждём, пока BuildHub закончит карту (иначе можно привязаться к устаревшему MainHub из сохранённого места)
while not Workspace:GetAttribute("HubReady") do
	Workspace:GetAttributeChangedSignal("HubReady"):Wait()
end
local folder = Workspace.MainHub:WaitForChild("Dummies")

local function bind(model: Model, template: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local torso = model:FindFirstChild("Torso")
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("HPBar")
	local back = gui and gui:FindFirstChild("Back")
	local fill = back and back:FindFirstChild("Fill")
	local label = gui and gui:FindFirstChild("Label")
	if not (hum and torso and fill and label) then
		return
	end

	local lastHit: { [Player]: number } = {}

	local function refresh()
		local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		fill.BackgroundColor3 = Color3.fromHSV(frac * 0.33, 0.8, 0.9)
		label.Text = "Training Dummy " .. math.ceil(hum.Health) .. "/" .. hum.MaxHealth
	end
	hum.HealthChanged:Connect(refresh)

	local function hurt(amount: number)
		if hum.Health > 0 then
			hum:TakeDamage(amount)
		end
	end

	torso.Touched:Connect(function(hit)
		local tool = hit:FindFirstAncestorOfClass("Tool")
		local plr = tool and Players:GetPlayerFromCharacter(tool.Parent)
		if not plr then
			return
		end
		local now = os.clock()
		if lastHit[plr] and now - lastHit[plr] < 0.5 then
			return
		end
		lastHit[plr] = now
		hurt(settings.TouchDamage)
	end)

	local click = torso:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MouseClick:Connect(function()
			hurt(settings.ClickDamage)
		end)
	end

	hum.Died:Connect(function()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Transparency = 0.75
			end
		end
		label.Text = "Respawning..."
		task.delay(settings.RespawnTime, function()
			local fresh = template:Clone()
			model:Destroy()
			fresh.Parent = folder
			bind(fresh, template)
		end)
	end)
end

for _, m in folder:GetChildren() do
	if m:IsA("Model") then
		bind(m, m:Clone())
	end
end
