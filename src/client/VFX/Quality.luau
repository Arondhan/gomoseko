--!strict
-- Режим графики. Low (рекомендуется на телефонах) отключает декоративные источники света и частицы, тени и bloom;
-- High включает всё обратно. Работает только на клиенте (локально для игрока), карту на сервере не меняет.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local TorchFlicker = require(script.Parent:WaitForChild("TorchFlicker"))

local Quality = {}

-- Имена деталей-«якорей» генератора карты (server/BuildHub, server/Hub/Decor, Hub/Atmosphere)
local DECOR_LIGHT_PARENTS = { CaveLight = true, CliffLight = true, CrystalGlow = true }
local DECOR_EMITTER_PARENTS = { MoonDust = true, FireflyAnchor = true }

local lastLow: boolean? = nil

local function applyToMap(low: boolean)
	local hub = Workspace:FindFirstChild("MainHub")
	if not hub then
		return
	end
	for _, descendant in hub:GetDescendants() do
		local parent = descendant.Parent
		if descendant:IsA("PointLight") and parent and DECOR_LIGHT_PARENTS[parent.Name] then
			descendant.Enabled = not low
		elseif descendant:IsA("ParticleEmitter") and parent and DECOR_EMITTER_PARENTS[parent.Name] then
			descendant.Enabled = not low
		end
	end
end

-- Включён ли режим Low graphics (для эффектов: меньше частиц и света)
function Quality.isLow(): boolean
	return lastLow == true
end

function Quality.apply(low: boolean)
	lastLow = low
	Lighting.GlobalShadows = not low
	for _, child in Lighting:GetChildren() do
		if child:IsA("BloomEffect") then
			child.Enabled = not low
		end
	end
	TorchFlicker.setEnabled(not low)
	applyToMap(low)

	-- карта строится сервером чуть позже входа: применяем ещё раз, когда MainHub появится
	if not Workspace:FindFirstChild("MainHub") then
		task.spawn(function()
			local hub = Workspace:WaitForChild("MainHub", 30)
			if hub and lastLow == low then
				applyToMap(low)
			end
		end)
	end
end

return Quality
