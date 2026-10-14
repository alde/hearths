-- Flat settings widgets.
-- Every row builder takes (parent, ..., y) and returns (frame, height) so
-- pages can be laid out top-down with `y = y - h`.

local W = {}
Hearths.Widgets = W

local ROW_H = 32
local SECTION_H = 30
local LABEL_PAD = 16
local CONTROL_PAD = 16
local FONT = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE = 11

W.ACCENT = { 0.35, 0.70, 1.0 }
W.FONT = FONT
W.LABEL_PAD = LABEL_PAD
W.CONTROL_PAD = CONTROL_PAD
local ACCENT = W.ACCENT
local TEXT_DIM = { 1, 1, 1, 0.40 }

local INPUT_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 8,
	insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
W.INPUT_BACKDROP = INPUT_BACKDROP

local rowCounters = {}

local function RowBg(frame, parent)
	rowCounters[parent] = (rowCounters[parent] or 0) + 1
	if rowCounters[parent] % 2 == 0 then
		local bg = frame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.15)
	end
end

local function MakeLabel(parent, text)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, FONT_SIZE, "")
	fs:SetPoint("LEFT", parent, "LEFT", LABEL_PAD, 0)
	fs:SetTextColor(1, 1, 1, 0.9)
	fs:SetText(text)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	fs:SetMaxLines(1)
	return fs
end

local function MakeRow(parent, y, height)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(parent:GetWidth(), height or ROW_H)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	RowBg(f, parent)
	return f
end

local function AttachTooltip(frame, tooltip)
	if not tooltip then return end
	frame:EnableMouse(true)
	frame:HookScript("OnEnter", function(self)
		local text = type(tooltip) == "function" and tooltip() or tooltip
		if not text or text == "" then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Small text button with accent hover, used inline in rows and headers
function W:TextButton(parent, text, onClick, width)
	local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
	btn:SetBackdrop(INPUT_BACKDROP)
	btn:SetBackdropColor(0.08, 0.10, 0.14, 0.9)
	btn:SetBackdropBorderColor(1, 1, 1, 0.2)
	local label = btn:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, 10, "")
	label:SetPoint("CENTER")
	label:SetTextColor(1, 1, 1, 0.9)
	btn.label = label
	function btn:SetLabel(t)
		label:SetText(t)
		self:SetSize(width or math.max(60, math.ceil(label:GetStringWidth()) + 20), 22)
	end
	btn:SetLabel(text)
	btn:SetScript("OnClick", onClick)
	btn:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
	end)
	btn:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(1, 1, 1, 0.2)
	end)
	return btn
end

-- Section header

function W:SectionHeader(parent, text, y)
	rowCounters[parent] = 0

	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(parent:GetWidth(), SECTION_H)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)

	local label = f:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, 10, "")
	label:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LABEL_PAD, 6)
	label:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3], TEXT_DIM[4])
	label:SetText(text)
	f.label = label

	local sep = f:CreateTexture(nil, "ARTWORK")
	sep:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LABEL_PAD, 0)
	sep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -LABEL_PAD, 0)
	sep:SetHeight(1)
	sep:SetColorTexture(1, 1, 1, 0.06)

	return f, SECTION_H
end

-- Toggle switch. isDisabled (optional) greys the row out and blocks clicks.

function W:Toggle(parent, text, y, getValue, setValue, tooltip, isDisabled)
	local f = MakeRow(parent, y)
	local label = MakeLabel(f, text)

	local TRACK_W, TRACK_H = 34, 18
	local KNOB_PAD = 2
	local KNOB_SZ = TRACK_H - KNOB_PAD * 2

	local track = CreateFrame("Button", nil, f)
	track:SetSize(TRACK_W, TRACK_H)
	track:SetPoint("RIGHT", f, "RIGHT", -CONTROL_PAD, 0)

	local trackBg = track:CreateTexture(nil, "BACKGROUND")
	trackBg:SetAllPoints()

	local knob = track:CreateTexture(nil, "OVERLAY")
	knob:SetSize(KNOB_SZ, KNOB_SZ)

	local function Snap()
		local disabled = isDisabled and isDisabled()
		local on = getValue() and not disabled
		knob:ClearAllPoints()
		if on then
			trackBg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.75)
			knob:SetColorTexture(1, 1, 1, 1)
			knob:SetPoint("LEFT", track, "LEFT", TRACK_W - KNOB_SZ - KNOB_PAD, 0)
		else
			trackBg:SetColorTexture(0.25, 0.25, 0.25, 0.65)
			knob:SetColorTexture(1, 1, 1, 0.5)
			knob:SetPoint("LEFT", track, "LEFT", KNOB_PAD, 0)
		end
		f:SetAlpha(disabled and 0.4 or 1)
	end

	track:SetScript("OnClick", function()
		if isDisabled and isDisabled() then return end
		setValue(not getValue())
		Snap()
	end)

	AttachTooltip(f, tooltip)
	AttachTooltip(track, tooltip)

	Snap()
	f._refresh = Snap
	return f, ROW_H
