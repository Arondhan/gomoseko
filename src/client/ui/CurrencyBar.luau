--!strict
-- Полоска валют справа внизу над меню: золото, Summon Crystals, Ring Essence. Данные — атрибуты Player (ведёт сервер).

local Players = game:GetService("Players")

local Chrome = require(script.Parent.Chrome)
local Glyphs = require(script.Parent.Glyphs)
local Theme = require(script.Parent.Theme)

local CurrencyBar = {}

local ENTRIES: { { attribute: string, tip: string, glyph: (Instance) -> (), color: Color3 } } = {
	{ attribute = "Gold", tip = "Gold", glyph = Glyphs.coin, color = Theme.Coin },
	{ attribute = "Crystals", tip = "Summon Crystals", glyph = Glyphs.crystal, color = Color3.fromRGB(150, 200, 255) },
	{ attribute = "Essence", tip = "Ring Essence", glyph = Glyphs.essence, color = Color3.fromRGB(150, 240, 210) },
}

local ENTRY_WIDTH = 92

function CurrencyBar.build(parent: Instance, tooltip: any)
	local player = Players.LocalPlayer

	local bar = Chrome.panel(parent, {
		Name = "CurrencyBar",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -88),
		Size = UDim2.fromOffset(#ENTRIES * ENTRY_WIDTH + 14, 34),
	}, 8)

	local row = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, bar)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, row)

	for index, entry in ENTRIES do
		local holder = Theme.new("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(ENTRY_WIDTH, 28),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, row)
		local iconHolder = Theme.new("Frame", {
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(2, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, holder)
		entry.glyph(iconHolder)
		local label = Chrome.label(holder, {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -32, 1, 0),
			Text = "0",
			TextSize = 16,
			TextColor3 = entry.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		})
		local function refresh()
			local value = player:GetAttribute(entry.attribute)
			label.Text = tostring(if type(value) == "number" then value else 0)
		end
		player:GetAttributeChangedSignal(entry.attribute):Connect(refresh)
		refresh()

		holder.MouseEnter:Connect(function()
			tooltip.show(entry.tip, nil, {}, entry.color)
		end)
		holder.MouseLeave:Connect(function()
			tooltip.hide()
		end)
	end

	return { frame = bar }
end

return CurrencyBar
