-- Меню справа внизу: Character (C), Inventory (I), Summon (G), Store (B) в золотой рамке, с процедурными
-- пиктограммами, свечением при наведении и подсказкой (общий Tooltip). Summon можно скрыть (options.summon = false).

local Chrome = require(script.Parent.Chrome)
local Glyphs = require(script.Parent.Glyphs)
local Theme = require(script.Parent.Theme)

local MicroMenu = {}

local BUTTON_SIZE = 42

-- tooltip — общий Tooltip (ui/Tooltip): показываем название и клавишу
function MicroMenu.build(parent: Instance, tooltip: any, options: { summon: boolean? }?)
	local showSummon = not options or options.summon ~= false
	local buttonCount = if showSummon then 4 else 3
	local menu = Chrome.panel(parent, {
		Name = "MicroMenu",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(buttonCount * BUTTON_SIZE + (buttonCount - 1) * 6 + 20, 62),
	}, 10)
	Chrome.diamond(menu, 8, UDim2.new(0, 6, 0, 6), 8)
	Chrome.diamond(menu, 8, UDim2.new(1, -6, 0, 6), 8)

	local row = Theme.new("Frame", { Name = "Buttons", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, menu)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)

	local function addButton(name: string, order: number, hotkey: string, tip: string, draw: (Instance) -> ())
		local frame, bevel = Chrome.slot(row, UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE), 7)
		frame.Name = name
		frame.LayoutOrder = order
		local glow = Chrome.glow(frame, Theme.GoldLight, 3)
		draw(frame)

		-- маленькая клавиша в углу
		Chrome.label(frame, {
			Position = UDim2.fromOffset(4, 1),
			Size = UDim2.fromOffset(14, 12),
			Text = hotkey,
			TextSize = 11,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 15,
		})
		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 30,
		}, frame)

		local button = { frame = frame, active = false, hotkey = hotkey, click = Instance.new("BindableEvent") }

		function button.setActive(active: boolean)
			button.active = active
			Chrome.tintBevel(bevel, if active then Theme.GoldLight else nil)
			Theme.tween(glow, 0.12, { Transparency = if active then 0.5 else 1 })
		end

		hit.MouseEnter:Connect(function()
			Theme.tween(glow, 0.12, { Transparency = 0.4 })
			tooltip.show(tip, "Hotkey: " .. hotkey, {}, Theme.GoldLight)
		end)
		hit.MouseLeave:Connect(function()
			Theme.tween(glow, 0.12, { Transparency = if button.active then 0.5 else 1 })
			tooltip.hide()
		end)
		hit.MouseButton1Click:Connect(function()
			button.click:Fire()
		end)
		return button
	end

	local result = {
		frame = menu,
		character = addButton("CharacterButton", 1, "C", "Character", Glyphs.character),
		inventory = addButton("InventoryButton", 2, "I", "Inventory", Glyphs.bag),
		shop = addButton("ShopButton", 4, "B", "Store", Glyphs.coin),
	}
	if showSummon then
		result.summon = addButton("SummonButton", 3, "G", "Summon", Glyphs.summon)
	end
	return result
end

return MicroMenu
