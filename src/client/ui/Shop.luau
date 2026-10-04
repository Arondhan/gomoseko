--!strict
-- Окно «Store» (Robux): пачки Summon Crystals, зелья удачи и геймпассы. Состояние приходит с сервера (StoreGetState),
-- покупку запускает сервер (StoreBuy -> PromptProductPurchase / PromptGamePassPurchase). Цены берутся у Roblox
-- (MarketplaceService:GetProductInfo). Для товаров с ID 0 (не настроены в Creator Hub) кнопка неактивна; в Studio
-- есть «Test Grant» — выдать товар без Robux для проверки.
-- Политика Roblox «Paid Random Items»: кристаллы и бусты удачи связаны со случайным призывом, поэтому над списком —
-- ссылка на таблицу шансов (окно Summon → Odds / Details); для регионов с запретом платные товары скрыты.

local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Chrome = require(script.Parent.Chrome)
local Glyphs = require(script.Parent.Glyphs)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Shop = {}

local ROW_HEIGHT = 92

local GLYPHS: { [string]: (Instance) -> () } = {
	Crystals = Glyphs.crystal,
	LuckPotion = Glyphs.potion,
	Pass = Glyphs.summon,
}

local SECTIONS: { { kind: string, title: string } } = {
	{ kind = "Crystals", title = "Summon Crystals" },
	{ kind = "LuckPotion", title = "Luck Potions" },
	{ kind = "Pass", title = "Passes" },
}

local priceCache: { [string]: string } = {}

-- Цена в Robux у Roblox (асинхронно); пока не пришла — «…»
local function fetchPrice(item: Types.StoreItem, label: TextLabel)
	if item.id == 0 then
		label.Text = "—"
		return
	end
	local cacheKey = (if item.isPass then "p" else "d") .. item.id
	if priceCache[cacheKey] then
		label.Text = priceCache[cacheKey]
		return
	end
	label.Text = "…"
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(
				item.id,
				if item.isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
		end)
		if ok and type(info) == "table" and info.PriceInRobux then
			priceCache[cacheKey] = "R$ " .. tostring(info.PriceInRobux)
		else
			priceCache[cacheKey] = "—"
		end
		if label.Parent then
			label.Text = priceCache[cacheKey]
		end
	end)
end

-- deps: { notify = (text, color?) -> (), openOdds = () -> (), gacha = GachaController }
function Shop.build(parent: Instance, deps: any)
	local window = Window.new(parent, {
		name = "ShopWindow",
		title = "Store",
		size = UDim2.fromOffset(440, 580),
		position = UDim2.new(0.74, 0, 0.47, 0),
	})

	local noteLabel = Chrome.label(window.body, {
		Size = UDim2.new(1, -130, 0, 44),
		Text = "Crystals and luck boosts are used for Ring Summon, a random-ring feature. See the exact odds before you buy.",
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local oddsButton = Theme.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(120, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "View odds",
		FontFace = Theme.Fonts.Title,
		TextSize = 14,
		TextColor3 = Theme.GoldLight,
		ZIndex = 5,
	}, window.body)
	Theme.corner(oddsButton, 6)
	Theme.gradient(oddsButton, 90, Color3.fromRGB(110, 84, 36), Color3.fromRGB(58, 42, 16))
	Chrome.bevel(oddsButton, 2, 6, true)
	oddsButton.MouseButton1Click:Connect(function()
		deps.openOdds()
	end)

	local list = Theme.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.GoldMid,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, window.body)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local stateRemote = Remotes.get("StoreGetState") :: RemoteFunction
	local buyRemote = Remotes.get("StoreBuy") :: RemoteFunction
	local grantRemote = Remotes.get("StudioGrant") :: RemoteFunction

	local function clear()
		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	local function addHeader(order: number, text: string)
		Chrome.label(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 26),
			Text = text,
			FontFace = Theme.Fonts.Title,
			TextSize = 16,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local function addRow(order: number, item: Types.StoreItem, studio: boolean)
		local row = Chrome.panel(list, {
			Name = item.key,
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
		}, 6)

		local iconSlot = Chrome.slot(row, UDim2.fromOffset(48, 48), 6)
		iconSlot.Position = UDim2.fromOffset(10, 10)
		local drawGlyph = GLYPHS[item.kind]
		if drawGlyph then
			drawGlyph(iconSlot)
		end

		Chrome.label(row, {
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -176, 0, 20),
			Text = item.name,
			FontFace = Theme.Fonts.Title,
			TextSize = 15,
			TextColor3 = Theme.GoldLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		Chrome.label(row, {
			Position = UDim2.fromOffset(68, 30),
			Size = UDim2.new(1, -176, 0, ROW_HEIGHT - 36),
			Text = item.description,
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
		})

		local price = Chrome.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(90, 18),
			Text = "",
			TextSize = 14,
			TextColor3 = Theme.Coin,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
		})
		fetchPrice(item, price)

		local canBuy = item.id ~= 0 and not item.owned
		local buy = Theme.new("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 30),
			Size = UDim2.fromOffset(90, 28),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = if item.owned then "Owned" elseif item.id == 0 then "Not set up" else "Buy",
			FontFace = Theme.Fonts.Title,
			TextSize = 14,
			TextColor3 = if canBuy then Theme.GoldLight else Theme.Muted,
			ZIndex = 5,
		}, row)
		Theme.corner(buy, 6)
		Theme.gradient(
			buy,
			90,
			if canBuy then Color3.fromRGB(110, 84, 36) else Color3.fromRGB(58, 58, 62),
			if canBuy then Color3.fromRGB(58, 42, 16) else Color3.fromRGB(32, 32, 36)
		)
		Chrome.bevel(buy, 2, 6, true)
		buy.MouseButton1Click:Connect(function()
			if not canBuy then
				return
			end
			local ok, success, reason = pcall(function()
				return buyRemote:InvokeServer(item.key)
			end)
			if ok and success == false then
				deps.notify(tostring(reason or "Purchase unavailable"))
			end
		end)

		if studio then
			local test = Theme.new("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 62),
				Size = UDim2.fromOffset(90, 22),
				BackgroundColor3 = Color3.fromRGB(40, 70, 50),
				BorderSizePixel = 0,
				Text = "Test Grant",
				FontFace = Theme.Fonts.Body,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(190, 255, 200),
				ZIndex = 5,
			}, row)
			Theme.corner(test, 5)
			test.MouseButton1Click:Connect(function()
				pcall(function()
					grantRemote:InvokeServer(item.key)
				end)
				task.spawn(deps.gacha.refresh)
				deps.notify("Granted: " .. item.name, Theme.Good)
			end)
		end
	end

	local function render(state: Types.StoreState)
		clear()
		oddsButton.Visible = not state.restricted
		if state.restricted then
			noteLabel.Size = UDim2.new(1, 0, 0, 44)
			noteLabel.Text = "Paid items related to random rewards are not available in your region."
			return
		end
		noteLabel.Size = UDim2.new(1, -130, 0, 44)
		noteLabel.Text =
			"Crystals and luck boosts are used for Ring Summon, a random-ring feature. See the exact odds before you buy."
		local order = 0
		for _, section in SECTIONS do
			order += 1
			addHeader(order, section.title)
			for _, item in state.items do
				if item.kind == section.kind then
					order += 1
					addRow(order, item, state.studio)
				end
			end
		end
	end

	local function refresh()
		local ok, state = pcall(function()
			return stateRemote:InvokeServer()
		end)
		if ok and type(state) == "table" then
			render(state)
		end
	end
	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(refresh)
		end
	end)

	return window
end

return Shop
