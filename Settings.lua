-- Settings window: sidebar + scrolling content.
-- Pages: General, Collection (LiteMount-style list with priorities and
-- sources for missing hearthstones), Profiles.

local W = Hearths.Widgets

local PANEL_W = 680
local PANEL_H = 540
local SIDEBAR_W = 160
local HEADER_H = 36
local CONTENT_PAD = 12
local CONTENT_W = PANEL_W - SIDEBAR_W - CONTENT_PAD * 2

local ACCENT = W.ACCENT
local FONT = W.FONT
local BG_COLOR = { 0.05, 0.07, 0.09, 0.95 }
local SIDEBAR_BG = { 0.04, 0.05, 0.07, 0.95 }

local Settings_ = {}
Hearths.Settings = Settings_

local mainFrame, sidebar, scrollFrame, scrollChild
local sidebarButtons = {}
local activeCategory
local pageBuilders = {}
local SelectCategory
local GetScrollRange, UpdateScrollbar, SetScroll

local CATEGORIES = {
	{ key = "general",    label = "General" },
	{ key = "collection", label = "Collection" },
	{ key = "profiles",   label = "Profiles" },
}

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local BUTTON_H = 28
local BUTTON_PAD = 2

local function CreateSidebarButton(parent, catDef, index)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(SIDEBAR_W - 8, BUTTON_H)
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -(HEADER_H + 8 + (index - 1) * (BUTTON_H + BUTTON_PAD)))

	local label = btn:CreateFontString(nil, "OVERLAY")
	label:SetFont(FONT, 11, "")
	label:SetPoint("LEFT", btn, "LEFT", 12, 0)
	label:SetText(catDef.label)
	label:SetTextColor(1, 1, 1, 0.7)
	btn.label = label

	local indicator = btn:CreateTexture(nil, "OVERLAY")
	indicator:SetSize(3, BUTTON_H - 4)
	indicator:SetPoint("LEFT", btn, "LEFT", 0, 0)
	indicator:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0)
	btn.indicator = indicator

	local hover = btn:CreateTexture(nil, "BACKGROUND")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0)
	btn.hover = hover

	btn:SetScript("OnEnter", function()
		if activeCategory ~= catDef.key then hover:SetColorTexture(1, 1, 1, 0.04) end
	end)
	btn:SetScript("OnLeave", function()
		if activeCategory ~= catDef.key then hover:SetColorTexture(1, 1, 1, 0) end
	end)
	btn:SetScript("OnClick", function() SelectCategory(catDef.key) end)

	btn.catKey = catDef.key
	return btn
end

local function UpdateSidebarHighlight()
	for _, btn in ipairs(sidebarButtons) do
		if btn.catKey == activeCategory then
			btn.label:SetTextColor(1, 1, 1, 1)
			btn.indicator:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			btn.hover:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.08)
		else
			btn.label:SetTextColor(1, 1, 1, 0.7)
			btn.indicator:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0)
			btn.hover:SetColorTexture(1, 1, 1, 0)
		end
	end
end

local SCROLLBAR_W = 4
local SCROLLBAR_GAP = 14
local SCROLL_STEP = 40
local scrollTrack, scrollThumb

function GetScrollRange()
	if not (scrollFrame and scrollChild) then return 0 end
	return math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
end

function UpdateScrollbar()
	if not scrollTrack then return end
	local range = GetScrollRange()
	if range <= 0 then
		scrollTrack:Hide()
		if scrollFrame:GetVerticalScroll() ~= 0 then scrollFrame:SetVerticalScroll(0) end
		return
	end
	scrollTrack:Show()
	local trackH = scrollTrack:GetHeight()
	local viewH = scrollFrame:GetHeight()
	local thumbH = math.max(24, trackH * viewH / (viewH + range))
	scrollThumb:SetHeight(thumbH)
	local offset = scrollFrame:GetVerticalScroll()
	if offset > range then
		offset = range
		scrollFrame:SetVerticalScroll(range)
	end
	scrollThumb:ClearAllPoints()
	scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -((trackH - thumbH) * offset / range))
end

function SetScroll(value)
	if not scrollFrame then return end
	value = math.max(0, math.min(GetScrollRange(), value or 0))
	scrollFrame:SetVerticalScroll(value)
	UpdateScrollbar()
end

