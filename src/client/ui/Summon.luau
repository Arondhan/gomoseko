--!strict
-- Окно «Ring Summon» (Gacha): баннер с порталом, удача, кнопки призыва ×1 / ×10, бесплатный ролл с таймером,
-- авто-ролл (пасс), кнопка «Odds / Details» с полной таблицей шансов (проценты, сумма ровно 100 %) и анимация открытия
-- с карточками колец. Вся логика (списание, бросок, выдача) — на сервере (GachaService); здесь только показ и ввод.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GachaMath = require(Shared:WaitForChild("Gacha"):WaitForChild("GachaMath"))
local RingsConfig = require(Shared:WaitForChild("Configs"):WaitForChild("Rings"):WaitForChild("RingsConfig"))
local GachaConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GachaConfig"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local VFX = script.Parent.Parent:WaitForChild("VFX")
local Haptics = require(VFX:WaitForChild("Haptics"))
local RareCutscene = require(VFX:WaitForChild("RareCutscene"))
local Sfx = require(VFX:WaitForChild("Sfx"))

local Chrome = require(script.Parent.Chrome)
local RingIcon = require(script.Parent.RingIcon)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Summon = {}

local QUALITY_RANK: { [string]: number } =
	{ Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Divine = 7 }
local AUTO_STOP_RANK = 4 -- авто-ролл останавливается на Epic и лучше
local PURPLE = Color3.fromRGB(150, 90, 240)

local function rank(quality: string): number
	return QUALITY_RANK[quality] or 1
end

local function qualityColor(quality: string): Color3
	return Theme.Quality[quality] or Theme.Quality.Common
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

-- Золотая кнопка с двумя строками (заголовок + подзаголовок)
local function makeButton(parent: Instance, size: UDim2, position: UDim2, title: string, subtitle: string?)
	local button = Theme.new("TextButton", {
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
	}, parent)
	Theme.corner(button, 8)
	local gradient = Theme.gradient(button, 90, Theme.ButtonTop, Theme.ButtonBottom)
	Chrome.bevel(button, 2, 8, true)
	local glow = Chrome.glow(button, Theme.GoldLight, 3)

	local titleLabel = Chrome.label(button, {
		Size = UDim2.new(1, 0, 0, if subtitle then 24 else 0),
		Position = UDim2.fromOffset(0, if subtitle then 6 else 0),
		Text = title,
		FontFace = Theme.Fonts.Title,
		TextSize = 19,
		TextColor3 = Theme.GoldLight,
		ZIndex = 6,
	})
	if not subtitle then
		titleLabel.Size = UDim2.fromScale(1, 1)
	end
	local subLabel = Chrome.label(button, {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 30),
		Text = subtitle or "",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(150, 210, 255),
		ZIndex = 6,
		Visible = subtitle ~= nil,
	})

	local api = { frame = button, enabled = true, click = Instance.new("BindableEvent") }
	function api.setEnabled(enabled: boolean)
		api.enabled = enabled
		button.Active = enabled
		gradient.Color = if enabled
			then ColorSequence.new(Theme.ButtonTop, Theme.ButtonBottom)
			else ColorSequence.new(Color3.fromRGB(58, 58, 62), Color3.fromRGB(32, 32, 36))
		titleLabel.TextTransparency = if enabled then 0 else 0.45
		subLabel.TextTransparency = if enabled then 0 else 0.45
	end
	function api.setTexts(newTitle: string, newSubtitle: string?)
		titleLabel.Text = newTitle
		subLabel.Text = newSubtitle or ""
	end
	button.MouseEnter:Connect(function()
		if api.enabled then
			Theme.tween(glow, 0.1, { Transparency = 0.45 })
		end
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(glow, 0.1, { Transparency = 1 })
	end)
	button.MouseButton1Click:Connect(function()
		if api.enabled then
			api.click:Fire()
		end
	end)
	return api
end

