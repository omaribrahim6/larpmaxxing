--!strict
-- Number formatting for UI.
local Format = {}

-- 1234567 -> "1,234,567". Rounds to a whole number first.
function Format.int(n: number): string
	local whole = math.floor((n or 0) + 0.5)
	local negative = whole < 0
	local s = tostring(math.abs(whole))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return if negative then "-" .. out else out
end

-- Short form for tight spaces: 950, 12.4K, 1.2M.
function Format.short(n: number): string
	local a = math.abs(n or 0)
	if a >= 1e6 then
		return (string.format("%.1fM", n / 1e6):gsub("%.0M", "M"))
	elseif a >= 1e4 then
		return (string.format("%.1fK", n / 1e3):gsub("%.0K", "K"))
	end
	return Format.int(n)
end

return Format

