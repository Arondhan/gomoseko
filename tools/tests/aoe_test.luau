-- Проверки AoeSearch вне Roblox. Запуск из корня репозитория: luau tools/tests/aoe_test.luau
local AoeSearch = require("../../src/shared/Combat/AoeSearch")

-- минимальная замена Vector3 для CLI: вычитание и Magnitude
local V = {}
V.__sub = function(a, b) return V.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
	return nil
end
function V.new(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V) end

local function check(name, cond) print((cond and "PASS " or "FAIL ") .. name) assert(cond, name) end

local candidates = {
	{ id = "far", position = V.new(30, 0, 0) },
	{ id = "edge", position = V.new(10, 0, 0) },
	{ id = "near", position = V.new(2, 0, 0) },
	{ id = "mid", position = V.new(6, 0, 0) },
}
local center = V.new(0, 0, 0)

local hit = AoeSearch.within(candidates, center, 10)
check("three inside radius", #hit == 3)
check("sorted nearest first", hit[1].id == "near" and hit[2].id == "mid" and hit[3].id == "edge")
check("boundary is included", hit[3].id == "edge")
check("far is excluded", #AoeSearch.within(candidates, center, 5) == 1)
check("empty list", #AoeSearch.within({}, center, 10) == 0)
check("zero radius hits only same point", #AoeSearch.within({ { id = "x", position = center } }, center, 0) == 1)

check("flight time", AoeSearch.flightTime(70, 70) == 1)
check("flight time 35 studs at 70/s", AoeSearch.flightTime(35, 70) == 0.5)
check("zero speed is instant", AoeSearch.flightTime(50, 0) == 0)
check("negative distance clamps", AoeSearch.flightTime(-5, 10) == 0)
