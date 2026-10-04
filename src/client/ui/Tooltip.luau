--!strict
-- Всплывающая подсказка в стиле WoW: панель с золотой фаской, название цвета качества, строки статов в два столбца,
-- жёлтое описание. Следует за курсором и не вылезает за экран. Один экземпляр на весь UI.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local Tooltip = {}

local WIDTH = 260
local CURSOR_OFFSET = Vector2.new(18, 18)
local Z = 101

function Tooltip.build(parent: Instance, getSkill: (skillId: string) -> Types.SkillConfig?)
	local frame = Chrome.panel(parent, {
		Name = "Tooltip",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 100,
	}, 6, true) -- simple: внутри панели UIListLayout, вложенный BevelInner сломал бы раскладку
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, frame)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, frame)

	local lines: { Instance } = {}

	local function nextOrder(): number
		return #lines + 1
	end

	local function addLine(text: string, color: Color3, size: number, font: Font?)
		local label = Chrome.label(frame, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			FontFace = font or Theme.Fonts.Body,
			TextSize = size,
			TextColor3 = color,
			TextStrokeTransparency = 0.6,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = Z,
		})
		table.insert(lines, label)
	end

	-- строка в два столбца (слева и справа)
	local function addRow(left: string, right: string, leftColor: Color3, rightColor: Color3)
		local row = Theme.new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			ZIndex = Z,
		}, frame)
		Chrome.label(row, {
			Size = UDim2.fromScale(0.5, 1),
			Text = left,
			TextSize = 15,
			FontFace = Theme.Fonts.Body,
			TextColor3 = leftColor,
			TextStrokeTransparency = 0.6,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = Z,
		})
		Chrome.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),
			Text = right,
			TextSize = 15,
			FontFace = Theme.Fonts.Body,
			TextColor3 = rightColor,
			TextStrokeTransparency = 0.6,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = Z,
		})
		table.insert(lines, row)
	end

	local function addSeparator()
		local line = Theme.new("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = Z,
		}, frame)
		Theme.new("UIGradient", {
			Color = ColorSequence.new(Theme.GoldDark, Theme.GoldMid),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.2),
				NumberSequenceKeypoint.new(0.8, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, line)
		table.insert(lines, line)
	end

	local connection: RBXScriptConnection? = nil
	local function follow()
		local mouse = UserInputService:GetMouseLocation() + CURSOR_OFFSET
		local viewport = (frame.Parent :: GuiBase2d).AbsoluteSize
		local size = frame.AbsoluteSize
		local scale = Theme.scaleOf(frame)
		frame.Position = UDim2.fromOffset(
			math.max(4, math.min(mouse.X, viewport.X - size.X - 4)) / scale,
			math.max(4, math.min(mouse.Y, viewport.Y - size.Y - 4)) / scale
		)
	end

	local function clear()
		for _, line in lines do
			line:Destroy()
		end
		table.clear(lines)
	end

	local function open()
		frame.Visible = true
		follow()
		if not connection then
			connection = RunService.RenderStepped:Connect(follow)
		end
	end

	local tooltip = {}

	function tooltip.hide()
		frame.Visible = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	-- простая подсказка: название, подзаголовок, строки текста
	function tooltip.show(title: string, subtitle: string?, body: { string }, titleColor: Color3?)
		clear()
		addLine(title, titleColor or Theme.GoldLight, 17, Theme.Fonts.Title)
		if subtitle then
			addLine(subtitle, Theme.Muted, 12)
		end
		for _, text in body do
			addLine(text, Theme.Text, 13)
		end
		open()
	end

	-- подсказка кольца: название цвета качества, пассивные бонусы (зелёным, как в WoW), статы скилла и описание
	function tooltip.showRing(ring: Types.RingDef)
		clear()
		local quality = Theme.Quality[ring.Quality] or Theme.Quality.Common
		addLine(ring.Name, quality, 17, Theme.Fonts.Title)
		addRow("Ring", Theme.QualityNames[ring.Quality] or "", Color3.new(1, 1, 1), quality)

		-- пассивные бонусы
		local stats = ring.Stats
		local bonuses: { string } = {}
		if stats.DamagePct then
			table.insert(bonuses, string.format("+%g%% Damage", stats.DamagePct))
		end
		if stats.MaxMana then
			table.insert(bonuses, string.format("+%g Max Mana", stats.MaxMana))
		end
		if stats.ManaRegen then
			table.insert(bonuses, string.format("+%g Mana regen / s", stats.ManaRegen))
		end
		if stats.CooldownReductionPct then
			table.insert(bonuses, string.format("-%g%% Cooldown", stats.CooldownReductionPct))
		end
		if stats.CastRange then
			table.insert(bonuses, string.format("+%g Cast range", stats.CastRange))
		end
		if stats.LuckPct then
			table.insert(bonuses, string.format("+%g%% Summon luck", stats.LuckPct))
		end
		if #bonuses > 0 then
			addSeparator()
			for _, text in bonuses do
				addLine(text, Theme.Good, 14)
			end
		end

		local skill = if ring.SkillId then getSkill(ring.SkillId) else nil
		if skill then
			addSeparator()
			addRow(
				string.format("%d mana", skill.ManaCost),
				string.format("Range %d", skill.CastRange),
				Color3.new(1, 1, 1),
				Color3.new(1, 1, 1)
			)
			addRow(
				if skill.CastTime > 0 then string.format("%g sec cast", skill.CastTime) else "Instant",
				string.format("Cooldown %g sec", skill.Cooldown),
				Color3.new(1, 1, 1),
				Color3.new(1, 1, 1)
			)
			addLine(
				string.format(
					"Use: %s Deals %d damage, hits up to %d targets, jump radius %d.",
					ring.Description,
					skill.Damage,
					skill.MaxBounces + 1,
					skill.BounceRadius
				),
				Theme.Warn,
				14,
				Theme.Fonts.Serif
			)
		else
			addLine(ring.Description, Theme.Warn, 14, Theme.Fonts.Serif)
		end
		addLine(string.format("Base rarity: 1 in %s", tostring(ring.OneIn)), Theme.Muted, 12)
		open()
	end

	return tooltip
end

return Tooltip