local function ClearContent()
	if not scrollChild then return end
	for _, child in ipairs({ scrollChild:GetChildren() }) do
		child:Hide()
		child:ClearAllPoints()
	end
	W:ResetRowCounters()
end

function SelectCategory(key)
	if not pageBuilders[key] then return end

	activeCategory = key
	ClearContent()
	UpdateSidebarHighlight()

	scrollChild:SetWidth(CONTENT_W)
	local y = pageBuilders[key](scrollChild, -CONTENT_PAD)
	scrollChild:SetHeight(math.abs(y) + CONTENT_PAD)
	SetScroll(0)
end

local function CreatePanel()
	if mainFrame then return mainFrame end

	mainFrame = CreateFrame("Frame", "HearthsSettings", UIParent, "BackdropTemplate")
	mainFrame:SetSize(PANEL_W, PANEL_H)
	mainFrame:SetPoint("CENTER")
	mainFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	mainFrame:SetBackdropColor(unpack(BG_COLOR))
	local _, classFile = UnitClass("player")
	local cc = classFile and ((C_ClassColor and C_ClassColor.GetClassColor(classFile)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
	if cc then
		mainFrame:SetBackdropBorderColor(cc.r, cc.g, cc.b, 1)
	else
		mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
	end
	mainFrame:SetFrameStrata("DIALOG")
	mainFrame:SetFrameLevel(100)
	mainFrame:SetClampedToScreen(true)
	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	mainFrame:Hide()

	tinsert(UISpecialFrames, "HearthsSettings")

	local title = mainFrame:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, 14, "")
	title:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", SIDEBAR_W + CONTENT_PAD, -10)
	title:SetText("Hearths Settings")
	title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

	local close = CreateFrame("Button", nil, mainFrame)
	close:SetSize(18, 18)
	close:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -8)
	local closeText = close:CreateFontString(nil, "OVERLAY")
	closeText:SetFont(FONT, 14, "")
	closeText:SetPoint("CENTER")
	closeText:SetText("x")
	closeText:SetTextColor(1, 1, 1, 0.5)
	close:SetScript("OnClick", function() mainFrame:Hide() end)
	close:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.3, 0.3) end)
	close:SetScript("OnLeave", function() closeText:SetTextColor(1, 1, 1, 0.5) end)

	sidebar = CreateFrame("Frame", nil, mainFrame)
	sidebar:SetSize(SIDEBAR_W, PANEL_H)
	sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)

	local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
	sidebarBg:SetAllPoints()
	sidebarBg:SetColorTexture(unpack(SIDEBAR_BG))

	local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY")
	sidebarTitle:SetFont(FONT, 13, "")
	sidebarTitle:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 16, -12)
	sidebarTitle:SetText("Hearths")
	sidebarTitle:SetTextColor(1, 1, 1, 0.9)

	local version = sidebar:CreateFontString(nil, "OVERLAY")
	version:SetFont(FONT, 9, "")
	version:SetPoint("LEFT", sidebarTitle, "RIGHT", 6, -1)
	version:SetText("v" .. (C_AddOns.GetAddOnMetadata("Hearths", "Version") or "?"))
	version:SetTextColor(1, 1, 1, 0.3)

	local sidebarSep = sidebar:CreateTexture(nil, "ARTWORK")
	sidebarSep:SetSize(1, PANEL_H)
	sidebarSep:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
	sidebarSep:SetColorTexture(1, 1, 1, 0.06)

	for i, catDef in ipairs(CATEGORIES) do
		sidebarButtons[i] = CreateSidebarButton(sidebar, catDef, i)
	end

	-- Plain scroll frame + thin flat scrollbar (no Blizzard arrows)
	scrollFrame = CreateFrame("ScrollFrame", "HearthsSettingsScroll", mainFrame)
	scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", SIDEBAR_W + 1, -(HEADER_H + 2))
	scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -SCROLLBAR_GAP, 6)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(_, delta)
		SetScroll(scrollFrame:GetVerticalScroll() - delta * SCROLL_STEP)
	end)

	scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(CONTENT_W, 1)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetScript("OnSizeChanged", function() UpdateScrollbar() end)
	scrollFrame:SetScript("OnSizeChanged", function() UpdateScrollbar() end)

	scrollTrack = CreateFrame("Frame", nil, mainFrame)
	scrollTrack:SetWidth(SCROLLBAR_W)
	scrollTrack:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -(HEADER_H + 4))
	scrollTrack:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 8)
	local trackBg = scrollTrack:CreateTexture(nil, "BACKGROUND")
	trackBg:SetAllPoints()
	trackBg:SetColorTexture(1, 1, 1, 0.04)

	scrollThumb = CreateFrame("Button", nil, scrollTrack)
	scrollThumb:SetWidth(SCROLLBAR_W)
	scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
	scrollThumb.tex = scrollThumb:CreateTexture(nil, "ARTWORK")
	scrollThumb.tex:SetAllPoints()
	scrollThumb.tex:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
	scrollThumb:SetScript("OnEnter", function(self) self.tex:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8) end)
	scrollThumb:SetScript("OnLeave", function(self)
		if not self.dragging then self.tex:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.45) end
	end)

	-- Drag the thumb
	scrollThumb:SetScript("OnMouseDown", function(self)
		local _, cy = GetCursorPosition()
		self.dragging = true
		self.startY = cy / self:GetEffectiveScale()
		self.startScroll = scrollFrame:GetVerticalScroll()
	end)
	scrollThumb:SetScript("OnMouseUp", function(self)
		self.dragging = false
		if not self:IsMouseOver() then self.tex:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.45) end
	end)
	scrollThumb:SetScript("OnUpdate", function(self)
		if not self.dragging then return end
		local _, cy = GetCursorPosition()
		cy = cy / self:GetEffectiveScale()
		local range = GetScrollRange()
		local travel = scrollTrack:GetHeight() - self:GetHeight()
		if range > 0 and travel > 0 then
			SetScroll(self.startScroll + (self.startY - cy) * range / travel)
		end
	end)

	-- Click on the track to jump a page
	scrollTrack:EnableMouse(true)
	scrollTrack:SetScript("OnMouseDown", function()
		local _, cy = GetCursorPosition()
		cy = cy / scrollTrack:GetEffectiveScale()
		local thumbTop = scrollThumb:GetTop() or 0
		local page = scrollFrame:GetHeight() - SCROLL_STEP
		if cy > thumbTop then
			SetScroll(scrollFrame:GetVerticalScroll() - page)
		else
			SetScroll(scrollFrame:GetVerticalScroll() + page)
		end
	end)
	scrollTrack:Hide()

	return mainFrame
