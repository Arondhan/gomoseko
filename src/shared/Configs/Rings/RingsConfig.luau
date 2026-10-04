--!strict
-- Определения колец. Кольцо в слоте RingBar даёт игроку скилл (SkillId -> Configs/Skills/<SkillId>Config).

local Types = require(script.Parent.Parent.Parent.Types)

local RingsConfig = {}

RingsConfig.Rings = {
	ring_arc_lightning = {
		Id = "ring_arc_lightning",
		Name = "Кольцо дуговой молнии",
		Description = "Молния бьёт цель и перескакивает на ближайших врагов.",
		SkillId = "ArcLightning",
		Color = Color3.fromRGB(80, 160, 255),
		Quality = "Epic",
	},
} :: { [string]: Types.RingDef }

-- Предметы, которые игрок получает при входе (пока без сохранения данных)
RingsConfig.StartingItems = { "ring_arc_lightning" } :: { string }

return RingsConfig
