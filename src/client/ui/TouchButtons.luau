--!strict
-- Кнопки для телефона (показываются только на устройствах с тачем): «Target» — выбрать ближайшую цель
-- (замена клавиши Tab). Каст колец — тап по слотам панели колец; выбор цели — тап по врагу в мире.

local UserInputService = game:GetService("UserInputService")

local Chrome = require(script.Parent.Chrome)
local Glyphs = require(script.Parent.Glyphs)
local Theme = require(script.Parent.Theme)

local TouchButtons = {}

-- deps: { onTarget = () -> () }
function TouchButtons.build(parent: Instance, deps: any): { frame: Frame }?
	if not UserInputService.TouchEnabled then
		return nil
	end

	local frame, bevel = Chrome.slot(parent, UDim2.fromOffset(64, 64), 10)
	frame.Name = "TargetButton"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(0.5, -176, 1, -30)
	Glyphs.target(frame)
	Chrome.label(frame, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "Target",
		TextSize = 11,
		TextColor3 = Theme.GoldLight,
		ZIndex = 15,
	})
	local hit = Theme.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 30,
	}, frame)
	hit.MouseButton1Click:Connect(function()
		Chrome.tintBevel(bevel, Theme.GoldLight)
		task.delay(0.15, function()
			Chrome.tintBevel(bevel, nil)
		end)
		deps.onTarget()
	end)
	return { frame = frame }
end

return TouchButtons
