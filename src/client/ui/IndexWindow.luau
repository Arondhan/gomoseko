--!strict
-- Окно «Ring Index» (книга колец): все кольца игры по возрастанию редкости; найденные показывают иконку, название
-- и «1 in N», ненайденные — тёмный силуэт и «???» (редкость не скрываем: честно видно, что это 1 in N).
-- Сверху прогресс коллекции, снизу награды за 25 / 50 / 100 %. Данные — IndexController (решает сервер).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GachaMath = require(Shared:WaitForChild("Gacha"):WaitForChild("GachaMath"))
local IndexMath = require(Shared:WaitForChild("Gacha"):WaitForChild("IndexMath"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))

local Chrome = require(script.Parent.Chrome)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local IndexWindow = {}

local CARD_W, CARD_H, GAP = 118, 138, 8

-- deps: { index = IndexController, tooltip = Tooltip, notify = (text, color?) -> () }
function IndexWindow.build(parent: Instance, deps: any)
	local index = deps.index
	local tooltip = deps.tooltip
	local notify: (string, Color3?) -> () = deps.notify

	local window = Window.new(parent, {
		name = "IndexWindow",
		title = "Ring Index",
		size = UDim2.fromOffset(580, 600),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	-- прогресс коллекции
	local progressLabel = Chrome.label(body, {
		Size = UDim2.new(1, 0, 0, 26),
		Text = "Collected: 0 / 0",
		FontFace = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Header,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local track = Theme.new("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Color3.fromRGB(10, 11, 15),
		BorderSizePixel = 0,
	}, body)
	Theme.corner(track, 7)
	Chrome.bevel(track, 1.5, 7, true)
	local fill = Theme.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.GoldMid,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	Theme.corner(fill, 7)
	Theme.gradient(fill, 90, Theme.GoldLight, Theme.GoldDark)

	-- сетка колец (статичная: карточки создаются один раз, потом только обновляются)
	local list = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54 - 112),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.GoldMid,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body)
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	local rings = table.clone(RingsConfig.List)
	table.sort(rings, function(a, b)
		return a.OneIn < b.OneIn
	end)

	local cards: { [string]: { cover: Frame, name: TextLabel, tag: TextLabel, bevel: UIStroke, def: any } } = {}
	local discoveredSet: { [string]: boolean } = {}
	for order, ring in rings do
		local color = Theme.Quality[ring.Quality] or Theme.Quality.Common
		local card, bevel = Chrome.slot(list, UDim2.fromOffset(CARD_W, CARD_H), 7)
		card.Name = ring.Id
		card.LayoutOrder = order
		local iconHolder = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(68, 68),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, card)
		RingIcon.new(iconHolder, ring)
		-- силуэт: тёмная плашка поверх иконки + «?»
		local cover = Theme.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(8, 9, 12),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			ZIndex = 20,
		}, iconHolder)
		Theme.corner(cover, 34)
		Chrome.label(cover, {
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			FontFace = Theme.Fonts.Banner,
			TextSize = Theme.TextSize.Title,
			TextColor3 = Theme.Muted,
			ZIndex = 21,
		})
		local name = Chrome.label(card, {
			Position = UDim2.fromOffset(4, 80),
			Size = UDim2.new(1, -8, 0, 34),
			Text = "???",
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Muted,
			TextWrapped = true,
			ZIndex = 4,
		})
		local tag = Chrome.label(card, {
			Position = UDim2.fromOffset(4, 114),
			Size = UDim2.new(1, -8, 0, 20),
			Text = GachaMath.formatOneIn(ring.OneIn),
			FontFace = Theme.Fonts.Numbers,
			TextSize = Theme.TextSize.Small - 1,
			TextColor3 = color,
			ZIndex = 4,
		})
		cards[ring.Id] = { cover = cover, name = name, tag = tag, bevel = bevel, def = ring }

		card.MouseEnter:Connect(function()
			if discoveredSet[ring.Id] then
				tooltip.showRing(ring)
			else
				tooltip.show(
					"Undiscovered ring",
					ring.Quality,
					{ "Base rarity: " .. GachaMath.formatOneIn(ring.OneIn) },
					color
				)
			end
		end)
		card.MouseLeave:Connect(function()
			tooltip.hide()
		end)
	end

	-- награды за вехи (три кнопки внизу)
	local rewardButtons: { { button: TextButton, label: TextLabel, gradient: UIGradient, percent: number } } = {}
	local rewardsRow = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundTransparency = 1,
	}, body)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, rewardsRow)
	local milestoneCount = #deps.milestones
	for order, percent in deps.milestones do
		local button = Theme.new("TextButton", {
			LayoutOrder = order,
			Size = UDim2.new(1 / milestoneCount, -8, 0, 86),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 5,
		}, rewardsRow)
		Theme.corner(button, 8)
		local gradient = Theme.gradient(button, 90, Color3.fromRGB(60, 54, 44), Color3.fromRGB(30, 28, 24))
		Chrome.bevel(button, 2, 8, true)
		local label = Chrome.label(button, {
			Size = UDim2.fromScale(1, 1),
			Text = "",
			FontFace = Theme.Fonts.Title,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.GoldLight,
			TextWrapped = true,
			ZIndex = 6,
		})
		table.insert(rewardButtons, { button = button, label = label, gradient = gradient, percent = percent })
		button.MouseButton1Click:Connect(function()
			task.spawn(function()
				local ok, reason = index.claim(percent)
				if ok then
					notify(string.format("Index reward claimed: %d%%!", percent), Theme.GoldLight)
				elseif reason then
					notify(reason)
				end
			end)
		end)
	end

	local function render()
		local state = index.getState()
		if not state then
			return
		end
		table.clear(discoveredSet)
		for _, id in state.discovered do
			discoveredSet[id] = true
		end
		for id, card in cards do
			local found = discoveredSet[id] == true
			local color = Theme.Quality[card.def.Quality] or Theme.Quality.Common
			card.cover.Visible = not found
			card.name.Text = if found then card.def.Name else "???"
			card.name.TextColor3 = if found then color else Theme.Muted
			Chrome.tintBevel(card.bevel, if found then color else nil)
		end
		local count = #state.discovered
		progressLabel.Text = string.format(
			"Collected: %d / %d  (%d%%)",
			count,
			state.total,
			math.floor(IndexMath.percent(count, state.total))
		)
		fill.Size = UDim2.fromScale(IndexMath.percent(count, state.total) / 100, 1)

		for i, entry in rewardButtons do
			local milestone = state.milestones[i]
			if milestone then
				local rewardText = string.format("%d Crystals", milestone.crystals)
				if milestone.essence > 0 then
					rewardText ..= string.format(" + %d Essence", milestone.essence)
				end
				if milestone.claimed then
					entry.label.Text = string.format("%d%%\nClaimed", milestone.percent)
					entry.gradient.Color = ColorSequence.new(Color3.fromRGB(70, 110, 60), Color3.fromRGB(36, 60, 32))
				elseif milestone.reached then
					entry.label.Text = string.format("%d%% — CLAIM!\n%s", milestone.percent, rewardText)
					entry.gradient.Color = ColorSequence.new(Color3.fromRGB(150, 112, 40), Color3.fromRGB(80, 56, 18))
				else
					entry.label.Text =
						string.format("%d%% (%d rings)\n%s", milestone.percent, milestone.need, rewardText)
					entry.gradient.Color = ColorSequence.new(Color3.fromRGB(60, 54, 44), Color3.fromRGB(30, 28, 24))
				end
			end
		end
	end
	index.changed.Event:Connect(render)
	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(index.refresh)
			render()
		end
	end)
	render()

	return window
end

return IndexWindow
