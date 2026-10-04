-- Фабрика окон в стиле WoW: объёмная золотая рамка с ромбами по углам, баннер заголовка,
-- кнопка закрытия, перетаскивание за заголовок, анимация открытия/закрытия.

local UserInputService = game:GetService("UserInputService")

local Chrome = require(script.Parent.Chrome)
local Theme = require(script.Parent.Theme)

local Window = {}

local topZ = 1 -- общий счётчик, чтобы активное окно было поверх

function Window.new(parent: Instance, config: { name: string, title: string, size: UDim2, position: UDim2 })
	local frame = Theme.new("CanvasGroup", {
		Name = config.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = config.position,
		Size = config.size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
		GroupTransparency = 1,
	}, parent)
	Theme.corner(frame, 10)
	Theme.gradient(frame, 90, Theme.PanelTop, Theme.PanelBottom)
	Chrome.bevel(frame, 3, 10)
	local scale = Theme.new("UIScale", { Name = "Scale", Scale = 0.94 }, frame)

	-- баннер заголовка
	local bar = Theme.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, frame)
	Theme.gradient(bar, 90, Color3.fromRGB(54, 48, 36), Color3.fromRGB(24, 22, 20))
	local line = Theme.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, bar)
	Theme.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.GoldDark),
			ColorSequenceKeypoint.new(0.5, Theme.GoldLight),
			ColorSequenceKeypoint.new(1, Theme.GoldDark),
		}),
	}, line)
	Chrome.label(bar, {
		Name = "Title",
		Size = UDim2.fromScale(1, 1),
		Text = config.title,
		FontFace = Theme.Fonts.Title,
		TextSize = 20,
		TextColor3 = Theme.GoldLight,
		TextStrokeTransparency = 0.2,
		ZIndex = 3,
	})
	Chrome.diamond(bar, 8, UDim2.new(0, 16, 0.5, 0), 4)
	Chrome.diamond(bar, 8, UDim2.new(1, -48, 0.5, 0), 4)

	local close = Theme.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "X",
		FontFace = Theme.Fonts.Numbers,
		TextSize = 14,
		TextColor3 = Theme.GoldLight,
		ZIndex = 4,
	}, bar)
	Theme.corner(close, 6)
	Theme.gradient(close, 90, Color3.fromRGB(70, 36, 30), Color3.fromRGB(30, 16, 14))
	Chrome.bevel(close, 1.5, 6)
	close.MouseEnter:Connect(function()
		Theme.tween(close, 0.1, { TextColor3 = Theme.Danger })
	end)
	close.MouseLeave:Connect(function()
		Theme.tween(close, 0.1, { TextColor3 = Theme.GoldLight })
	end)

	Chrome.corners(frame, 9, 7)

	local body = Theme.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
	}, frame)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
	}, body)

	local window = { frame = frame, body = body, isOpen = false, changed = Instance.new("BindableEvent") }

	local function bringToFront()
		topZ += 1
		frame.ZIndex = topZ
	end

	function window.setOpen(open: boolean)
		if window.isOpen == open then
			return
		end
		window.isOpen = open
		window.changed:Fire(open)
		if open then
			bringToFront()
			frame.Visible = true
			scale.Scale = 0.94
			Theme.tween(frame, 0.15, { GroupTransparency = 0 })
			Theme.tween(scale, 0.15, { Scale = 1 })
		else
			Theme.tween(frame, 0.12, { GroupTransparency = 1 })
			Theme.tween(scale, 0.12, { Scale = 0.96 })
			task.delay(0.12, function()
				if not window.isOpen then
					frame.Visible = false
				end
			end)
		end
	end

	function window.toggle()
		window.setOpen(not window.isOpen)
	end

	close.MouseButton1Click:Connect(function()
		window.setOpen(false)
	end)

	-- перетаскивание за заголовок
	local dragging = false
	local dragStart: Vector3
	local startPos: UDim2
	bar.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			bringToFront()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - dragStart
			frame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	return window
end

return Window
