Hearths.UI = {}
local UI = Hearths.UI

local CUSTOM_BUTTON_SIZE = 41

function UI:Initialize()
	self.hearthsButton = nil
	self.currentHearthstone = nil
	self.macroName = "HEARTHS_BTN"
	self.pendingMacroUpdate = nil
	self.triedRefreshInCombat = false
end

function UI:OnPlayerEnteringWorld()
	self.hearthsButton = self:CreateHearthstoneButton()

	if Hearths.db.profile.showCustomButton then
		self:ShowCustomButton()
	end
end

function UI:OnCombatEnd()
	-- Process any macro updates once out of combat
	if self.triedRefreshInCombat then
		self.triedRefreshInCombat = false
		Hearths.App:RefreshSelectedHearthstone()
	end

	if self.pendingMacroUpdate then
		self:UpdateMacro(self.pendingMacroUpdate)
		self.pendingMacroUpdate = nil
	end
end

function UI:OnDataUpdated(event, hearthstonesOptions)
	Hearths.Debug:Log("UI", "Data", "Hearthstone data updated")
end

function UI:OnSelectionChanged(event, selectedHearthstone)
	self.currentHearthstone = selectedHearthstone

	if selectedHearthstone then
		self:UpdateMacro(selectedHearthstone)
		self:UpdateCustomButtonAppearance(selectedHearthstone)
		Hearths.Debug:Log("UI", "Macro", "Updating macro:", selectedHearthstone.id, selectedHearthstone.kind)
	end
end

function UI:OnSelectionFailed(event, errorMessage)
	self:ShowErrorMessage(errorMessage or "No hearthstones available")
end

function UI:CreateHearthstoneButton()
	if self.hearthsButton then
		return self.hearthsButton
	end

	local frame = CreateFrame("Button", self.macroName, UIParent, "SecureActionButtonTemplate")
	frame:SetSize(1, 1)
	frame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
	frame:RegisterForClicks("AnyUp", "AnyDown")
	frame:SetAttribute("useOnKeyDown", false)

	local icon = frame:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints()
	icon:Hide()
	frame.icon = icon

	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	cooldown:SetAllPoints()
	frame.cooldown = cooldown

	self:ConfigureModifierKeys(frame)
	self:ConfigureKeybinding(frame)

	return frame
end

function UI:ConfigureModifierKeys(frame)
	local hearthstoneIDs = Hearths.App:GetHearthstoneIDs()

	-- Shift + click for Dalaran Hearthstone (if available)
	if PlayerHasToy(hearthstoneIDs.DALARAN) then
		frame:SetAttribute("shift-type1", "toy")
		frame:SetAttribute("shift-toy1", hearthstoneIDs.DALARAN)
	end

	-- Ctrl + click for Garrison Hearthstone (if available)
	if PlayerHasToy(hearthstoneIDs.GARRISON) then
		frame:SetAttribute("ctrl-type1", "toy")
		frame:SetAttribute("ctrl-toy1", hearthstoneIDs.GARRISON)
	end
end

function UI:ConfigureKeybinding(frame)
	if Hearths.db.profile.hearthsKeybinding then
		SetBindingClick(Hearths.db.profile.hearthsKeybinding, frame:GetName())
	end
end

function UI:UpdateKeybinding(oldBinding, newBinding)
	if not self.hearthsButton then return end

	if oldBinding and oldBinding ~= "" then
		SetBinding(oldBinding)
	end

	if newBinding and newBinding ~= "" then
		---@diagnostic disable-next-line: missing-parameter
		SetBindingClick(newBinding, self.hearthsButton:GetName())
	end
end

function UI:UpdateMacro(hearthstone)
	if InCombatLockdown() then
		Hearths.Debug:Log("UI", "Combat", "Combat lockdown active, deferring macro update")
		self.pendingMacroUpdate = hearthstone
		self.triedRefreshInCombat = true
		return
	end

	if not self.hearthsButton then
		Hearths.Debug:Log("UI", "Macro", "No hearthstone button available for macro update")
		return
	end

	self:ClearButtonAttributes()
	self:SetButtonAttributes(hearthstone)
	self:CreateOrUpdateMacroText(hearthstone)
end

function UI:ClearButtonAttributes()
	self.hearthsButton:ClearAttribute("*item1")
	self.hearthsButton:ClearAttribute("*toy1")
	self.hearthsButton:ClearAttribute("*spell1")
end

function UI:SetButtonAttributes(hearthstone)
	local button = self.hearthsButton
	local itemType = hearthstone.kind
	local id = hearthstone.id

	if itemType == "spell" then
		button:SetAttribute("type1", "spell")
		button:SetAttribute("*spell1", id)
	elseif itemType == "toy" then
		button:SetAttribute("type1", "toy")
		button:SetAttribute("*toy1", id)
	elseif itemType == "item" then
		button:SetAttribute("type1", "item")
		button:SetAttribute("*item1", "item:" .. id)
	else
		Hearths.Debug:Log("UI", "Attributes", "Unknown hearthstone type:", itemType)
	end
end