end

---------------------------------------------------------------------------
-- General page
---------------------------------------------------------------------------

pageBuilders.general = function(parent, y)
	local db = Hearths.db.profile
	local App = Hearths.App
	local _, h

	_, h = W:SectionHeader(parent, "MACRO", y); y = y - h
	_, h = W:ButtonRow(parent, "HEARTHS_BTN macro", y, {
		{ "Pick Up Macro", function()
			if GetCursorInfo() then
				ClearCursor()
				return
			end
			local macroIndex = GetMacroIndexByName(Hearths.UI.macroName)
			if macroIndex > 0 then
				PickupMacro(macroIndex)
			else
				Hearths:Print("No macro yet. Try /hearths refresh first.")
			end
		end, update = function() return GetCursorInfo() and "Cancel Pickup" or "Pick Up Macro" end },
		{ "Re-roll", function() App:RefreshSelectedHearthstone(true) end },
	}, "Pick up the macro and drop it on an action bar. Shift uses the Dalaran Hearthstone, Ctrl the Garrison Hearthstone."); y = y - h
	_, h = W:Keybind(parent, "Keybinding", y,
		function() return db.hearthsKeybinding end,
		function(v)
			local old = db.hearthsKeybinding
			db.hearthsKeybinding = v
			Hearths.UI:UpdateKeybinding(old, v)
		end,
		"Click, then press a key. Right-click to clear. Shift/Ctrl on the same key use Dalaran/Garrison."); y = y - h

	_, h = W:SectionHeader(parent, "ROTATION", y); y = y - h
	_, h = W:Toggle(parent, "Include Default Hearthstone", y,
		function() return db.includeDefaultHearthstone end,
		function(v) db.includeDefaultHearthstone = v end,
		function()
			return App:IsDefaultHearthstoneAvailable() and "Add the plain Hearthstone item to the rotation."
				or "You don't have the Hearthstone item in your bags."
		end,
		function() return not App:IsDefaultHearthstoneAvailable() end); y = y - h
	_, h = W:Toggle(parent, "Astral Recall Fallback", y,
		function() return db.includeAstralRecall end,
		function(v) db.includeAstralRecall = v end,
		"Shaman only: use Astral Recall when every hearthstone is on cooldown.",
		function() return not App:IsPlayerShaman() end); y = y - h
	_, h = W:Toggle(parent, "Avoid Repeats", y,
		function() return db.avoidRepeat end,
		function(v) db.avoidRepeat = v end,
		"Never roll the same hearthstone twice in a row (when you have more than one)."); y = y - h
	_, h = W:Toggle(parent, "Favor Less-Used Hearthstones", y,
		function() return db.favorLessUsed end,
		function(v) db.favorLessUsed = v end,
		"Bad-luck protection: hearthstones you've used less than your favourite get rolled more often (up to "
			.. Hearths.MAX_LESS_USED_BOOST .. "x) until things even out. Priorities still apply on top."); y = y - h
	_, h = W:ButtonRow(parent, "Usage History", y, {
		{ "Reset", function()
			App:ResetUsage()
			Hearths:Print("Usage history cleared.")
		end },
	}, "Clear how many times this character has used each hearthstone."); y = y - h
	_, h = W:Toggle(parent, "Use New Hearthstones Right Away", y,
		function() return db.useNewImmediately end,
		function(v) db.useNewImmediately = v end,
		"When you learn a new hearthstone toy, put it on the Hearths button immediately so you can try it."); y = y - h
	_, h = W:Dropdown(parent, "Default Priority", y, Hearths.PRIORITY_LABELS,
		function() return db.defaultPriority end,
		function(v)
			db.defaultPriority = v
			Hearths:SendMessage("HEARTHS_PRIORITIES_CHANGED")
		end,
		{ 0, 1, 2, 3, 4 },
		"Priority for hearthstones you haven't set yourself, including new ones you collect."); y = y - h

	_, h = W:SectionHeader(parent, "MISC", y); y = y - h
	_, h = W:Toggle(parent, "Debug Logging", y,
		function() return db.debugMode end,
		function(v) db.debugMode = v end); y = y - h

	return y