-- deps: { gacha = GachaController, tooltip = Tooltip, notify = (text, color?) -> (), settings = SettingsController }
function Summon.build(parent: Instance, deps: any)
	local settings = deps.settings
	local gacha = deps.gacha
	local tooltip = deps.tooltip
	local notify: (string, Color3?) -> () = deps.notify

	local window = Window.new(parent, {
		name = "SummonWindow",
		title = "Ring Summon",
		size = UDim2.fromOffset(540, 580),
		position = UDim2.new(0.5, 0, 0.47, 0),
	})
	local body = window.body

	---------------------------------------------------------------------------
	-- Баннер: вращающиеся кольца портала вокруг орба
	---------------------------------------------------------------------------
	local banner = Theme.new("Frame", {
		Name = "Banner",
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, body)
	Theme.corner(banner, 8)
	Theme.gradient(banner, 90, Color3.fromRGB(58, 34, 96), Color3.fromRGB(14, 10, 28))
	Chrome.bevel(banner, 2, 8, true)

	local spinning: { { gradient: UIGradient, speed: number } } = {}
	for index, ringSize in { 150, 112, 76 } do
		local ring = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(ringSize, ringSize),
			BackgroundTransparency = 1,
		}, banner)
		Theme.corner(ring, 999)
		local stroke = Theme.new("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Thickness = 4 - index * 0.6,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ring)
		local gradient = Theme.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.GoldLight),
				ColorSequenceKeypoint.new(0.35, PURPLE),
				ColorSequenceKeypoint.new(0.7, Color3.fromRGB(90, 170, 255)),
				ColorSequenceKeypoint.new(1, Theme.GoldLight),
			}),
		}, stroke)
		table.insert(spinning, { gradient = gradient, speed = (if index % 2 == 0 then -1 else 1) * (40 + index * 25) })
	end
	local orb = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, banner)
	Theme.corner(orb, 999)
	Theme.gradient(orb, 90, Color3.fromRGB(240, 220, 255), PURPLE)
	Theme.new("UIStroke", { Color = Theme.GoldLight, Thickness = 2 }, orb)
	local orbScale = Theme.new("UIScale", { Scale = 1 }, orb)
	task.spawn(function()
		-- мягкое «дыхание» орба, пока окно открыто
		while banner.Parent do
			TweenService:Create(orbScale, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Scale = 1.25 }):Play()
			task.wait(1.1)
			TweenService:Create(orbScale, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Scale = 0.9 }):Play()
			task.wait(1.1)
		end
	end)
	Chrome.label(banner, {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "RING SUMMON",
		FontFace = Theme.Fonts.Banner,
		TextSize = 26,
		TextColor3 = Theme.GoldLight,
		ZIndex = 6,
	})
	Chrome.label(banner, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Every ring is a 1-in-N find",
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(210, 200, 240),
		ZIndex = 6,
	})
	local spinConnection = RunService.RenderStepped:Connect(function(dt)
		if window.isOpen then
			for _, entry in spinning do
				entry.gradient.Rotation = (entry.gradient.Rotation + entry.speed * dt) % 360
			end
		end
	end)
	banner.Destroying:Once(function()
		spinConnection:Disconnect()
	end)

	---------------------------------------------------------------------------
	-- Удача и «Odds / Details»
	---------------------------------------------------------------------------
	local luckLabel = Chrome.label(body, {
		Position = UDim2.fromOffset(0, 186),
		Size = UDim2.fromOffset(300, 26),
		Text = "Your Luck: ×1.00",
		FontFace = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = Theme.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	luckLabel.Active = true
	luckLabel.MouseEnter:Connect(function()
		local state = gacha.getState()
		if not state then
			return
		end
		local lines: { string } = {}
		for _, source in state.luckSources do
			table.insert(lines, string.format("%s: +%g%%", source.name, source.percent))
		end
		if #lines == 0 then
			table.insert(lines, "No luck bonuses active.")
		end
		table.insert(lines, "Luck multiplies the chance of every ring except the most common one.")
		tooltip.show(string.format("Luck ×%.2f", state.luck), nil, lines, Theme.Good)
	end)
	luckLabel.MouseLeave:Connect(function()
		tooltip.hide()
	end)

	local oddsButton = makeButton(body, UDim2.fromOffset(150, 28), UDim2.new(1, -150, 0, 185), "Odds / Details", nil)
	oddsButton.frame.ZIndex = 5

	local currencyLabel = Chrome.label(body, {
		Position = UDim2.fromOffset(0, 214),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	---------------------------------------------------------------------------
	-- Кнопки призыва
	---------------------------------------------------------------------------
	local single = makeButton(body, UDim2.new(0.5, -6, 0, 58), UDim2.fromOffset(0, 242), "Summon ×1", "10 Crystals")
	local multi = makeButton(body, UDim2.new(0.5, -6, 0, 58), UDim2.new(0.5, 6, 0, 242), "Summon ×10", "100 Crystals")
	local free = makeButton(body, UDim2.new(0.6, -6, 0, 46), UDim2.fromOffset(0, 312), "Free Roll", nil)
	local auto = makeButton(body, UDim2.new(0.4, -6, 0, 46), UDim2.new(0.6, 6, 0, 312), "Auto Roll: Off", nil)

	local noteLabel = Chrome.label(body, {
		Position = UDim2.fromOffset(0, 366),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextColor3 = Theme.Warn,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local lastLabel = Chrome.label(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 16,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local totalLabel = Chrome.label(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	---------------------------------------------------------------------------
	-- Таблица шансов (Odds / Details)
	---------------------------------------------------------------------------
	local oddsPanel = Chrome.panel(body, {
		Name = "OddsPanel",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 40,
	}, 8)
	Chrome.label(oddsPanel, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "Summon odds",
		FontFace = Theme.Fonts.Title,
		TextSize = 20,
		TextColor3 = Theme.GoldLight,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
	})
	local oddsNote = Chrome.label(oddsPanel, {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "",
		FontFace = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = Theme.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 42,
	})
	local oddsList = Theme.new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 72),
		Size = UDim2.new(1, -20, 1, -118),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.GoldMid,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 42,
	}, oddsPanel)
	Theme.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }, oddsList)
	local oddsBack = makeButton(oddsPanel, UDim2.fromOffset(120, 32), UDim2.new(1, -132, 1, -40), "Back", nil)
	oddsBack.frame.ZIndex = 45
	local oddsTotal = Chrome.label(oddsPanel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -160, 0, 22),
		Text = "Total: 100%",
		FontFace = Theme.Fonts.Numbers,
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 42,
	})
	local _ = oddsTotal

	local function renderOdds()
		local state = gacha.getState()
		for _, child in oddsList:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		if not state then
			return
		end
		oddsNote.Text = string.format(
			"Shown for your current Luck ×%.2f. The most common ring takes the remaining chance. All chances add up to exactly 100%%.",
			state.luck
		)
		local order = 0
		for _, group in state.odds do
			order += 1
			local header = Theme.new("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 26),
				BackgroundTransparency = 1,
				ZIndex = 43,
			}, oddsList)
			Chrome.label(header, {
				Size = UDim2.new(0.5, 0, 1, 0),
				Text = group.quality,
				FontFace = Theme.Fonts.Title,
				TextSize = 17,
				TextColor3 = qualityColor(group.quality),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 44,
			})
			Chrome.label(header, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
				Text = group.percent .. "%",
				TextSize = 16,
				TextColor3 = qualityColor(group.quality),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 44,
			})
			for _, ring in group.rings do
				order += 1
				local row = Theme.new("Frame", {
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 20),
					BackgroundTransparency = 1,
					ZIndex = 43,
				}, oddsList)
				Chrome.label(row, {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(0.45, -12, 1, 0),
					Text = ring.name,
					FontFace = Theme.Fonts.Body,
					TextSize = 15,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 44,
				})
				Chrome.label(row, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0.55, 0, 1, 0),
					Text = string.format("%s%%   ·   %s", ring.percent, ring.effective),
					FontFace = Theme.Fonts.Body,
					TextSize = 15,
					TextColor3 = Color3.new(1, 1, 1),
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 44,
				})
			end
		end
	end

	local function openOdds()
		window.setOpen(true)
		task.spawn(function()
			gacha.refresh()
			renderOdds()
		end)
		renderOdds()
		oddsPanel.Visible = true
	end
	oddsButton.click.Event:Connect(openOdds)
	oddsBack.click.Event:Connect(function()
		oddsPanel.Visible = false
	end)

	---------------------------------------------------------------------------
	-- Анимация открытия: заряд орба -> вспышка -> карточки колец
	---------------------------------------------------------------------------
	local overlay = Theme.new("Frame", {
		Name = "SummonReveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 150,
	}, parent)

	local function clearOverlay()
		for _, child in overlay:GetChildren() do
			child:Destroy()
		end
	end

	local function flash(color: Color3, strength: number)
		local f = Theme.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = 1 - strength,
			BorderSizePixel = 0,
			ZIndex = 190,
		}, overlay)
		Theme.tween(f, 0.6, { BackgroundTransparency = 1 })
		task.delay(0.7, function()
			f:Destroy()
		end)
	end

	-- искры, разлетающиеся от центра (количество растёт с редкостью)
	local function burst(color: Color3, count: number)
		for _ = 1, count do
			local size = math.random(6, 14)
			local spark = Theme.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.5),
				BorderSizePixel = 0,
				Rotation = math.random(0, 90),
				ZIndex = 188,
			}, overlay)
			local angle = math.random() * math.pi * 2
			local distance = math.random(160, 460)
			local time = 0.6 + math.random() * 0.5
			TweenService:Create(spark, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(2, 2),
			}):Play()
			task.delay(time + 0.1, function()
				spark:Destroy()
			end)
		end
	end

	-- расходящееся кольцо-ударная волна
	local function shockwave(color: Color3)
		local ring = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 30),
			BackgroundTransparency = 1,
			ZIndex = 187,
		}, overlay)
		Theme.corner(ring, 999)
		local stroke = Theme.new("UIStroke", { Color = color, Thickness = 8 }, ring)
		TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(1100, 1100),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.7), { Thickness = 1, Transparency = 1 }):Play()
		task.delay(0.8, function()
			ring:Destroy()
		end)
	end

	-- число «1 in N» набегает от 1 до N (быстро, потом замедляется) — момент напряжения перед раскрытием
	local function countUp(label: TextLabel, prefix: string, target: number, time: number)
		local value = Instance.new("NumberValue")
		value.Value = 1
		value.Changed:Connect(function(v: number)
			if label.Parent then
				label.Text = prefix .. GachaMath.formatOneIn(math.max(1, math.floor(v)))
			end
		end)
		local tween = TweenService:Create(
			value,
			TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Value = target }
		)
		tween.Completed:Once(function()
			if label.Parent then
				label.Text = prefix .. GachaMath.formatOneIn(target)
			end
			value:Destroy()
		end)
		tween:Play()
	end

	-- щелчок раскрытия: высота тона растёт с номером карточки (последовательность «нарастает»)
	local function tickSound(index: number, volume: number)
		Sfx.play2D(Sounds.id("RevealTick"), volume, 0.01, math.min(2, 1 + (index - 1) * 0.06))
	end

	-- карточка кольца: back (рубашка) и front (лицо); возвращает функцию flip()
	local function makeCard(
		cardParent: Instance,
		result: Types.RollResult,
		width: number,
		height: number,
		position: UDim2,
		compact: boolean
	)
		local ring = RingsConfig.Rings[result.ringId]
		local color = qualityColor(result.quality)

		local holder = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromOffset(width, height),
			BackgroundTransparency = 1,
			ZIndex = 160,
		}, cardParent)

		local back = Chrome.panel(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 161,
		}, 8)
		Chrome.label(back, {
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			FontFace = Theme.Fonts.Banner,
			TextSize = if compact then 36 else 64,
			TextColor3 = Theme.GoldLight,
			ZIndex = 163,
		})

		local front = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Visible = false,
			ClipsDescendants = true,
			ZIndex = 161,
		}, holder)
		Theme.corner(front, 8)
		Theme.gradient(front, 90, color:Lerp(Color3.new(0, 0, 0), 0.65), Color3.fromRGB(14, 14, 20))
		local stroke = Chrome.bevel(front, 2, 8, true)
		Chrome.tintBevel(stroke, color)

		local iconSize = if compact then width * 0.7 else width * 0.62
		local iconHolder = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, if compact then 6 else 16),
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			ZIndex = 162,
		}, front)
		RingIcon.new(iconHolder, ring)

		local textTop = (if compact then 6 else 16) + iconSize + 4
		Chrome.label(front, {
			Position = UDim2.fromOffset(4, textTop),
			Size = UDim2.new(1, -8, 0, if compact then 30 else 40),
			Text = ring.Name,
			FontFace = Theme.Fonts.Title,
			TextSize = if compact then 13 else 18,
			TextColor3 = color,
			TextWrapped = true,
			ZIndex = 163,
		})
		Chrome.label(front, {
			Position = UDim2.fromOffset(4, textTop + (if compact then 30 else 40)),
			Size = UDim2.new(1, -8, 0, 16),
			Text = result.quality,
			TextSize = if compact then 13 else 15,
			TextColor3 = color,
			ZIndex = 163,
		})
		local tag = if result.isNew then "NEW!" else string.format("+%d Essence", result.essence)
		Chrome.label(front, {
			Position = UDim2.fromOffset(4, textTop + (if compact then 46 else 58)),
			Size = UDim2.new(1, -8, 0, 16),
			Text = tag,
			TextSize = if compact then 13 else 16,
			TextColor3 = if result.isNew then Theme.Good else Color3.fromRGB(150, 240, 210),
			ZIndex = 163,
		})
		local oddsLabel: TextLabel? = nil
		if not compact then
			oddsLabel = Chrome.label(front, {
				Position = UDim2.fromOffset(4, textTop + 78),
				Size = UDim2.new(1, -8, 0, 19),
				Text = "Base rarity: " .. GachaMath.formatOneIn(result.oneIn),
				FontFace = Theme.Fonts.Body,
				TextSize = 14,
				TextColor3 = Theme.Muted,
				ZIndex = 163,
			})
		end

		local function flip(index: number?)
			local cardRank = rank(result.quality)
			tickSound(index or 1, if cardRank >= 4 then 0.9 else 0.5)
			Theme.tween(back, 0.12, { Size = UDim2.fromScale(0, 1) })
			task.wait(0.12)
			back.Visible = false
			front.Visible = true
			Theme.tween(front, 0.14, { Size = UDim2.fromScale(1, 1) })
			if cardRank >= 5 then
				flash(color, if cardRank >= 6 then 0.9 else 0.45)
			end
			if cardRank >= 4 then
				burst(color, if compact then 5 + cardRank * 2 else 8 + cardRank * 4)
				Haptics.pulse(0.2 + cardRank * 0.07, 0.12)
			end
			if oddsLabel and result.oneIn >= 100 then
				countUp(oddsLabel, "Base rarity: ", result.oneIn, 0.9)
			end
		end
		return flip
	end

	-- results: список результатов; onFinish() вызывается при закрытии оверлея; onAgain — «Summon again» (необязательно)
	local function playReveal(results: { Types.RollResult }, onFinish: () -> (), onAgain: (() -> ())?)
		clearOverlay()
		overlay.Visible = true
		local quick = settings.getFlag("SkipAnim") -- «быстрый ролл»: без заряда, катсцены и пауз
		local skipped = quick

		local best = results[1]
		for _, result in results do
			if rank(result.quality) > rank(best.quality) then
				best = result
			end
		end
		local bestColor = qualityColor(best.quality)
		local bestRank = rank(best.quality)

		local function finish()
			overlay.Visible = false
			clearOverlay()
			onFinish()
		end

		if quick then
			flash(bestColor, 0.3)
		elseif bestRank >= 4 and best.oneIn >= GachaConfig.Cinematic.MinOneIn and settings.getFlag("Cinematic") then
			-- кинематографичная находка: прячем интерфейс, камера наезжает на персонажа, затем карточки со вспышкой
			overlay.Visible = false
			local hud = if parent:IsA("ScreenGui") then parent else nil
			if hud then
				hud.Enabled = false
			end
			pcall(RareCutscene.play, {
				color = bestColor,
				rank = bestRank,
				shake = settings.getFlag("Shake"),
			})
			if hud then
				hud.Enabled = true
			end
			overlay.Visible = true
			flash(bestColor, 0.9)
			shockwave(bestColor)
			burst(bestColor, 40)
		else
			-- заряд орба: цвет подсказывает редкость (Epic и выше), чем лучше находка — тем он крупнее
			local orbColor = if bestRank >= 4 then bestColor else PURPLE
			local charge = Theme.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 170,
			}, overlay)
			Theme.corner(charge, 999)
			Theme.gradient(charge, 90, Color3.fromRGB(245, 230, 255), orbColor)
			Theme.new("UIStroke", { Color = Theme.GoldLight, Thickness = 3 }, charge)
			local chargeTime = 0.9 + math.max(0, bestRank - 3) * 0.1
			Theme.tween(charge, chargeTime, { Size = UDim2.fromOffset(150 + bestRank * 14, 150 + bestRank * 14) })
			Sfx.play2D(Sounds.id("ArcLightningCharge"), 0.6)
			Haptics.pulse(0.1 + bestRank * 0.05, chargeTime)
			task.wait(chargeTime)
			flash(if #results == 1 then bestColor else Color3.new(1, 1, 1), 0.7)
			if bestRank >= 5 then
				shockwave(bestColor)
			end
			charge:Destroy()
		end

		-- особые находки: крупная подпись, под ней «1 in N» с набегающим числом
		if bestRank >= 6 then
			local label = Chrome.label(overlay, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.12),
				Size = UDim2.fromOffset(600, 70),
				Text = string.upper(best.quality) .. "!",
				FontFace = Theme.Fonts.Banner,
				TextSize = Theme.TextSize.Banner + 16,
				TextColor3 = bestColor,
				TextStrokeTransparency = 0,
				ZIndex = 180,
			})
			label.TextTransparency = 1
			Theme.tween(label, 0.4, { TextTransparency = 0 })
		end
		if #results > 1 and bestRank >= 4 then
			local bestLabel = Chrome.label(overlay, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, if bestRank >= 6 then 0.2 else 0.14),
				Size = UDim2.fromOffset(700, 36),
				Text = "",
				FontFace = Theme.Fonts.Title,
				TextSize = Theme.TextSize.Title,
				TextColor3 = bestColor,
				TextStrokeTransparency = 0,
				ZIndex = 180,
			})
			countUp(
				bestLabel,
				string.format("Best find: %s — ", RingsConfig.Rings[best.ringId].Name),
				best.oneIn,
				if quick then 0.2 else 1.4
			)
		end

		local buttons: { any } = {}
		local function showButtons()
			local continue = makeButton(
				overlay,
				UDim2.fromOffset(170, 46),
				UDim2.new(0.5, if onAgain then -180 else -85, 0.88, 0),
				"Continue",
				nil
			)
			continue.frame.ZIndex = 185
			continue.click.Event:Connect(finish)
			table.insert(buttons, continue)
			if onAgain then
				local again =
					makeButton(overlay, UDim2.fromOffset(170, 46), UDim2.new(0.5, 10, 0.88, 0), "Summon again", nil)
				again.frame.ZIndex = 185
				again.click.Event:Connect(function()
					overlay.Visible = false
					clearOverlay()
					onFinish()
					onAgain()
				end)
				table.insert(buttons, again)
			end
		end

		if #results == 1 then
			local flip = makeCard(overlay, results[1], 240, 340, UDim2.fromScale(0.5, 0.5), false)
			flip(1)
			showButtons()
			return
		end

		-- мульти: сетка 5x2, карточки переворачиваются по очереди (тон щелчков растёт); Skip показывает всё сразу
		local cardW, cardH, gap = 104, 150, 10
		local columns = 5
		local rows = math.ceil(#results / columns)
		local totalW = columns * cardW + (columns - 1) * gap
		local totalH = rows * cardH + (rows - 1) * gap
		local flips: { (number?) -> () } = {}
		for index, result in results do
			local column = (index - 1) % columns
			local row = (index - 1) // columns
			local x = -totalW / 2 + column * (cardW + gap) + cardW / 2
			local y = -totalH / 2 + row * (cardH + gap) + cardH / 2
			table.insert(flips, makeCard(overlay, result, cardW, cardH, UDim2.new(0.5, x, 0.5, y), true))
		end
		local skip = makeButton(overlay, UDim2.fromOffset(120, 40), UDim2.new(1, -140, 0.92, 0), "Skip", nil)
		skip.frame.ZIndex = 185
		skip.click.Event:Connect(function()
			skipped = true
		end)
		for index, flip in flips do
			task.spawn(flip, index)
			if not skipped then
				task.wait(0.2)
			end
		end
		skip.frame:Destroy()
		showButtons()
	end

	---------------------------------------------------------------------------
	-- Состояние и действия
	---------------------------------------------------------------------------
	local busy = false
	local autoOn = false

	local function refreshUi()
		local state = gacha.getState()
		if not state then
			return
		end
		local restricted = state.paidRestricted
		luckLabel.Text = string.format("Your Luck: ×%.2f", state.luck)
		currencyLabel.Text =
			string.format("Summon Crystals: %d     ·     Ring Essence: %d", state.crystals, state.essence)
		totalLabel.Text = string.format("Total summons: %d", state.rolls)
		single.setTexts("Summon ×1", string.format("%d Crystals", state.rollCost))
		multi.setTexts(
			string.format("Summon ×%d", state.multiCount),
			string.format("%d Crystals", state.rollCost * state.multiCount)
		)
		single.setEnabled(not busy and not restricted and state.crystals >= state.rollCost)
		multi.setEnabled(not busy and not restricted and state.crystals >= state.rollCost * state.multiCount)

		local freeIn = gacha.freeRollIn()
		free.setTexts(if freeIn <= 0 then "Free Roll: Ready!" else "Free Roll in " .. formatTime(freeIn), nil)
		free.setEnabled(not busy and freeIn <= 0)

		local hasAuto = state.passes.AutoRoll == true
		auto.setTexts(
			if hasAuto then (if autoOn then "Auto Roll: On" else "Auto Roll: Off") else "Auto Roll (Pass)",
			nil
		)
		auto.setEnabled(hasAuto and not restricted)

		if restricted then
			noteLabel.Text =
				"Paid summons and paid boosts are not available in your region. You can still use the free roll."
		else
			noteLabel.Text =
				"Odds are shown before every purchase: tap Odds / Details. Duplicate rings turn into Ring Essence."
		end
	end
	gacha.stateChanged.Event:Connect(refreshUi)

	-- таймер бесплатного ролла и подписи — раз в секунду, пока окно открыто
	task.spawn(function()
		while banner.Parent do
			if window.isOpen then
				refreshUi()
			end
			task.wait(1)
		end
	end)
	window.changed.Event:Connect(function(open: boolean)
		if open then
			task.spawn(gacha.refresh)
			refreshUi()
		else
			oddsPanel.Visible = false
		end
	end)

	local function doRoll(count: number, isFree: boolean)
		if busy then
			return
		end
		busy = true
		refreshUi()
		local response = gacha.roll(count, isFree)
		if not response.ok or not response.results then
			notify(response.reason or "Could not summon")
			busy = false
			refreshUi()
			return
		end
		local results = response.results
		local last = results[#results]
		lastLabel.Text = string.format("Last: %s (%s)", RingsConfig.Rings[last.ringId].Name, last.quality)
		playReveal(results, function()
			busy = false
			refreshUi()
		end, function()
			task.spawn(doRoll, count, isFree and false)
		end)
	end

	single.click.Event:Connect(function()
		task.spawn(doRoll, 1, false)
	end)
	multi.click.Event:Connect(function()
		local state = gacha.getState()
		task.spawn(doRoll, if state then state.multiCount else 10, false)
	end)
	free.click.Event:Connect(function()
		task.spawn(doRoll, 1, true)
	end)

	-- авто-ролл: ×1 подряд без анимации; останавливается на Epic и лучше, при нехватке кристаллов или закрытии окна
	auto.click.Event:Connect(function()
		autoOn = not autoOn
		refreshUi()
		if not autoOn then
			return
		end
		task.spawn(function()
			while autoOn and window.isOpen do
				local state = gacha.getState()
				if not state or state.paidRestricted or state.crystals < state.rollCost or busy then
					break
				end
				busy = true
				local response = gacha.roll(1, false)
				busy = false
				if not response.ok or not response.results then
					notify(response.reason or "Auto roll stopped")
					break
				end
				local result = response.results[1]
				lastLabel.Text = string.format("Last: %s (%s)", RingsConfig.Rings[result.ringId].Name, result.quality)
				if rank(result.quality) >= AUTO_STOP_RANK then
					busy = true
					playReveal(response.results, function()
						busy = false
						refreshUi()
					end, nil)
					break
				end
				task.wait(if state.passes.FastRoll then 0.35 else 0.7)
			end
			autoOn = false
			refreshUi()
		end)
	end)

	return { window = window, openOdds = openOdds }
end

return Summon
