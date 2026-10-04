--!strict
-- Предупреждение об ударе босса Rift: красный круг на земле, внутри растёт заполнение до момента удара, затем
-- короткая вспышка. Сервер присылает RiftTelegraph (position/radius/duration) и сам наносит урон по кругу; здесь
-- только картинка.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local RiftTelegraph = {}

local RED = Color3.fromRGB(255, 50, 40)

local function disc(position: Vector3, diameter: number, transparency: number): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = RED
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = Workspace
	return part
end

function RiftTelegraph.start()
	local remote = Remotes.get("RiftTelegraph") :: RemoteEvent
	remote.OnClientEvent:Connect(function(data: any)
		if
			type(data) ~= "table"
			or typeof(data.position) ~= "Vector3"
			or type(data.radius) ~= "number"
			or type(data.duration) ~= "number"
		then
			return
		end
		local radius = math.clamp(data.radius, 1, 60)
		local duration = math.clamp(data.duration, 0.2, 5)
		local position = data.position + Vector3.new(0, 0.15, 0)

		local outer = disc(position, radius * 2, 0.7)
		local fill = disc(position + Vector3.new(0, 0.05, 0), 2, 0.4)
		local grow = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Size = Vector3.new(0.3, radius * 2, radius * 2),
		})
		grow.Completed:Once(function()
			fill.Transparency = 0.1
			TweenService:Create(fill, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			TweenService:Create(outer, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end)
		grow:Play()
		Debris:AddItem(outer, duration + 0.6)
		Debris:AddItem(fill, duration + 0.6)
	end)
end

return RiftTelegraph
