-- Точка входа клиентского UI в стиле WoW (Dragonflight):
-- 4 слота для колец внизу по центру, меню (Инвентарь, Магазин) справа внизу.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ui = script.Parent:WaitForChild("ui")
local Theme = require(ui:WaitForChild("Theme"))
local RingBar = require(ui:WaitForChild("RingBar"))
local MicroMenu = require(ui:WaitForChild("MicroMenu"))
local Inventory = require(ui:WaitForChild("Inventory"))
local Shop = require(ui:WaitForChild("Shop"))

-- стандартный рюкзак мешает клавишам 1-4
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("HubUI")
if old then
	old:Destroy()
end

local gui = Theme.new("ScreenGui", {
	Name = "HubUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 10,
}, playerGui)

local ringBar = RingBar.build(gui)
local menu = MicroMenu.build(gui)

-- окна и привязка к кнопкам меню
local windows = {
	{ window = Inventory.build(gui), button = menu.inventory, key = Enum.KeyCode.I },
	{ window = Shop.build(gui), button = menu.shop, key = Enum.KeyCode.B },
}

for _, entry in windows do
	entry.button.click.Event:Connect(entry.window.toggle)
	entry.window.changed.Event:Connect(entry.button.setActive)
end

local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

UserInputService.InputBegan:Connect(function(input, processed)
	-- Esc закрывает окна даже если его обработал CoreGui
	if input.KeyCode == Enum.KeyCode.Escape then
		for _, entry in windows do
			entry.window.setOpen(false)
		end
		return
	end
	if processed then
		return
	end
	for i, key in slotKeys do
		if input.KeyCode == key then
			ringBar.press(i)
			return
		end
	end
	for _, entry in windows do
		if input.KeyCode == entry.key then
			entry.window.toggle()
			return
		end
	end
end)