end

---------------------------------------------------------------------------
-- Collection page
---------------------------------------------------------------------------

local STATUS_COLORS = {
	available   = { 0.30, 0.85, 0.45 },
	seasonal    = { 1.00, 0.75, 0.20 },
	shop        = { 0.35, 0.70, 1.00 },
	unavailable = { 0.55, 0.55, 0.55 },
}

local GROUPS = {
	{ key = "owned",       label = "COLLECTED" },
	{ key = "available",   label = "MISSING - OBTAINABLE NOW" },
	{ key = "seasonal",    label = "MISSING - SEASONAL EVENTS" },
	{ key = "shop",        label = "MISSING - SHOP" },
	{ key = "unavailable", label = "MISSING - NO LONGER AVAILABLE" },
}

local collection = {
	filter = "all",   -- all | owned | missing
	search = "",
	container = nil,
	rows = {},
	headers = {},
	listTop = 0,
}

local ROW_MIN_H = 40
local ICON_SZ = 28
local RIGHT_W = 118

local function MakePriorityStepper(row)
	local s = CreateFrame("Frame", nil, row)
	s:SetSize(RIGHT_W, 20)
	s:SetPoint("RIGHT", row, "RIGHT", -W.CONTROL_PAD, 0)

	local function Arrow(text, point, delta)
		local b = CreateFrame("Button", nil, s)
		b:SetSize(18, 20)
		b:SetPoint(point)
		local fs = b:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT, 13, "")
		fs:SetPoint("CENTER")
		fs:SetText(text)
		fs:SetTextColor(1, 1, 1, 0.6)
		b:SetScript("OnEnter", function() fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3]) end)
		b:SetScript("OnLeave", function() fs:SetTextColor(1, 1, 1, 0.6) end)
		b:SetScript("OnClick", function()
			local data = row.data
			if not data then return end
			Hearths:SetPriority(data.id, Hearths:GetPriority(data.id) + delta)
			data.priority = Hearths:GetPriority(data.id)
			row:Refresh()
		end)
		return b
	end
	s.minus = Arrow("-", "LEFT", -1)
	s.plus = Arrow("+", "RIGHT", 1)

	s.bg = s:CreateTexture(nil, "BACKGROUND")
	s.bg:SetPoint("LEFT", s.minus, "RIGHT", 2, 0)
	s.bg:SetPoint("RIGHT", s.plus, "LEFT", -2, 0)
	s.bg:SetHeight(18)

	s.text = s:CreateFontString(nil, "OVERLAY")
	s.text:SetFont(FONT, 10, "")
	s.text:SetPoint("CENTER", s.bg, "CENTER")
	s.text:SetTextColor(1, 1, 1, 0.95)

	-- Mouse wheel over the stepper also changes priority
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(_, delta)
		local data = row.data
		if not data then return end
		Hearths:SetPriority(data.id, Hearths:GetPriority(data.id) + delta)
		data.priority = Hearths:GetPriority(data.id)
		row:Refresh()
	end)
	return s
