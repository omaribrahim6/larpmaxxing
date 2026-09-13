-- Touch Grass's confirm prompt (spec "Touch Grass (rebirth)"): what resets, what stays, and
-- the farming bonus now and after, with Not yet and Touch Grass. The server decides
-- (RebirthService); this only asks.
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Rebirth = {}
Rebirth.__index = Rebirth
local MID = Vector2.new(0.5, 0.5)
local CENTER = Enum.TextXAlignment.Center
local GRASS = Color3.fromRGB(122, 214, 112)
local GRASS_BUTTON = Color3.fromRGB(52, 160, 72) -- darker, so the white label reads
local new = Theme.new

-- deps: config, play, button(parent, props, onClick), rebirthMath (Shared.RebirthMath),
-- tuning (Tuning.TouchGrass), confirm()
function Rebirth.new(root, deps)
	local words = deps.config.Words
	local self = setmetatable({ deps = deps, root = root, open = false }, Rebirth)
	-- dims the game and keeps clicks off the HUD underneath
	self.backdrop = new("Frame", root, { Name = "GrassBackdrop", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 11, Visible = false })
	self.frame = Theme.panel(root, { name = "GrassPrompt", anchor = MID, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(440, 300), z = 11, edge = GRASS, edgeWidth = 3 })
	self.frame.Visible = false
	self.frame.SelectionGroup = true
	Theme.text(self.frame, { name = "Title", font = Theme.Display, text = "🌱 " .. words.GrassTitle, size = 30, color = GRASS, align = CENTER, position = UDim2.fromOffset(16, 14), box = UDim2.new(1, -32, 0, 44), stroke = 2.5 })
	self.body = Theme.text(self.frame, { name = "Body", size = 18, align = CENTER, position = UDim2.fromOffset(20, 66), box = UDim2.new(1, -40, 1, -150), wrap = true, top = true, stroke = 1.5 })
	self.no = deps.button(self.frame, { name = "NotYet", text = words.NotYet, size = 18, position = UDim2.new(0.27, 0, 1, -42), box = UDim2.new(0.42, -12, 0, 50) }, function()
		self:Close()
	end)
	self.yes = deps.button(self.frame, { name = "Confirm", text = "🌱 " .. words.TouchGrass, size = 18, color = GRASS_BUTTON, position = UDim2.new(0.73, 0, 1, -42), box = UDim2.new(0.42, -12, 0, 50) }, function()
		self:Close()
		deps.confirm()
	end)
	self.no.NextSelectionRight = self.yes
	self.yes.NextSelectionLeft = self.no
	return self
end

-- Opens the prompt for a player with `rebirths` so far.
function Rebirth:Open(rebirths: number)
	if self.open then
		return
	end
	self.open = true
	local d = self.deps
	local now = d.rebirthMath.multiplier(rebirths, d.tuning)
	local after = d.rebirthMath.multiplier(rebirths + 1, d.tuning)
	self.body.Text = d.config.Words.GrassBody:format(("%.2fx"):format(now), ("%.2fx"):format(after))
	self.frame.Visible = true
	self.backdrop.Visible = true
	Juice.punch(self.frame, 0.8, 0.4)
	d.play("Swipe", 0.4)
end

function Rebirth:Close()
	if not self.open then
		return
	end
	self.open = false
	self.frame.Visible = false
	self.backdrop.Visible = false
end

function Rebirth:IsOpen()
	return self.open
end

function Rebirth:FocusTargets()
	return { self.no, self.yes }
end

function Rebirth:Destroy() end

return Rebirth
