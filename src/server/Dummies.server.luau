-- Training dummies (DPS arena): they never die — damage is counted by DpsService.
-- BuildHub creates the models in Workspace.MainHub.Dummies; here we only set up the label above each head.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- wait for BuildHub to finish the map (otherwise we could bind to a stale MainHub from a saved place)
while not Workspace:GetAttribute("HubReady") do
	Workspace:GetAttributeChangedSignal("HubReady"):Wait()
end
local folder = Workspace.MainHub:WaitForChild("Dummies")

for _, model in folder:GetChildren() do
	if model:IsA("Model") then
		local head = model:FindFirstChild("Head")
		local gui = head and head:FindFirstChild("HPBar")
		local label = gui and gui:FindFirstChild("Label")
		local back = gui and gui:FindFirstChild("Back")
		if label and label:IsA("TextLabel") then
			label.Text = "Training Dummy"
			label.Size = UDim2.new(1, 0, 0, 20)
		end
		if back and back:IsA("GuiObject") then
			back.Visible = false -- health bar makes no sense: the dummy is immortal
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = Config.Dummies.MaxHealth
			humanoid.Health = humanoid.MaxHealth
		end
	end
end
