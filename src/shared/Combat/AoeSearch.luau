--!strict
-- Чистая математика площадных скиллов (без Roblox-инстансов — проверяется вне Studio).
-- Используется server/Services/CombatService (Fireball, Meteor).

local AoeSearch = {}

export type Candidate<T> = { id: T, position: Vector3 }

-- Все кандидаты не дальше radius от center (граница включена), ближайшие первыми
function AoeSearch.within<T>(candidates: { Candidate<T> }, center: Vector3, radius: number): { Candidate<T> }
	local found: { { candidate: Candidate<T>, dist: number } } = {}
	for _, candidate in candidates do
		local dist = (candidate.position - center).Magnitude
		if dist <= radius then
			table.insert(found, { candidate = candidate, dist = dist })
		end
	end
	table.sort(found, function(a, b)
		return a.dist < b.dist
	end)
	local result: { Candidate<T> } = {}
	for _, entry in found do
		table.insert(result, entry.candidate)
	end
	return result
end

-- Время полёта снаряда (сек); нулевая или отрицательная скорость — мгновенно
function AoeSearch.flightTime(distance: number, speed: number): number
	if speed <= 0 then
		return 0
	end
	return math.max(0, distance) / speed
end

return AoeSearch