end

local function RowTooltip(row)
	local data = row.data
	if not data then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	if GameTooltip.SetToyByItemID and data.owned then
		GameTooltip:SetToyByItemID(data.id)
	else
		GameTooltip:SetItemByID(data.id)
	end
	if data.entry then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("How to get", ACCENT[1], ACCENT[2], ACCENT[3])
		GameTooltip:AddLine(data.entry.source, 1, 1, 1, true)
	end
	if data.owned and not data.usable then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(data.reason or "Not usable on this character", 1, 0.5, 0.25, true)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Shift-click to link in chat", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function CreateCollectionRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetWidth(CONTENT_W)

	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SZ, ICON_SZ)
	row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", W.LABEL_PAD, -6)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.stepper = MakePriorityStepper(row)

	row.status = row:CreateFontString(nil, "OVERLAY")
	row.status:SetFont(FONT, 10, "")
	row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", -W.CONTROL_PAD, -8)
	row.status:SetWidth(RIGHT_W)
	row.status:SetJustifyH("RIGHT")

	row.category = row:CreateFontString(nil, "OVERLAY")
	row.category:SetFont(FONT, 9, "")
	row.category:SetPoint("TOPRIGHT", row.status, "BOTTOMRIGHT", 0, -3)
	row.category:SetWidth(RIGHT_W)
	row.category:SetJustifyH("RIGHT")
	row.category:SetTextColor(1, 1, 1, 0.4)

	local textW = CONTENT_W - W.LABEL_PAD - ICON_SZ - 8 - RIGHT_W - W.CONTROL_PAD - 10

	row.name = row:CreateFontString(nil, "OVERLAY")
	row.name:SetFont(FONT, 11, "")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
	row.name:SetWidth(textW)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.name:SetMaxLines(1)

	row.sub = row:CreateFontString(nil, "OVERLAY")
	row.sub:SetFont(FONT, 9, "")
	row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
	row.sub:SetWidth(textW)
	row.sub:SetJustifyH("LEFT")
	row.sub:SetJustifyV("TOP")
	row.sub:SetWordWrap(true)
	row.sub:SetSpacing(1)

	row:SetScript("OnEnter", function(self)
		self.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.06)
		RowTooltip(self)
	end)
	row:SetScript("OnLeave", function(self)
		self:SetStripe(self.stripe)
		GameTooltip:Hide()
	end)
	row:SetScript("OnClick", function(self)
		if IsModifiedClick("CHATLINK") and self.data then
			local _, link = C_Item.GetItemInfo(self.data.id)
			if link then ChatEdit_InsertLink(link) end
		end
	end)

	function row:SetStripe(on)
		self.stripe = on
		self.bg:SetColorTexture(0, 0, 0, on and 0.15 or 0)
	end

	function row:Refresh()
		local data = self.data
		self.icon:SetTexture(data.icon or 134400)
		self.icon:SetDesaturated(not data.owned)
		self.icon:SetAlpha(data.owned and 1 or 0.6)
		self.name:SetText(data.name)

		local entry = data.entry
		local catLabel = entry and Hearths.Data.CATEGORIES[entry.category] or "Other"
		if entry and entry.isNew then catLabel = "NEW - " .. catLabel end

		if data.owned then
			self.name:SetTextColor(1, 1, 1, 0.95)
			self.status:Hide()
			self.category:Hide()
			if data.usable then
				self.stepper:Show()
				local p = data.priority
				local c = Hearths.PRIORITY_COLORS[p]
				self.stepper.bg:SetColorTexture(c[1], c[2], c[3], 0.33)
				self.stepper.text:SetText(Hearths.PRIORITY_LABELS[p])
				self.stepper.minus:SetShown(p > Hearths.PRIORITY_MIN)
				self.stepper.plus:SetShown(p < Hearths.PRIORITY_MAX)
				local uses = Hearths.App:GetUsage(data.id)
				local usedText = uses > 0 and ("  -  used " .. uses .. "x") or "  -  never used"
				self.sub:SetText((entry and (catLabel .. "  -  " .. (entry.expansion or "")) or "Not in catalogue yet (found by tooltip)") .. usedText)
				self.sub:SetTextColor(1, 1, 1, 0.45)
			else
				self.stepper:Hide()
				self.status:Show()
				self.status:SetText("Can't use")
				self.status:SetTextColor(1, 0.5, 0.25)
				self.sub:SetText(data.reason or "Not usable on this character")
				self.sub:SetTextColor(1, 0.5, 0.25, 0.8)
			end
		else
			self.stepper:Hide()
			self.name:SetTextColor(1, 1, 1, 0.7)
			self.status:Show()
			self.category:Show()
			local c = STATUS_COLORS[entry.status] or STATUS_COLORS.unavailable
			self.status:SetText(Hearths.Data.STATUS_LABEL[entry.status] or entry.status)
			self.status:SetTextColor(c[1], c[2], c[3])
			self.category:SetText(catLabel)
			self.sub:SetText(entry.source)
			self.sub:SetTextColor(1, 1, 1, 0.6)
		end

		local textH = 14 + 3 + math.ceil(self.sub:GetStringHeight())
		self:SetHeight(math.max(ROW_MIN_H, textH + 14))
	end

	return row
