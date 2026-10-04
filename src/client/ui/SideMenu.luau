--!strict
-- Меню слева: крупные цветные плитки с эмодзи и подписью (как на референсе): Summon, Rings, Index, Shop, Boost,
-- Ranks, Settings (и Admin — только для админов). Плитки по две в ряд. Красная точка («ping») — когда там что-то ждёт игрока (бесплатный ролл,
-- награда Index). У каждой кнопки: click (BindableEvent), setActive(bool), setPing(bool).

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local SideMenu = {}

local TILE = 70
local CELL_W, CELL_H = 88, 100

export type Button = {
	frame: Frame,
	click: BindableEvent,
	setActive: (boolean) -> (),
	setPing: (boolean) -> (),
}

-- tooltip — общий Tooltip (ui/Tooltip): показываем название и клавишу
function SideMenu.build(parent: Instance, tooltip: any)
	local menu = Theme.new("Frame", {
		Name = "SideMenu",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 172),
		Size = UDim2.fromOffset(CELL_W * 2 + 8, CELL_H * 4 + 24),
		BackgroundTransparency = 1,
	}, parent)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL_W, CELL_H),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, menu)

	local function addButton(
		name: string,
		order: number,
		title: string,
		emoji: string,
		color: Color3,
		hotkey: string
	): Button
		local cell = Theme.new("Frame", { Name = name, LayoutOrder = order, BackgroundTransparency = 1 }, menu)
		local tile = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(TILE, TILE),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, cell)
		Theme.corner(tile, 16)
		Theme.gradient(tile, 90, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25))
		local bevel = Chrome.bevel(tile, 2, 16)
		local scale = Theme.new("UIScale", { Scale = 1 }, tile)
		local glow = Chrome.glow(tile, Color3.new(1, 1, 1), 4)

		Theme.new("TextLabel", {
			Name = "Emoji",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = emoji,
			TextSize = 40,
			Font = Enum.Font.SourceSansBold,
			ZIndex = 3,
		}, tile)
		Chrome.label(cell, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TILE + 4),
			Size = UDim2.new(1, 0, 0, 22),
			Text = title,
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Color3.new(1, 1, 1),
		})

		-- красная точка «тут что-то ждёт»
		local ping = Theme.new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(255, 50, 50),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 8,
		}, tile)
		Theme.corner(ping, 11)
		Theme.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, ping)
		Chrome.label(ping, {
			Size = UDim2.fromScale(1, 1),
			Text = "!",
			TextSize = 16,
			TextStrokeTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 9,
		})

		local hit = Theme.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 30,
		}, cell)

		local button = {
			frame = cell,
			active = false,
			click = Instance.new("BindableEvent"),
		}
		function button.setActive(active: boolean)
			button.active = active
			Chrome.tintBevel(bevel, if active then Theme.GoldLight else nil)
			Theme.tween(glow, 0.12, { Transparency = if active then 0.3 else 1 })
		end
		function button.setPing(on: boolean)
			ping.Visible = on
		end

		hit.MouseEnter:Connect(function()
			Theme.tween(scale, 0.1, { Scale = 1.08 })
			tooltip.show(title, "Hotkey: " .. hotkey, {}, color)
		end)
		hit.MouseLeave:Connect(function()
			Theme.tween(scale, 0.1, { Scale = 1 })
			tooltip.hide()
		end)
		hit.MouseButton1Down:Connect(function()
			Theme.tween(scale, 0.06, { Scale = 0.92 })
		end)
		hit.MouseButton1Up:Connect(function()
			Theme.tween(scale, 0.1, { Scale = 1.08 })
		end)
		hit.MouseButton1Click:Connect(function()
			button.click:Fire()
		end)
		return button :: any
	end

	local T = Theme.Tiles
	local buttons = {
		frame = menu,
		summon = addButton("SummonButton", 1, "Summon", "🔮", T.Summon, "G"),
		rings = addButton("RingsButton", 2, "Rings", "💍", T.Rings, "C / I"),
		index = addButton("IndexButton", 3, "Index", "📖", T.Index, "N"),
		shop = addButton("ShopButton", 4, "Shop", "🛒", T.Shop, "B"),
		boost = addButton("BoostButton", 5, "Boost", "🍀", T.Boost, "V"),
		ranks = addButton("RanksButton", 6, "Ranks", "🏆", T.Ranks, "L"),
		settings = addButton("SettingsButton", 7, "Settings", "⚙️", T.Settings, "O"),
		admin = addButton("AdminButton", 8, "Admin", "🛠️", T.Admin, "F2"),
	}
	buttons.admin.frame.Visible = false -- плитка Admin появляется только у админов (Main после AdminGet)
	return buttons
end

return SideMenu
