-- The look of the player UI: its fonts and the few primitives every panel, label and
-- button is built from. Colours live in UIConfig.Colors.
local Colors = require(script.Parent.UIConfig).Colors

local Theme = {}
Theme.Display = Enum.Font.LuckiestGuy -- rank names, numbers, stamps
Theme.Body = Enum.Font.FredokaOne -- labels and buttons
Theme.Small = Enum.Font.GothamBlack -- eyebrows and small caps

function Theme.new(class, parent, props)
	local inst = Instance.new(class)
	for key, value in props or {} do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end
local new = Theme.new

-- Rounded corners: `radius` pixels, or a pill or circle when nil.
function Theme.corner(parent, radius)
	return new("UICorner", parent, { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

-- An outline around a frame (never its text).
function Theme.border(parent, color, thickness)
	return new("UIStroke", parent, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color or Colors.Ink,
		Thickness = thickness or 2.5,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- Lighter at the top, darker at the bottom (multiplies the frame's colour).
function Theme.shade(parent, bottom)
	return new("UIGradient", parent, { Name = "Shade", Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), bottom or Color3.fromRGB(170, 170, 180)) })
end

-- A text label with an ink outline. props: name, text, font, size, color, position, box
-- (its Size), anchor, align, top (align to the top), scaled, maxSize, wrap, stroke
-- (outline thickness, or false for none).
function Theme.text(parent, props)
	local label = new("TextLabel", parent, {
		Name = props.name or "Label",
		BackgroundTransparency = 1,
		Text = props.text or "",
		Font = props.font or Theme.Body,
		TextSize = props.size or 16,
		TextColor3 = props.color or Colors.Text,
		TextScaled = props.scaled == true,
		TextWrapped = props.wrap == true,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = if props.top then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		Position = props.position or UDim2.new(),
		Size = props.box or UDim2.fromScale(1, 1),
		AnchorPoint = props.anchor or Vector2.zero,
	})
	if props.stroke ~= false then
		new("UIStroke", label, { Color = Colors.Ink, Thickness = props.stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round })
	end
	if props.maxSize then
		new("UITextSizeConstraint", label, { MaxTextSize = props.maxSize, MinTextSize = props.minSize or 8 })
	end
	return label
end

-- A dark panel: shaded fill, ink outline, rounded. props: name, position, box, anchor,
-- color, transparency, radius, edge (outline colour), edgeWidth, z.
function Theme.panel(parent, props)
	local frame = new("Frame", parent, {
		Name = props.name or "Panel",
		BackgroundColor3 = props.color or Colors.PanelTop,
		BackgroundTransparency = props.transparency or 0.04,
		BorderSizePixel = 0,
		Position = props.position or UDim2.new(),
		Size = props.box or UDim2.fromScale(1, 1),
		AnchorPoint = props.anchor or Vector2.zero,
		ZIndex = props.z or 1,
	})
	Theme.corner(frame, props.radius or 14)
	Theme.border(frame, props.edge, props.edgeWidth)
	Theme.shade(frame, Color3.fromRGB(140, 140, 155))
	return frame
end

-- A chunky button: a coloured face shaded to a darker bottom, an ink outline and an
-- outlined label (the child "Label"; change it with Theme.setText). It is anchored at its
-- centre, so hover and press scale it in place. props: name, text, color, textColor, size,
-- position, box, anchor, radius, scaled, maxSize, z.
function Theme.button(parent, props)
	local b = new("TextButton", parent, {
		Name = props.name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = props.color or Colors.Raised,
		BorderSizePixel = 0,
		Position = props.position or UDim2.new(),
		Size = props.box or UDim2.fromOffset(120, 44),
		AnchorPoint = props.anchor or Vector2.new(0.5, 0.5),
		Selectable = true,
		ZIndex = props.z or 1,
	})
	Theme.corner(b, props.radius or 12)
	Theme.border(b)
	new("UIGradient", b, {
		Name = "Shade",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(236, 236, 236)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 168)),
		}),
	})
	Theme.text(b, {
		text = props.text,
		size = props.size or 18,
		color = props.textColor,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(6, 2),
		box = UDim2.new(1, -12, 1, -4),
		stroke = 1.8,
		scaled = props.scaled,
		maxSize = props.maxSize,
	})
	return b
end

function Theme.setText(button, text)
	local label = button:FindFirstChild("Label")
	if label and label.Text ~= text then
		label.Text = text
	end
end

return Theme
