--!strict
-- Всплывающая подсказка в стиле WoW: название, подзаголовок и строки описания, следует за курсором.
-- Один экземпляр на весь UI. showRing(ring) собирает текст из определения кольца и конфига его скилла.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))
local Theme = require(script.Parent.Theme)

local Tooltip = {}

local WIDTH = 240
local CURSOR_OFFSET = Vector2.new(18, 18)
local RARITY_COLORS: { [string]: Color3 } = {
	["Эпическое"] = Color3.fromRGB(190, 90, 255),
}

function Tooltip.build(parent: Instance, getSkill: (skillId: string) -> Types.SkillConfig?)
	local frame = Theme.new("Frame", {
		Name = "Tooltip",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 100,
	}, parent)
	Theme.corner(frame, 6)
	Theme.stroke(frame, Theme.Gold, 1.5)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, frame)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, frame)

	local lines: { Instance } = {}
	local function addLine(text: string, color: Color3, size: number, bold: boolean)
		local label = Theme.new("TextLabel", {
			LayoutOrder = #lines + 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
			TextSize = size,
			TextColor3 = color,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 101,
		}, frame)
		table.insert(lines, label)
	end

	local connection: RBXScriptConnection? = nil
	local function follow()
		local mouse = UserInputService:GetMouseLocation() + CURSOR_OFFSET
		local viewport = frame.Parent and (frame.Parent :: GuiBase2d).AbsoluteSize or Vector2.new(1920, 1080)
		local size = frame.AbsoluteSize
		frame.Position =
			UDim2.fromOffset(math.min(mouse.X, viewport.X - size.X - 4), math.min(mouse.Y, viewport.Y - size.Y - 4))
	end

	local tooltip = {}

	function tooltip.hide()
		frame.Visible = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	-- title / subtitle / строки описания; titleColor — цвет названия
	function tooltip.show(title: string, subtitle: string?, body: { string }, titleColor: Color3?)
		for _, line in lines do
			line:Destroy()
		end
		table.clear(lines)
		addLine(title, titleColor or Theme.Text, 16, true)
		if subtitle then
			addLine(subtitle, Theme.Muted, 12, false)
		end
		for _, text in body do
			addLine(text, Theme.Text, 13, false)
		end
		frame.Visible = true
		follow()
		if not connection then
			connection = RunService.RenderStepped:Connect(follow)
		end
	end

	function tooltip.showRing(ring: Types.RingDef)
		local body = { ring.Description }
		local skill = getSkill(ring.SkillId)
		if skill then
			table.insert(body, string.format("Урон: %d (до %d целей)", skill.Damage, skill.MaxBounces + 1))
			table.insert(body, string.format("Радиус прыжка: %d", skill.BounceRadius))
			table.insert(body, string.format("Дальность: %d", skill.CastRange))
			table.insert(body, string.format("Мана: %d", skill.ManaCost))
			table.insert(body, string.format("Перезарядка: %g сек", skill.Cooldown))
		end
		tooltip.show(ring.Name, ring.Rarity, body, RARITY_COLORS[ring.Rarity])
	end

	return tooltip
end

return Tooltip
