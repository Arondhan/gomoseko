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
	}, 6)
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

	local function addLine(text: string, color: Color3, size: number, font: Enum.Font?)
		local label = Chrome.label(frame, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			Font = font or Theme.BodyFont,
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
			TextSize = 13,
			Font = Theme.BodyFont,
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
			TextSize = 13,
			Font = Theme.BodyFont,
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
		frame.Position = UDim2.fromOffset(
			math.max(4, math.min(mouse.X, viewport.X - size.X - 4)),
			math.max(4, math.min(mouse.Y, viewport.Y - size.Y - 4))
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
		addLine(title, titleColor or Theme.GoldLight, 17, Theme.TitleFont)
		if subtitle then
			addLine(subtitle, Theme.Muted, 12)
		end
		for _, text in body do
			addLine(text, Theme.Text, 13)
		end
		open()
	end

	-- подсказка кольца: название цвета качества, тип, статы скилла в два столбца, жёлтое описание
	function tooltip.showRing(ring: Types.RingDef)
		clear()
		local quality = Theme.Quality[ring.Quality] or Theme.Quality.Common
		addLine(ring.Name, quality, 17, Theme.TitleFont)
		addRow("Кольцо", Theme.QualityNames[ring.Quality] or "", Color3.new(1, 1, 1), quality)

		local skill = getSkill(ring.SkillId)
		if skill then
			addSeparator()
			addRow(
				string.format("%d маны", skill.ManaCost),
				string.format("Дальность %d", skill.CastRange),
				Color3.new(1, 1, 1),
				Color3.new(1, 1, 1)
			)
			addRow(
				if skill.CastTime > 0
					then string.format("%g сек. каст", skill.CastTime)
					else "Мгновенно",
				string.format("Перезарядка %g сек.", skill.Cooldown),
				Color3.new(1, 1, 1),
				Color3.new(1, 1, 1)
			)
			addLine(
				string.format(
					"Использование: %s Урон %d, до %d целей, радиус прыжка %d.",
					ring.Description,
					skill.Damage,
					skill.MaxBounces + 1,
					skill.BounceRadius
				),
				Theme.Warn,
				14,
				Theme.SerifFont
			)
		else
			addLine(ring.Description, Theme.Warn, 14, Theme.SerifFont)
		end
		open()
	end

	return tooltip
end

return Tooltip
