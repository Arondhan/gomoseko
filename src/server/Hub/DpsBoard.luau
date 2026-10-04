--!strict
-- Физическая доска DPS-лидерборда в хабе: рамка на столбах и SurfaceGui с таблицей топ-10.
-- build() ставит доску на карту (BuildHub), render() обновляет текст (DpsService, раз в несколько секунд).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fonts = require(Shared:WaitForChild("Fonts"))
local DpsMath = require(Shared:WaitForChild("Dps"):WaitForChild("DpsMath"))

local DpsBoard = {}

local ROWS = 10
local CANVAS = Vector2.new(1120, 760)
local GOLD = Color3.fromRGB(255, 226, 150)
local RANK_COLORS = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(215, 220, 232), Color3.fromRGB(214, 146, 90) }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	textSize: number,
	align: Enum.TextXAlignment,
	font: Font
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.FontFace = font
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.5
	l.TextXAlignment = align
	l.Text = ""
	l.Parent = parent
	return l
end

-- position — точка на земле под доской; доска смотрит в сторону +Z
function DpsBoard.build(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "DpsBoard"
	local facing = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
	local wood = Color3.fromRGB(104, 72, 44)
	local dark = Color3.fromRGB(20, 22, 30)

	for _, side in { -1, 1 } do
		part(
			model,
			"Post",
			Vector3.new(1.2, 13, 1.2),
			facing * CFrame.new(side * 7.6, 6.5, 0),
			wood,
			Enum.Material.Wood
		)
	end
	part(
		model,
		"Frame",
		Vector3.new(16.4, 10.6, 0.8),
		facing * CFrame.new(0, 8.6, 0.1),
		Color3.fromRGB(214, 164, 70),
		Enum.Material.Metal
	)
	local board = part(
		model,
		"Board",
		Vector3.new(15.2, 9.4, 0.6),
		facing * CFrame.new(0, 8.6, -0.35),
		dark,
		Enum.Material.SmoothPlastic
	)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = CANVAS
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = board

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(44, 46, 64), Color3.fromRGB(14, 15, 22))
	gradient.Parent = backdrop

	local title = label(
		gui,
		"Title",
		UDim2.fromOffset(0, 16),
		UDim2.new(1, 0, 0, 84),
		64,
		Enum.TextXAlignment.Center,
		Fonts.Banner
	)
	title.TextColor3 = GOLD
	title.Text = "DPS LEADERBOARD"
	local subtitle = label(
		gui,
		"Subtitle",
		UDim2.fromOffset(0, 100),
		UDim2.new(1, 0, 0, 40),
		32,
		Enum.TextXAlignment.Center,
		Fonts.Title
	)
	subtitle.TextColor3 = Color3.fromRGB(170, 200, 255)

	for row = 1, ROWS do
		local y = 150 + (row - 1) * 54
		label(
			gui,
			"Rank" .. row,
			UDim2.fromOffset(40, y),
			UDim2.fromOffset(110, 50),
			34,
			Enum.TextXAlignment.Left,
			Fonts.Numbers
		)
		label(
			gui,
			"Name" .. row,
			UDim2.fromOffset(160, y),
			UDim2.fromOffset(620, 50),
			34,
			Enum.TextXAlignment.Left,
			Fonts.Title
		)
		label(
			gui,
			"Score" .. row,
			UDim2.fromOffset(780, y),
			UDim2.fromOffset(300, 50),
			34,
			Enum.TextXAlignment.Right,
			Fonts.Numbers
		)
	end

	local footer = label(
		gui,
		"Footer",
		UDim2.fromOffset(0, 702),
		UDim2.new(1, 0, 0, 44),
		26,
		Enum.TextXAlignment.Center,
		Fonts.Body
	)
	footer.TextColor3 = Color3.fromRGB(190, 190, 205)
	footer.Text = "Hit a training dummy for 30 seconds to set your score"

	model.PrimaryPart = board
	model.Parent = parent
	return model
end

-- entries: { { rank, name, score } }; score = DPS × 10; title — «Daily» / «Weekly» / «All time»
function DpsBoard.render(
	model: Model,
	period: string,
	entries: { { rank: number, name: string, score: number } },
	note: string?
)
	local board = model:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("Gui")
	if not gui then
		return
	end
	local subtitle = gui:FindFirstChild("Subtitle") :: TextLabel?
	if subtitle then
		subtitle.Text = period .. (if note then "  ·  " .. note else "")
	end
	for row = 1, ROWS do
		local entry = entries[row]
		local rankLabel = gui:FindFirstChild("Rank" .. row) :: TextLabel?
		local nameLabel = gui:FindFirstChild("Name" .. row) :: TextLabel?
		local scoreLabel = gui:FindFirstChild("Score" .. row) :: TextLabel?
		if rankLabel and nameLabel and scoreLabel then
			if entry then
				local color = RANK_COLORS[row] or Color3.new(1, 1, 1)
				rankLabel.Text = "#" .. entry.rank
				nameLabel.Text = entry.name
				scoreLabel.Text = DpsMath.format(entry.score) .. " DPS"
				rankLabel.TextColor3 = color
				nameLabel.TextColor3 = color
				scoreLabel.TextColor3 = color
			else
				rankLabel.Text = ""
				nameLabel.Text = if row == 1 then "No scores yet — be the first!" else ""
				nameLabel.TextColor3 = Color3.fromRGB(150, 150, 165)
				scoreLabel.Text = ""
			end
		end
	end
end

return DpsBoard