end

-- Dropdown. values: table key -> label, or a function returning one.

function W:Dropdown(parent, text, y, values, getValue, setValue, order, tooltip)
	local f = MakeRow(parent, y)
	MakeLabel(f, text)

	local DD_W, DD_H = 160, 24

	local btn = CreateFrame("Button", nil, f)
	btn:SetSize(DD_W, DD_H)
	btn:SetPoint("RIGHT", f, "RIGHT", -CONTROL_PAD, 0)

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.08, 0.10, 0.14, 0.9)

	local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
	border:SetAllPoints()
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	border:SetBackdropBorderColor(1, 1, 1, 0.15)

	local label = btn:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, FONT_SIZE, "")
	label:SetPoint("LEFT", btn, "LEFT", 8, 0)
	label:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	label:SetMaxLines(1)
	label:SetTextColor(1, 1, 1, 0.9)

	local arrow = btn:CreateFontString(nil, "OVERLAY")
	arrow:SetFont(FONT, 10, "")
	arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
	arrow:SetText("v")
	arrow:SetTextColor(1, 1, 1, 0.5)

	local function GetValues()
		return type(values) == "function" and values() or values
	end

	local function GetOrder(vals)
		local o = type(order) == "function" and order() or order
		if o and #o > 0 then return o end
		o = {}
		for k in pairs(vals) do o[#o + 1] = k end
		table.sort(o, function(a, b) return tostring(vals[a]) < tostring(vals[b]) end)
		return o
	end

	local function UpdateLabel()
		local key = getValue()
		local vals = GetValues()
		label:SetText(vals[key] or tostring(key or ""))
	end

	local menu
	local itemPool = {}

	local function BuildMenu()
		if not menu then
			menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
			menu:SetBackdrop(INPUT_BACKDROP)
			menu:SetBackdropColor(0.08, 0.10, 0.14, 0.95)
			menu:SetBackdropBorderColor(1, 1, 1, 0.2)
			menu:SetFrameStrata("TOOLTIP")
			menu:SetWidth(DD_W)
			menu:SetClampedToScreen(true)
			menu:SetPoint("TOP", btn, "BOTTOM", 0, -2)
		end

		-- Rebuilt on every open so dynamic lists (profiles) stay current
		local vals = GetValues()
		local displayOrder = GetOrder(vals)
		local itemH = 22
		for _, item in ipairs(itemPool) do item:Hide() end

		for i, key in ipairs(displayOrder) do
			local item = itemPool[i]
			if not item then
				item = CreateFrame("Button", nil, menu)
				item:SetSize(DD_W - 4, itemH)
				item.text = item:CreateFontString(nil, "OVERLAY")
				item.text:SetFont(FONT, FONT_SIZE, "")
				item.text:SetAllPoints()
				item.text:SetJustifyH("LEFT")
				item.text:SetTextColor(1, 1, 1, 0.85)
				item:SetScript("OnEnter", function(self) self.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
				item:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 1, 1, 0.85) end)
				itemPool[i] = item
			end
			item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(2 + (i - 1) * itemH))
			item.text:SetText("  " .. tostring(vals[key] or key))
			item:SetScript("OnClick", function()
				setValue(key)
				UpdateLabel()
				menu:Hide()
			end)
			item:Show()
		end
		menu:SetHeight(#displayOrder * itemH + 4)
	end

	btn:SetScript("OnClick", function()
		if menu and menu:IsShown() then
			menu:Hide()
			return
		end
		BuildMenu()
		menu:Show()
	end)

	btn:SetScript("OnEnter", function() border:SetBackdropBorderColor(1, 1, 1, 0.30) end)
	btn:SetScript("OnLeave", function() border:SetBackdropBorderColor(1, 1, 1, 0.15) end)
	btn:SetScript("OnHide", function() if menu then menu:Hide() end end)

	AttachTooltip(f, tooltip)

	UpdateLabel()
	f._refresh = UpdateLabel
	f.button = btn
	return f, ROW_H
end

-- Text input (commits on Enter)

function W:TextInput(parent, text, y, getValue, setValue, tooltip)
	local f = MakeRow(parent, y)
	MakeLabel(f, text)

	local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
	box:SetSize(160, 22)
	box:SetPoint("RIGHT", f, "RIGHT", -CONTROL_PAD, 0)
	box:SetAutoFocus(false)
	box:SetFont(FONT, FONT_SIZE, "")
	box:SetTextColor(1, 1, 1, 0.9)
	box:SetBackdrop(INPUT_BACKDROP)
	box:SetBackdropColor(0.08, 0.10, 0.14, 0.9)
	box:SetBackdropBorderColor(1, 1, 1, 0.15)
	box:SetTextInsets(6, 6, 0, 0)
	box:SetText(getValue() or "")

	box:SetScript("OnEnterPressed", function(self)
		setValue(self:GetText())
		self:SetText(getValue() or "")
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText(getValue() or "")
		self:ClearFocus()
	end)

	AttachTooltip(f, tooltip)

	f._refresh = function() box:SetText(getValue() or "") end
	return f, ROW_H
end

-- Row with one or more buttons on the right: buttons = { {text, onClick}, ... }

function W:ButtonRow(parent, text, y, buttons, tooltip)
	local f = MakeRow(parent, y)
	MakeLabel(f, text)

	local anchor
	for i = #buttons, 1, -1 do
		local def = buttons[i]
		local btn = W:TextButton(f, def[1], def[2])
		if anchor then
			btn:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
		else
			btn:SetPoint("RIGHT", f, "RIGHT", -CONTROL_PAD, 0)
		end
		anchor = btn
		if def.update then
			-- allow labels that depend on state (e.g. "Cancel Pickup")
			btn:SetScript("OnUpdate", function(self) self:SetLabel(def.update()) end)
		end
	end

	AttachTooltip(f, tooltip)
	return f, ROW_H
end

-- Keybinding capture: click, then press a key combo. Esc cancels,
-- right-click clears.

function W:Keybind(parent, text, y, getValue, setValue, tooltip)
	local f = MakeRow(parent, y)
	MakeLabel(f, text)

	local btn = W:TextButton(f, "", nil, 160)
	btn:SetPoint("RIGHT", f, "RIGHT", -CONTROL_PAD, 0)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local listening = false

	local function Snap()
		if listening then
			btn:SetLabel("Press a key...")
			btn.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
		else
			local v = getValue()
			btn:SetLabel((v and v ~= "") and v or "Not bound")
			btn.label:SetTextColor(1, 1, 1, (v and v ~= "") and 0.9 or 0.4)
		end
	end

	local function Stop()
		listening = false
		btn:EnableKeyboard(false)
		Snap()
	end

	local IGNORED = {
		LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
		LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
	}

	btn:SetScript("OnClick", function(_, mouse)
		if InCombatLockdown() then return end
		if mouse == "RightButton" then
			setValue(nil)
			Stop()
			return
		end
		listening = not listening
		btn:EnableKeyboard(listening)
		Snap()
	end)

	btn:SetScript("OnKeyDown", function(self, key)
		if not listening then return end
		if IGNORED[key] then return end
		if key == "ESCAPE" then
			Stop()
			return
		end
		local combo = key
		if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
		if IsControlKeyDown() then combo = "CTRL-" .. combo end
		if IsAltKeyDown() then combo = "ALT-" .. combo end
		setValue(combo)
		Stop()
	end)
	btn:SetScript("OnHide", Stop)

	AttachTooltip(f, tooltip)
	Snap()
	f._refresh = Snap
	return f, ROW_H
end

-- Search box (no row chrome), returns the EditBox

function W:SearchBox(parent, width, onChange)
	local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	box:SetSize(width, 22)
	box:SetAutoFocus(false)
	box:SetFont(FONT, FONT_SIZE, "")
	box:SetTextColor(1, 1, 1, 0.9)
	box:SetBackdrop(INPUT_BACKDROP)
	box:SetBackdropColor(0.08, 0.10, 0.14, 0.9)
	box:SetBackdropBorderColor(1, 1, 1, 0.15)
	box:SetTextInsets(6, 6, 0, 0)

	local hint = box:CreateFontString(nil, "OVERLAY")
	hint:SetFont(FONT, 10, "")
	hint:SetPoint("LEFT", box, "LEFT", 7, 0)
	hint:SetText("Search name or source...")
	hint:SetTextColor(1, 1, 1, 0.3)

	box:SetScript("OnTextChanged", function(self)
		hint:SetShown(self:GetText() == "")
		onChange(self:GetText())
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	return box
end

-- Spacer

function W:Spacer(parent, y, height)
	height = height or 12
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(parent:GetWidth(), height)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	return f, height
end

-- Wrapped paragraph of dim text

function W:Paragraph(parent, text, y)
	local f = CreateFrame("Frame", nil, parent)
	local w = parent:GetWidth()
	f:SetWidth(w)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT, 10, "")
	fs:SetPoint("TOPLEFT", f, "TOPLEFT", LABEL_PAD, -6)
	fs:SetWidth(w - LABEL_PAD * 2)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	fs:SetSpacing(2)
	fs:SetTextColor(1, 1, 1, 0.55)
	fs:SetText(text)
	local h = math.ceil(fs:GetStringHeight()) + 12
	f:SetHeight(h)
	return f, h
end

-- Reset row counter (used when switching pages)

function W:ResetRowCounters(parent)
	if parent then
		rowCounters[parent] = 0
	else
		wipe(rowCounters)
	end
end
