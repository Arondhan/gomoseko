-- Точка входа клиента: UI в стиле WoW (Dragonflight) и запуск контроллеров боя.
-- UI: фреймы игрока и цели (HP/мана), 4 слота для колец внизу по центру, меню (Инвентарь, Магазин) справа внизу.
-- Контроллеры: инвентарь колец, таргет, скиллы; VFX: отрисовка молнии.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Controllers = script.Parent:WaitForChild("Controllers")
local InventoryController = require(Controllers:WaitForChild("InventoryController"))
local TargetController = require(Controllers:WaitForChild("TargetController"))
local SkillController = require(Controllers:WaitForChild("SkillController"))
local LightningRenderer = require(script.Parent:WaitForChild("VFX"):WaitForChild("LightningRenderer"))
local DamageNumbers = require(script.Parent:WaitForChild("VFX"):WaitForChild("DamageNumbers"))

local ui = script.Parent:WaitForChild("ui")
local Theme = require(ui:WaitForChild("Theme"))
local RingBar = require(ui:WaitForChild("RingBar"))
local MicroMenu = require(ui:WaitForChild("MicroMenu"))
local Inventory = require(ui:WaitForChild("Inventory"))
local Shop = require(ui:WaitForChild("Shop"))
local PlayerFrame = require(ui:WaitForChild("PlayerFrame"))
local TargetFrame = require(ui:WaitForChild("TargetFrame"))
local Tooltip = require(ui:WaitForChild("Tooltip"))
local Notice = require(ui:WaitForChild("Notice"))
local XpBar = require(ui:WaitForChild("XpBar"))
local CastBar = require(ui:WaitForChild("CastBar"))

-- стандартный рюкзак мешает клавишам 1-4, а стандартная полоска здоровья дублирует PlayerFrame
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
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

PlayerFrame.build(gui)
local targetFrame = TargetFrame.build(gui)
local notice = Notice.build(gui)
XpBar.build(gui)
local castBar = CastBar.build(gui)
local tooltip = Tooltip.build(gui, SkillController.getSkill)

local ringBar = RingBar.build(gui, {
	onActivate = SkillController.castSlot, -- ЛКМ по слоту = нажатие его клавиши
	onUnequip = InventoryController.unequip, -- ПКМ по слоту снимает кольцо
	onHover = function(slot)
		local ring = if slot then InventoryController.getRingInSlot(slot) else nil
		if ring then
			tooltip.showRing(ring)
		else
			tooltip.hide()
		end
	end,
})
local menu = MicroMenu.build(gui, tooltip)

-- окна и привязка к кнопкам меню
local windows = {
	{
		window = Inventory.build(gui, { controller = InventoryController, ringBar = ringBar, tooltip = tooltip }),
		button = menu.inventory,
		key = Enum.KeyCode.I,
	},
	{ window = Shop.build(gui), button = menu.shop, key = Enum.KeyCode.B },
}

for _, entry in windows do
	entry.button.click.Event:Connect(entry.window.toggle)
	entry.window.changed.Event:Connect(entry.button.setActive)
end

-- кольца из состояния сервера -> иконки в слотах RingBar
InventoryController.changed.Event:Connect(function()
	tooltip.hide()
	for i = 1, ringBar.slotCount do
		ringBar.setSlot(i, InventoryController.getRingInSlot(i))
	end
end)

-- оверлей кулдауна на слотах (каждый кадр, только отображение)
RunService.RenderStepped:Connect(function()
	for i = 1, ringBar.slotCount do
		local ring = InventoryController.getRingInSlot(i)
		if ring then
			local remaining, total = SkillController.getCooldown(ring.SkillId)
			ringBar.setCooldown(i, remaining, total)
		else
			ringBar.setCooldown(i, 0, 0)
		end
	end
end)

-- таргет -> фрейм цели
TargetController.changed.Event:Connect(function(model)
	targetFrame.setTarget(model)
end)

-- cast bar следует за событиями скилл-контроллера
SkillController.castStarted.Event:Connect(castBar.start)
SkillController.castFinished.Event:Connect(castBar.finish)
SkillController.castCancelled.Event:Connect(castBar.cancel)

-- «ding» при повышении уровня (атрибут Level растёт на сервере)
local lastLevel = localPlayer:GetAttribute("Level")
localPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	local level = localPlayer:GetAttribute("Level")
	if type(level) == "number" and type(lastLevel) == "number" and level > lastLevel then
		notice.show("Новый уровень: " .. level .. "!", Theme.GoldLight)
	end
	lastLevel = level
end)

-- запуск контроллеров (они ждут ремоуты, которые создаёт server/Main)
InventoryController.start()
TargetController.start()
SkillController.start(notice.show, ringBar.press)
LightningRenderer.start()
DamageNumbers.start()

local slotKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

UserInputService.InputBegan:Connect(function(input, processed)
	-- Esc закрывает окна даже если его обработал CoreGui
	if input.KeyCode == Enum.KeyCode.Escape then
		for _, entry in windows do
			entry.window.setOpen(false)
		end
		TargetController.clear() -- как в WoW: Esc снимает цель
		return
	end
	if processed then
		return
	end
	for i, key in slotKeys do
		if input.KeyCode == key then
			ringBar.press(i)
			SkillController.castSlot(i)
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
