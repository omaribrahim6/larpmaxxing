-- Builds the leaderboard wall on the Plaza's east edge (Workspace.Larp.Map.Plaza.LeaderboardWall):
-- one board per Config.Leaderboards entry, facing the middle of the Plaza, on a dark wall
-- between two gold posts under a LEADERBOARDS header. LeaderboardService draws each board
-- at runtime (a board part's Leaderboard attribute names its entry). Rebuild with
--   require(game.ServerStorage.LarpBuild.LeaderboardWall).build()
local Kit = require(script.Parent.Kit)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Leaderboards)

local Wall = {}

Wall.config = {
	x = 53, -- the wall's line; the boards face -X, toward the Plaza's middle
	centerZ = 4.5,
	floorY = 0.2, -- the Plaza floor's top
	board = Vector3.new(11, 13, 0.5), -- one board: width, height, depth
	gap = 1.2,
	lift = 1.8, -- a board's bottom above the floor
}

local P = Kit.Palette

function Wall.build(): string
	local c = Wall.config
	local model = Kit.fresh(workspace.Larp.Map.Plaza, "LeaderboardWall", "Model")
	local boards = Config.boards
	local width = #boards * c.board.X + (#boards - 1) * c.gap
	local top = c.floorY + c.lift + c.board.Y
	-- facing -X, a part's local X runs along world -Z, so the boards read left to right as
	-- z grows; `back` pushes a part behind the boards' faces
	local function at(z: number, y: number, back: number?): CFrame
		local p = Vector3.new(c.x + (back or 0), y, z)
		return CFrame.lookAt(p, p - Vector3.xAxis)
	end
	Kit.block(model, "Plinth", at(c.centerZ, c.floorY + 0.5, 0.4), Vector3.new(width + 3, 1, 3), P.dark, Enum.Material.Slate)
	Kit.block(model, "Backing", at(c.centerZ, (c.floorY + top + 3) / 2, 0.7), Vector3.new(width + 2, top + 3 - c.floorY, 0.8), Color3.fromRGB(34, 30, 46))
	for _, side in { -1, 1 } do
		Kit.block(model, "Post", at(c.centerZ + side * (width / 2 + 1.2), (c.floorY + top + 3) / 2, 0.3), Vector3.new(1.4, top + 3 - c.floorY, 1.8), P.gold, Enum.Material.Metal)
	end
	for i, board in boards do
		local z = c.centerZ - width / 2 + c.board.X / 2 + (i - 1) * (c.board.X + c.gap)
		local part = Kit.block(model, "Board_" .. board.id, at(z, c.floorY + c.lift + c.board.Y / 2), c.board, Color3.fromRGB(20, 18, 28))
		part:SetAttribute("Leaderboard", board.id)
		-- a neon trim in the board's colour along its bottom edge
		Kit.block(model, "Trim", at(z, c.floorY + c.lift - 0.2, -0.05), Vector3.new(c.board.X, 0.3, 0.6), board.color, Enum.Material.Neon)
	end
	local header = Kit.block(model, "Header", at(c.centerZ, top + 1.6, -0.05), Vector3.new(width * 0.6, 2.8, 0.6), P.gold)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = header
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(28, 22, 12)
	label.Text = Config.header
	label.Parent = gui
	return ("%d boards"):format(#boards)
end

return Wall