end

local function CreateGroupHeader(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(CONTENT_W, 30)
	f.label = f:CreateFontString(nil, "OVERLAY")
	f.label:SetFont(FONT, 10, "")
	f.label:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", W.LABEL_PAD, 6)
	f.label:SetTextColor(1, 1, 1, 0.4)
	local sep = f:CreateTexture(nil, "ARTWORK")
	sep:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", W.LABEL_PAD, 0)
	sep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -W.LABEL_PAD, 0)
	sep:SetHeight(1)
	sep:SetColorTexture(1, 1, 1, 0.06)
	return f
end

local function Matches(data, search)
	if search == "" then return true end
	if string.find(data.name:lower(), search, 1, true) then return true end
	local entry = data.entry
	if entry then
		if string.find(entry.source:lower(), search, 1, true) then return true end
		if string.find((Hearths.Data.CATEGORIES[entry.category] or ""):lower(), search, 1, true) then return true end
		if entry.expansion and string.find(entry.expansion:lower(), search, 1, true) then return true end
	end
	return false
end

local function LayoutCollectionList()
	local container = collection.container
	if not container then return end

	local all = Hearths.App:GetCollection()
	local search = collection.search:lower()

	local grouped = {}
	for _, g in ipairs(GROUPS) do grouped[g.key] = {} end
	for _, data in ipairs(all) do
		if Matches(data, search) then
			local key = data.owned and "owned" or data.entry.status
			local include = collection.filter == "all"
				or (collection.filter == "owned" and data.owned)
				or (collection.filter == "missing" and not data.owned)
			if include and grouped[key] then
				table.insert(grouped[key], data)
			end
		end
	end

	for _, r in ipairs(collection.rows) do r:Hide() end
	for _, hdr in ipairs(collection.headers) do hdr:Hide() end

	local y, rowIndex, headerIndex = 0, 0, 0
	for _, g in ipairs(GROUPS) do
		local list = grouped[g.key]
		if #list > 0 then
			table.sort(list, function(a, b) return a.name < b.name end)

			headerIndex = headerIndex + 1
			local hdr = collection.headers[headerIndex]
			if not hdr then
				hdr = CreateGroupHeader(container)
				collection.headers[headerIndex] = hdr
			end
			hdr:ClearAllPoints()
			hdr:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
			hdr.label:SetText(g.label .. "  (" .. #list .. ")")
			hdr:Show()
			y = y - 30

			for i, data in ipairs(list) do
				rowIndex = rowIndex + 1
				local row = collection.rows[rowIndex]
				if not row then
					row = CreateCollectionRow(container)
					collection.rows[rowIndex] = row
				end
				row.data = data
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
				row:SetStripe(i % 2 == 0)
				row:Refresh()
				row:Show()
				y = y - row:GetHeight()
			end
		end
	end

	if rowIndex == 0 then
		headerIndex = headerIndex + 1
		local hdr = collection.headers[headerIndex] or CreateGroupHeader(container)
		collection.headers[headerIndex] = hdr
		hdr:ClearAllPoints()
		hdr:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
		hdr.label:SetText("NOTHING MATCHES")
		hdr:Show()
		y = y - 30
	end

	container:SetHeight(math.abs(y) + 1)
	scrollChild:SetHeight(math.abs(collection.listTop) + math.abs(y) + CONTENT_PAD)
end

local function UpdateSummary()
	local s = collection.summary
	if not s then return end
	local have, total = Hearths.App:GetCollectionCounts()
	s.text:SetText(string.format("Collected  |cffffffff%d|r / %d", have, total))
	local ratio = total > 0 and have / total or 0
	s.fill:SetWidth(math.max(1, s.barW * ratio))
end

pageBuilders.collection = function(parent, y)
	-- Summary row: count + progress bar
	local summary = CreateFrame("Frame", nil, parent)
	summary:SetSize(CONTENT_W, 34)
	summary:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	summary.text = summary:CreateFontString(nil, "OVERLAY")
	summary.text:SetFont(FONT, 12, "")
	summary.text:SetPoint("LEFT", summary, "LEFT", W.LABEL_PAD, 0)
	summary.text:SetTextColor(1, 1, 1, 0.6)
	summary.barW = 200
	local barBg = summary:CreateTexture(nil, "BACKGROUND")
	barBg:SetSize(summary.barW, 6)
	barBg:SetPoint("RIGHT", summary, "RIGHT", -W.CONTROL_PAD, 0)
	barBg:SetColorTexture(1, 1, 1, 0.08)
	summary.fill = summary:CreateTexture(nil, "ARTWORK")
	summary.fill:SetHeight(6)
	summary.fill:SetPoint("LEFT", barBg, "LEFT")
	summary.fill:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
	collection.summary = summary
	UpdateSummary()
	y = y - 34

	-- Search + filter tabs
	local controls = CreateFrame("Frame", nil, parent)
	controls:SetSize(CONTENT_W, 30)
	controls:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)

	local search = W:SearchBox(controls, 190, function(text)
		collection.search = text or ""
		LayoutCollectionList()
	end)
	search:SetPoint("LEFT", controls, "LEFT", W.LABEL_PAD, 0)
	search:SetText(collection.search)

	local tabs = {}
	local function SnapTabs()
		for key, tab in pairs(tabs) do
			if key == collection.filter then
				tab:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
				tab.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
			else
				tab:SetBackdropBorderColor(1, 1, 1, 0.2)
				tab.label:SetTextColor(1, 1, 1, 0.8)
			end
		end
	end
	local anchor
	for _, def in ipairs({ { "missing", "Missing" }, { "owned", "Collected" }, { "all", "All" } }) do
		local key = def[1]
		local tab = W:TextButton(controls, def[2], function()
			collection.filter = key
			SnapTabs()
			LayoutCollectionList()
		end, 72)
		tab:SetScript("OnLeave", SnapTabs)
		if anchor then
			tab:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
		else
			tab:SetPoint("RIGHT", controls, "RIGHT", -W.CONTROL_PAD, 0)
		end
		anchor = tab
		tabs[key] = tab
	end
	SnapTabs()
	y = y - 30

	-- Bulk priority buttons
	local _, h = W:ButtonRow(parent, "Set every collected hearthstone to", y, {
		{ "Never", function()
			local ids = {}
			for id in pairs(Hearths.App.owned) do ids[#ids + 1] = id end
			Hearths:SetAllPriorities(ids, Hearths.PRIORITY.NEVER)
		end },
		{ "Normal", function()
			local ids = {}
			for id in pairs(Hearths.App.owned) do ids[#ids + 1] = id end
			Hearths:SetAllPriorities(ids, Hearths.PRIORITY.NORMAL)
		end },
	}, "Priority: Never = skip, More often = 2x, A lot more = 6x. If anything is set to Always, only the Always ones are used.")
	y = y - h

	-- The list lives in its own container so typing in the search box
	-- only re-lays the rows (and keeps focus).
	if not collection.container then
		collection.container = CreateFrame("Frame", nil, parent)
		collection.container:SetWidth(CONTENT_W)
	end
	collection.container:SetParent(parent)
	collection.container:ClearAllPoints()
	collection.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	collection.container:Show()
	collection.listTop = y

	LayoutCollectionList()
	return y - collection.container:GetHeight()
end

---------------------------------------------------------------------------
-- Profiles page
---------------------------------------------------------------------------

local function ProfileValues()
	local vals = {}
	for _, name in ipairs(Hearths.db:GetProfiles()) do
		vals[name] = name
	end
	return vals
end

local function OtherProfileValues()
	local vals = {}
	local current = Hearths.db:GetCurrentProfile()
	for _, name in ipairs(Hearths.db:GetProfiles()) do
		if name ~= current then vals[name] = name end
	end
	return vals
end

pageBuilders.profiles = function(parent, y)
	local db = Hearths.db
	local _, h

	_, h = W:SectionHeader(parent, "PROFILE", y); y = y - h
	_, h = W:Paragraph(parent, "Priorities and settings are saved per profile. By default every character has its own.", y); y = y - h
	_, h = W:Dropdown(parent, "Active Profile", y, ProfileValues,
		function() return db:GetCurrentProfile() end,
		function(v)
			db:SetProfile(v)
			SelectCategory("profiles")
		end); y = y - h
	_, h = W:TextInput(parent, "New Profile", y,
		function() return "" end,
		function(v)
			if v and v ~= "" then
				db:SetProfile(v)
				SelectCategory("profiles")
			end
		end,
		"Type a name and press Enter to create and switch to it."); y = y - h

	_, h = W:SectionHeader(parent, "MANAGE", y); y = y - h
	_, h = W:Dropdown(parent, "Copy From", y, OtherProfileValues,
		function() return nil end,
		function(v)
			db:CopyProfile(v)
			Hearths:Print("Copied profile '" .. v .. "' into '" .. db:GetCurrentProfile() .. "'.")
			SelectCategory("profiles")
		end,
		nil, "Overwrite the active profile with a copy of another one."); y = y - h
	_, h = W:Dropdown(parent, "Delete Profile", y, OtherProfileValues,
		function() return nil end,
		function(v)
			db:DeleteProfile(v)
			Hearths:Print("Deleted profile '" .. v .. "'.")
			SelectCategory("profiles")
		end,
		nil, "Delete another profile. The active profile can't be deleted."); y = y - h
	_, h = W:ButtonRow(parent, "Reset Active Profile", y, {
		{ "Reset", function()
			db:ResetProfile()
			Hearths:Print("Profile reset to defaults.")
			SelectCategory("profiles")
		end },
	}, "Restore all settings and priorities in this profile to their defaults."); y = y - h

	return y
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function Settings_:Open(category)
	if InCombatLockdown() then
		Hearths:Print("Cannot open settings during combat.")
		return
	end
	local panel = CreatePanel()
	panel:Show()
	SelectCategory(category or activeCategory or "general")
end

function Settings_:OpenCollection(filter)
	if filter then collection.filter = filter end
	self:Open("collection")
end

function Settings_:Toggle(category)
	if mainFrame and mainFrame:IsShown() and (not category or category == activeCategory) then
		mainFrame:Hide()
	else
		self:Open(category)
	end
end

-- Called when toy data / priorities / profiles change
function Settings_:Refresh()
	if not (mainFrame and mainFrame:IsShown()) then return end
	if activeCategory == "collection" then
		UpdateSummary()
		LayoutCollectionList()
	end
end

function Settings_:OnProfileChanged()
	if mainFrame and mainFrame:IsShown() and activeCategory then
		SelectCategory(activeCategory)
	end
end

-- Stub in the Blizzard AddOns settings list that opens our window
if Settings and Settings.RegisterCanvasLayoutCategory then
	local redirect = CreateFrame("Frame")
	redirect.name = "Hearths"

	local btn = CreateFrame("Button", nil, redirect, "UIPanelButtonTemplate")
	btn:SetSize(200, 30)
	btn:SetPoint("CENTER")
	btn:SetText("Open Hearths Settings")
	btn:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end
		C_Timer.After(0, function() Settings_:Open() end)
	end)

	local category = Settings.RegisterCanvasLayoutCategory(redirect, "Hearths")
	Settings.RegisterAddOnCategory(category)
end