function UI:CreateOrUpdateMacroText(hearthstone)
	local tooltip = self:GetTooltipForHearthstone(hearthstone)
	local macroText = tooltip .. "\n/click " .. self.hearthsButton:GetName() .. "\n"

	local hasMacro = GetMacroIndexByName(self.macroName)
	if hasMacro > 0 then
		-- Update existing macro
		EditMacro(self.macroName, self.macroName, "INV_MISC_QUESTIONMARK", macroText)
		Hearths.Debug:Log("UI", "Macro", "Updated macro with " .. tostring(hearthstone.id) .. " (" .. hearthstone.kind .. ")")
	else
		-- Create new macro
		CreateMacro(self.macroName, "INV_MISC_QUESTIONMARK", macroText, true)
		Hearths.Debug:Log("UI", "Macro", "Created new macro")
	end
end

function UI:GetTooltipForHearthstone(hearthstone)
	if hearthstone.kind == "spell" then
		return "#showtooltip Astral Recall"
	else
		return "#showtooltip item:" .. hearthstone.id
	end
end

function UI:ShowErrorMessage(message)
	Hearths.Debug:Log("UI", "Error", message)
	Hearths:Print("WARNING: " .. message)
end

function UI:ToggleCustomButton(show)
	if InCombatLockdown() then
		Hearths:Print("Cannot toggle button during combat.")
		return
	end

	if show then
		self:ShowCustomButton()
	else
		self:HideCustomButton()
	end
end

function UI:ShowCustomButton()
	local button = self.hearthsButton
	if not button then return end
	if InCombatLockdown() then return end

	button:SetSize(CUSTOM_BUTTON_SIZE, CUSTOM_BUTTON_SIZE)
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:RegisterForDrag("LeftButton")

	-- Restore saved position or default to center
	button:ClearAllPoints()
	local pos = Hearths.db.profile.customButtonPosition
	if pos then
		button:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	else
		button:SetPoint("CENTER", UIParent, "CENTER")
	end

	button.icon:Show()

	button:SetScript("OnDragStart", function(frame)
		if IsAltKeyDown() then
			frame:StartMoving()
		end
	end)

	button:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		self:SaveCustomButtonPosition(frame)
	end)

	button:SetScript("OnEnter", function(frame)
		local hs = self.currentHearthstone
		if not hs then return end

		GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
		self:SetTooltipForHearthstone(hs)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Alt-drag to move | Shift: Dalaran | Ctrl: Garrison", 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	Hearths:RegisterEvent("SPELL_UPDATE_COOLDOWN", function()
		self:RefreshCustomButtonCooldown()
	end)

	if self.currentHearthstone then
		self:UpdateCustomButtonAppearance(self.currentHearthstone)
	end
end

function UI:HideCustomButton()
	local button = self.hearthsButton
	if not button then return end
	if InCombatLockdown() then return end

	Hearths:UnregisterEvent("SPELL_UPDATE_COOLDOWN")

	button:SetMovable(false)
	button:UnregisterForDrag("LeftButton")
	button:SetScript("OnDragStart", nil)
	button:SetScript("OnDragStop", nil)
	button:SetScript("OnEnter", nil)
	button:SetScript("OnLeave", nil)

	button.icon:Hide()
	button:SetSize(1, 1)
	button:ClearAllPoints()
	button:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
end

function UI:SaveCustomButtonPosition(frame)
	local point, _, relativePoint, x, y = frame:GetPoint()
	Hearths.db.profile.customButtonPosition = {
		point = point,
		relativePoint = relativePoint,
		x = x,
		y = y,
	}
end

function UI:UpdateCustomButtonAppearance(hearthstone)
	local button = self.hearthsButton
	if not button or not Hearths.db.profile.showCustomButton then return end

	local icon = self:GetIconForHearthstone(hearthstone)
	if icon then
		button.icon:SetTexture(icon)
	end

	self:RefreshCustomButtonCooldown()
end

function UI:RefreshCustomButtonCooldown()
	local button = self.hearthsButton
	if not button or not Hearths.db.profile.showCustomButton then return end
	if not self.currentHearthstone then return end

	local start, duration = self:GetCooldownForHearthstone(self.currentHearthstone)
	if start and duration and duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	else
		button.cooldown:Clear()
	end
end

function UI:GetIconForHearthstone(hearthstone)
	if hearthstone.kind == "spell" then
		return C_Spell.GetSpellTexture(hearthstone.id)
	elseif hearthstone.kind == "toy" then
		local _, _, icon = C_ToyBox.GetToyInfo(hearthstone.id)
		return icon
	elseif hearthstone.kind == "item" then
		return C_Item.GetItemIconByID(hearthstone.id)
	end
end

function UI:GetCooldownForHearthstone(hearthstone)
	if hearthstone.kind == "spell" then
		return C_Spell.GetSpellCooldown(hearthstone.id)
	else
		return C_Item.GetItemCooldown(hearthstone.id)
	end
end

function UI:SetTooltipForHearthstone(hearthstone)
	if hearthstone.kind == "spell" then
		GameTooltip:SetSpellByID(hearthstone.id)
	elseif hearthstone.kind == "toy" then
		GameTooltip:SetToyByItemID(hearthstone.id)
	elseif hearthstone.kind == "item" then
		GameTooltip:SetItemByID(hearthstone.id)
	end
end
