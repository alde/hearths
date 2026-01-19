-- Hearths Addon - Random Hearthstone Rotation
local addonName, addon = ...
local frame = nil
local cooldownFrame = nil
local currentHearthstone = nil
local hearthstoneToys = {}
local pendingRotation = false
local lastCooldownCheck = 0
local buttonVisible = true
local mouseoverVisible = false
local boundLocation = nil

-- Debug print function
local function DebugPrint(msg)
    if HearthsDB and HearthsDB.debug then
        print("|cFF888888[Hearths Debug]|r " .. msg)
    end
end

-- Initialize SavedVariables
local function InitializeSavedVars()
    local wasNew = HearthsDB == nil
    HearthsDB = HearthsDB or {}
    HearthsDB.position = HearthsDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    HearthsDB.debug = HearthsDB.debug or false
    if HearthsDB.useAllHearthstones == nil then
        HearthsDB.useAllHearthstones = true
    end
    if HearthsDB.includeStandardHearthstone == nil then
        HearthsDB.includeStandardHearthstone = true
    end
    HearthsDB.enabledHearthstones = HearthsDB.enabledHearthstones or {}
    HearthsDB.visibilityMode = HearthsDB.visibilityMode or "always"
    HearthsDB.usageStats = HearthsDB.usageStats or {}

    if wasNew then
        DebugPrint("SavedVariables initialized for first time - useAllHearthstones: " .. tostring(HearthsDB.useAllHearthstones))
    else
        DebugPrint("SavedVariables loaded - useAllHearthstones: " .. tostring(HearthsDB.useAllHearthstones) .. ", enabledHearthstones count: " .. tostring(#HearthsDB.enabledHearthstones))
    end
end


-- Function to update button visibility based on current mode
local function UpdateButtonVisibility()
    if not frame then
        return
    end

    local mode = HearthsDB.visibilityMode
    local shouldShow = false

    if mode == "always" then
        shouldShow = true
    elseif mode == "never" then
        shouldShow = false
    elseif mode == "mouseover" then
        shouldShow = mouseoverVisible
    else
        -- Default to always visible for unknown modes
        shouldShow = true
    end

    -- Only show if we have a current hearthstone
    if shouldShow and not currentHearthstone then
        shouldShow = false
    end

    -- Always keep frame shown for mouse events
    frame:Show()
    frame:SetAlpha(0)

    -- Handle always visible mode
    if mode == "always" then
        frame:Show()
        frame:SetAlpha(1)
        return
    end

    if mode == "mouseover" then
        frame:Show()
        -- TODO: fade in and out
        frame:SetAlpha(mouseoverVisible and 1 or 0)
    end

    if mode == "never" then
        frame:Hide()
        return
    end
end

-- Bad luck protection: Select hearthstone with weighted randomness
local function SelectHearthstoneWithLuckProtection(availableHearthstones)
    if #availableHearthstones == 0 then
        return nil
    end

    -- First check for any new hearthstones (0 uses) - always prioritize these
    for _, hearthstone in ipairs(availableHearthstones) do
        local usage = HearthsDB.usageStats[hearthstone.id] or 0
        if usage == 0 then
            DebugPrint("Selected new hearthstone (0 uses): " .. hearthstone.name)
            return hearthstone
        end
    end

    -- No new hearthstones, use weighted selection based on usage
    local maxUsage = 0
    for _, hearthstone in ipairs(availableHearthstones) do
        local usage = HearthsDB.usageStats[hearthstone.id] or 0
        if usage > maxUsage then
            maxUsage = usage
        end
    end

    -- Calculate weights (higher for less used hearthstones)
    local weights = {}
    local totalWeight = 0
    for _, hearthstone in ipairs(availableHearthstones) do
        local usage = HearthsDB.usageStats[hearthstone.id] or 0
        local weight = maxUsage - usage + 1  -- Ensure minimum weight of 1
        weights[hearthstone] = weight
        totalWeight = totalWeight + weight
        DebugPrint("  " .. hearthstone.name .. ": usage=" .. usage .. ", weight=" .. weight)
    end

    -- Select based on weights
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    for _, hearthstone in ipairs(availableHearthstones) do
        currentWeight = currentWeight + weights[hearthstone]
        if randomValue <= currentWeight then
            DebugPrint("Selected by weight: " .. hearthstone.name .. " (usage: " .. (HearthsDB.usageStats[hearthstone.id] or 0) .. ")")
            return hearthstone
        end
    end

    -- Fallback to first available (should never reach here)
    return availableHearthstones[1]
end

-- Function to increment usage stats when a hearthstone is used
local function IncrementHearthstoneUsage(hearthstone)
    if hearthstone and hearthstone.id then
        HearthsDB.usageStats[hearthstone.id] = (HearthsDB.usageStats[hearthstone.id] or 0) + 1
        DebugPrint("Incremented usage for " .. hearthstone.name .. " to " .. HearthsDB.usageStats[hearthstone.id])
    end
end


-- Function to check if a hearthstone is enabled for rotation
local function IsHearthstoneEnabled(hearthstone)
    -- If it's the standard hearthstone, check the specific setting
    if hearthstone.id == 6948 then
        return HearthsDB.includeStandardHearthstone
    end

    -- For all other hearthstones, use the existing logic
    if HearthsDB.useAllHearthstones then
        return true
    end
    return HearthsDB.enabledHearthstones[hearthstone.id] == true
end

-- Function to get cooldown information for different types
local function GetCooldownInfo(hearthstone)
    local startTime, duration = 0, 0

    if hearthstone.type == "toy" then
        startTime, duration = C_Item.GetItemCooldown(hearthstone.id)
    elseif hearthstone.type == "item" then
        startTime, duration = C_Item.GetItemCooldown(hearthstone.id)
    elseif hearthstone.type == "spell" then
        local cooldownInfo = C_Spell.GetSpellCooldown(hearthstone.id)
        if cooldownInfo then
            startTime, duration = cooldownInfo.startTime, cooldownInfo.duration
        end
    end

    return startTime, duration
end

-- Function to check if hearthstone is on cooldown
local function IsOnCooldown(hearthstone)
    local startTime, duration = GetCooldownInfo(hearthstone)
    if duration <= 0 then
        return false -- No cooldown active
    end
    local remaining = (startTime + duration) - GetTime()
    return remaining > 0.1 -- Add small buffer to avoid precision issues
end

-- Function to get remaining cooldown time
local function GetRemainingCooldown(hearthstone)
    local startTime, duration = GetCooldownInfo(hearthstone)
    if duration > 0 then
        local remaining = (startTime + duration) - GetTime()
        return math.max(0, remaining)
    end
    return 0
end

-- Function to validate that initialization was successful
local function ValidateInitialization()
    -- Check if any hearthstones were found
    if #hearthstoneToys == 0 then
        DebugPrint("Validation failed: No hearthstones found")
        return false
    end

    -- Check if at least one hearthstone is enabled
    local hasEnabledHearthstone = false
    for _, hearthstone in ipairs(hearthstoneToys) do
        if IsHearthstoneEnabled(hearthstone) then
            hasEnabledHearthstone = true
            break
        end
    end

    if not hasEnabledHearthstone then
        DebugPrint("Validation failed: No enabled hearthstones found")
        return false
    end

    DebugPrint("Validation passed: " .. #hearthstoneToys .. " hearthstones found, at least one enabled")
    return true
end

-- Function to update button attributes for a specific hearthstone
local function UpdateButtonForHearthstone(hearthstone)
    -- Set up modifier keys for Dalaran and Garrison hearthstones
    if PlayerHasToy(140192) then -- Dalaran Hearthstone
        frame:SetAttribute("shift-type1", "toy")
        frame:SetAttribute("shift-toy1", 140192)
    end
    if PlayerHasToy(110560) then -- Garrison Hearthstone
        frame:SetAttribute("ctrl-type1", "toy")
        frame:SetAttribute("ctrl-toy1", 110560)
    end

    -- Set up the button based on hearthstone type
    if hearthstone.type == "toy" then
        local _, toyName, toyTexture = C_ToyBox.GetToyInfo(hearthstone.id)
        frame:SetNormalTexture(toyTexture or hearthstone.icon)
        frame:SetAttribute("type1", "toy")
        frame:SetAttribute("*toy1", hearthstone.id)
    elseif hearthstone.type == "item" then
        frame:SetNormalTexture(hearthstone.icon)
        frame:SetAttribute("type1", "item")
        frame:SetAttribute("*item1", "item:" .. hearthstone.id)
    elseif hearthstone.type == "spell" then
        frame:SetNormalTexture(hearthstone.icon)
        frame:SetAttribute("type1", "spell")
        frame:SetAttribute("*spell1", hearthstone.id)
    end
end

-- Create a working hearthstone button using the pattern that works
local function CreateHearthstoneButton()
    -- Note: ScanHearthstoneToys() should be called before this function
    if #hearthstoneToys == 0 then
        DebugPrint("No hearthstone toys found!")
        return
    end

    -- Pick an available hearthstone for the button (same logic as rotation)
    local availableHearthstones = {}
    DebugPrint("Initial cooldown check for all hearthstones:")
    for _, hearthstone in ipairs(hearthstoneToys) do
        local onCooldown = IsOnCooldown(hearthstone)
        local enabled = IsHearthstoneEnabled(hearthstone)
        local remaining = GetRemainingCooldown(hearthstone)
        DebugPrint("  " .. hearthstone.name .. ": " .. (onCooldown and ("on cooldown (" .. math.floor(remaining) .. "s)") or "available") .. (enabled and "" or " (disabled)"))
        if not onCooldown and enabled then
            table.insert(availableHearthstones, hearthstone)
        end
    end

    -- If no hearthstones are available, find the enabled one with shortest cooldown
    if #availableHearthstones == 0 then
        DebugPrint("All enabled hearthstones on cooldown at startup, finding shortest cooldown")
        local shortestCooldown = nil
        local shortestTime = math.huge

        for _, hearthstone in ipairs(hearthstoneToys) do
            if IsHearthstoneEnabled(hearthstone) then
                local remaining = GetRemainingCooldown(hearthstone)
                if remaining < shortestTime then
                    shortestTime = remaining
                    shortestCooldown = hearthstone
                end
            end
        end

        if shortestCooldown then
            currentHearthstone = shortestCooldown
            DebugPrint("Selected hearthstone with shortest cooldown at startup: " .. currentHearthstone.name .. " (" .. math.floor(shortestTime) .. "s remaining)")
        end
    else
        -- Pick a hearthstone using bad luck protection
        currentHearthstone = SelectHearthstoneWithLuckProtection(availableHearthstones)
        if currentHearthstone then
            DebugPrint("Selected available hearthstone at startup: " .. currentHearthstone.name)
        end
    end

    frame = CreateFrame("Button", "Hearths", UIParent, "SecureActionButtonTemplate")
    frame:SetSize(41, 41)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Create cooldown overlay
    cooldownFrame = CreateFrame("Cooldown", "HearthsCooldown", frame, "CooldownFrameTemplate")
    cooldownFrame:SetAllPoints(frame)
    cooldownFrame:SetDrawBling(false)


    -- Set up the button for the current hearthstone
    if currentHearthstone then
        UpdateButtonForHearthstone(currentHearthstone)
        DebugPrint("Button configured for: " .. currentHearthstone.name)
    else
        DebugPrint("ERROR: No hearthstone selected, cannot configure button")
        return
    end

    -- Custom tooltip with modifier information
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        local hearthstoneToShow = currentHearthstone
        if IsShiftKeyDown() and PlayerHasToy(140192) then
            hearthstoneToShow = { id = 140192, type = "toy", name = "Dalaran Hearthstone" }
        elseif IsControlKeyDown() and PlayerHasToy(110560) then
            hearthstoneToShow = { id = 110560, type = "toy", name = "Garrison Hearthstone" }
        end

        if hearthstoneToShow then
            GameTooltip:AddLine(hearthstoneToShow.name, 1, 1, 1, 1)
            if boundLocation then
                GameTooltip:AddLine("Target: |cFFFF8000" .. boundLocation .. "|r", 1, 1, 1, 1)
            end
        else
            GameTooltip:AddLine("Hearths (No hearthstone selected)", 1, 0.5, 0.5, 1)
        end
        GameTooltip:AddLine(" ")
        if PlayerHasToy(140192) then
            GameTooltip:AddLine("Shift-click: Dalaran Hearthstone", 0.7, 0.7, 1, 1)
        end
        if PlayerHasToy(110560) then
            GameTooltip:AddLine("Ctrl-click: Garrison Hearthstone", 0.7, 0.7, 1, 1)
        end
        GameTooltip:AddLine("Alt-drag: Move button", 0.7, 0.7, 0.7, 1)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame:RegisterForClicks("AnyDown")

    -- Handle dragging to move the button
    frame:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, x, y = self:GetPoint()
        HearthsDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)

    -- Check for modifier keys before click to prevent rotation
    frame:SetScript("PreClick", function(self, button)
        if button == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() then
            -- This is a normal click, prepare for rotation
            pendingRotation = true
            DebugPrint("Clicked: " .. currentHearthstone.name .. " (pending rotation)")
        elseif button == "LeftButton" and IsShiftKeyDown() then
            -- Shift-click for Dalaran
            pendingRotation = false
            DebugPrint("Shift-clicked: Dalaran Hearthstone (no rotation)")
        elseif button == "LeftButton" and IsControlKeyDown() then
            -- Ctrl-click for Garrison
            pendingRotation = false
            DebugPrint("Ctrl-clicked: Garrison Hearthstone (no rotation)")
        else
            -- Other modifier click
            pendingRotation = false
            DebugPrint("Modifier click detected, no rotation")
        end
    end)

    -- Update cooldown display and modifier keys
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- Modifier key checks (run every frame for responsiveness)
        local shiftDown = IsShiftKeyDown()
        local ctrlDown = IsControlKeyDown()
        local modifierStateChanged = self.lastShiftDown ~= shiftDown or self.lastCtrlDown ~= ctrlDown

        if modifierStateChanged then
            self.lastShiftDown = shiftDown
            self.lastCtrlDown = ctrlDown

            local hearthstoneToSet = currentHearthstone
            if shiftDown and PlayerHasToy(140192) then
                hearthstoneToSet = { id = 140192, type = "toy", name = "Dalaran Hearthstone", icon = select(3, C_ToyBox.GetToyInfo(140192)) }
            elseif ctrlDown and PlayerHasToy(110560) then
                hearthstoneToSet = { id = 110560, type = "toy", name = "Garrison Hearthstone", icon = select(3, C_ToyBox.GetToyInfo(110560)) }
            end

            if hearthstoneToSet and hearthstoneToSet.icon then
                frame:SetNormalTexture(hearthstoneToSet.icon)
            elseif currentHearthstone and currentHearthstone.icon then
                frame:SetNormalTexture(currentHearthstone.icon)
            end

            if frame:IsMouseOver() then
                frame:GetScript("OnEnter")(frame)
            end
        end

        -- Cooldown checks (throttled to 1-second intervals)
        lastCooldownCheck = lastCooldownCheck + elapsed
        if lastCooldownCheck >= 1.0 then
            lastCooldownCheck = 0

            local hearthstoneForCooldown = currentHearthstone
            if shiftDown and PlayerHasToy(140192) then
                hearthstoneForCooldown = { id = 140192, type = "toy" }
            elseif ctrlDown and PlayerHasToy(110560) then
                hearthstoneForCooldown = { id = 110560, type = "toy" }
            end

            if hearthstoneForCooldown then
                local startTime, duration = GetCooldownInfo(hearthstoneForCooldown)
                if duration > 0 then
                    cooldownFrame:SetCooldown(startTime, duration)
                else
                    cooldownFrame:Clear()
                end
            else
                cooldownFrame:Clear()
            end
        end
    end)

    -- Restore saved position
    if HearthsDB.position then
        frame:ClearAllPoints()
        frame:SetPoint(HearthsDB.position.point, UIParent, HearthsDB.position.relativePoint, HearthsDB.position.x, HearthsDB.position.y)
    end

    DebugPrint("Created button for: " .. currentHearthstone.name .. " (ID: " .. currentHearthstone.id .. ")")

    -- Apply visibility settings
    UpdateButtonVisibility()

    -- Mouseover detection using direct button events
    local mouseoverTimer = nil

    -- Store original handlers
    local originalOnEnter = frame:GetScript("OnEnter")
    local originalOnLeave = frame:GetScript("OnLeave")

    frame:SetScript("OnEnter", function(self)
        if HearthsDB.visibilityMode == "mouseover" then
            -- Cancel any pending hide timer
            if mouseoverTimer then
                mouseoverTimer:Cancel()
                mouseoverTimer = nil
            end

            DebugPrint("Mouse entered button area")
            mouseoverVisible = true
            UpdateButtonVisibility()
        end

        -- Call original OnEnter for tooltip
        if originalOnEnter then
            originalOnEnter(self)
        end
    end)

    frame:SetScript("OnLeave", function(self)
        if HearthsDB.visibilityMode == "mouseover" then
            -- Add delay before hiding to prevent flickering
            if mouseoverTimer then
                mouseoverTimer:Cancel()
            end
            mouseoverTimer = C_Timer.NewTimer(0.3, function()
                if HearthsDB.visibilityMode == "mouseover" then
                    DebugPrint("Mouse left button area (delayed)")
                    mouseoverVisible = false
                    UpdateButtonVisibility()
                end
                mouseoverTimer = nil
            end)
        end

        -- Call original OnLeave for tooltip
        if originalOnLeave then
            originalOnLeave(self)
        end
    end)

end


-- Create a hidden tooltip for scanning item descriptions
local scanningTooltip = CreateFrame("GameTooltip", "HearthsScanningTooltip", UIParent, "GameTooltipTemplate")
scanningTooltip:SetOwner(UIParent, "ANCHOR_NONE") -- Ensures it's hidden

-- Function to get item description using GameTooltip
local function GetItemDescription(itemID)
    scanningTooltip:ClearLines()
    scanningTooltip:SetHyperlink("item:" .. itemID)

    local descriptionText = ""
    local numLines = scanningTooltip:NumLines()

    for i = 1, numLines do
        local line = _G["HearthsScanningTooltipTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            -- Skip the item name line and focus on description lines
            if i > 1 then -- Skip first line (item name)
                descriptionText = descriptionText .. text .. " "
            end
        end
    end

    scanningTooltip:ClearLines()
    return descriptionText
end

-- Scan for hearthstone toys the player owns
function ScanHearthstoneToys()
    DebugPrint("Starting hearthstone scan...")
    hearthstoneToys = {}

    -- Add the default hearthstone if enabled and owned
    if HearthsDB.includeStandardHearthstone and GetItemCount(6948) > 0 then
        local defaultHearthstone = {
            id = 6948,
            name = "Hearthstone",
            icon = "Interface\\Icons\\INV_Misc_Rune_01",
            type = "item"
        }
        table.insert(hearthstoneToys, defaultHearthstone)
        DebugPrint("Added to rotation: " .. defaultHearthstone.name)
    end

    -- Add Astral Recall if player is a Shaman
    local _, playerClass = UnitClass("player")
    if playerClass == "SHAMAN" then
        local astralRecall = {
            id = 556, -- Astral Recall spell ID
            name = "Astral Recall",
            icon = "Interface\\Icons\\Spell_Nature_AstralRecal",
            type = "spell"
        }
        table.insert(hearthstoneToys, astralRecall)
        DebugPrint("Added to rotation: " .. astralRecall.name)
    end

    -- Scan toy box for hearthstone toys (ignore current filters)
    local numToys = C_ToyBox.GetNumToys()
    DebugPrint("Scanning " .. numToys .. " toys in toy box...")
    for i = 1, numToys do
        local toyID = C_ToyBox.GetToyFromIndex(i)
        if toyID and toyID > 0 and C_ToyBox.IsToyUsable(toyID) and PlayerHasToy(toyID) then
            local itemID, toyName, icon = C_ToyBox.GetToyInfo(toyID)

            if toyName and type(toyName) == "string" then
                -- Get the item description using the GameTooltip method
                local description = GetItemDescription(toyID)
                local isHearthstone = false
                if string.find(description, "Returns you to (.*).") then
                    DebugPrint(description)
                    isHearthstone = true
                    if boundLocation == nil then
                        boundLocation = string.match(description, "Returns you to ([^%.]+).")
                    end
                end

                if isHearthstone then
                    local hearthstoneToy = {
                        id = toyID,
                        name = toyName,
                        icon = icon,
                        type = "toy"
                    }
                    table.insert(hearthstoneToys, hearthstoneToy)
                    DebugPrint("Added to rotation: " .. hearthstoneToy.name)
                end
            end
        end
    end

    DebugPrint("Found " .. #hearthstoneToys .. " usable hearthstones")
end

-- Create options panel with custom frame and proper icons
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "HearthsOptionsPanel", UIParent)
    panel.name = "Hearths"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Hearths Options")

    -- Debug Mode checkbox
    local debugCheckbox = CreateFrame("CheckButton", "HearthsDebugCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    debugCheckbox.Text:SetText("Enable Debug Logging")
    debugCheckbox:SetScript("OnClick", function(self)
        HearthsDB.debug = self:GetChecked()
        local status = self:GetChecked() and "enabled" or "disabled"
        print("|cFF00FF00[Hearths]|r Debug logging " .. status)
    end)

    -- Visibility Mode Section
    local visibilityHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibilityHeader:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -20)
    visibilityHeader:SetText("Button Visibility:")

    -- Visibility Mode Dropdown
    local visibilityDropdown = CreateFrame("Frame", "HearthsVisibilityDropdown", panel, "UIDropDownMenuTemplate")
    visibilityDropdown:SetPoint("TOPLEFT", visibilityHeader, "BOTTOMLEFT", -15, -5)
    UIDropDownMenu_SetWidth(visibilityDropdown, 150)
    UIDropDownMenu_SetText(visibilityDropdown, "Always Visible")

    local function VisibilityDropdown_OnClick(self)
        HearthsDB.visibilityMode = self.value
        UIDropDownMenu_SetText(visibilityDropdown, self:GetText())
        DebugPrint("Visibility mode changed to: " .. self.value)
        UpdateButtonVisibility()
        CloseDropDownMenus()
    end

    local function VisibilityDropdown_Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = "Always Visible"
        info.value = "always"
        info.func = VisibilityDropdown_OnClick
        info.checked = HearthsDB.visibilityMode == "always"
        UIDropDownMenu_AddButton(info)

        info.text = "Never Visible"
        info.value = "never"
        info.func = VisibilityDropdown_OnClick
        info.checked = HearthsDB.visibilityMode == "never"
        UIDropDownMenu_AddButton(info)


        info.text = "Show on Mouseover"
        info.value = "mouseover"
        info.func = VisibilityDropdown_OnClick
        info.checked = HearthsDB.visibilityMode == "mouseover"
        UIDropDownMenu_AddButton(info)
    end

    UIDropDownMenu_Initialize(visibilityDropdown, VisibilityDropdown_Initialize)

    -- Keybinding Information Section
    local keybindHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keybindHeader:SetPoint("TOPLEFT", visibilityDropdown, "BOTTOMLEFT", 15, -20)
    keybindHeader:SetText("Keybindings:")

    -- Create keybind text frame (will be updated dynamically)
    local keybindCurrent = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    keybindCurrent:SetPoint("TOPLEFT", keybindHeader, "BOTTOMLEFT", 0, -3)
    keybindCurrent:SetText("• Current binding: Loading...")
    keybindCurrent:SetTextColor(0.8, 0.8, 0.8)

    -- Store reference for dynamic updates
    panel.keybindCurrent = keybindCurrent

    -- Update keybinding text whenever the panel is shown
    panel:SetScript("OnShow", function()
        if panel.keybindCurrent then
            local currentKeybind = GetBindingKey("CLICK Hearths:LeftButton")
            if currentKeybind then
                panel.keybindCurrent:SetText("• Current binding: Random " .. currentKeybind .. ", Dalaran: Shift+" .. currentKeybind .. ", Garrison: Ctrl+" .. currentKeybind)
                panel.keybindCurrent:SetTextColor(0.5, 1, 0.5)
            else
                panel.keybindCurrent:SetText("• Current binding: None - Configure in Interface > Key Bindings > Hearths")
                panel.keybindCurrent:SetTextColor(0.8, 0.8, 0.8)
            end
        end
    end)

    -- Use All Hearthstones checkbox
    local useAllCheckbox = CreateFrame("CheckButton", "HearthsUseAllCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    useAllCheckbox:SetPoint("TOPLEFT", keybindCurrent, "BOTTOMLEFT", 0, -10)
    useAllCheckbox.Text:SetText("Use All Hearthstones")

    -- Include Standard Hearthstone checkbox
    local includeStandardCheckbox = CreateFrame("CheckButton", "HearthsIncludeStandardCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    includeStandardCheckbox:SetPoint("TOPLEFT", useAllCheckbox, "BOTTOMLEFT", 0, 0)
    includeStandardCheckbox.Text:SetText("Include Standard Hearthstone")
    includeStandardCheckbox:SetScript("OnClick", function(self)
        HearthsDB.includeStandardHearthstone = self:GetChecked()
        DebugPrint("Include Standard Hearthstone: " .. tostring(HearthsDB.includeStandardHearthstone))
        -- Rescan and update button if needed
        ScanHearthstoneToys()
        SetupRandomHearthstone()
    end)


    useAllCheckbox:SetScript("OnClick", function(self)
        HearthsDB.useAllHearthstones = self:GetChecked()
        if HearthsDB.useAllHearthstones then
            DebugPrint("Enabled all hearthstones for rotation")
            -- Also enable standard hearthstone
            HearthsDB.includeStandardHearthstone = true
            includeStandardCheckbox:SetChecked(true)
            includeStandardCheckbox:SetEnabled(false)

            for _, checkbox in pairs(panel.hearthstoneCheckboxes or {}) do
                checkbox:SetChecked(true)
                checkbox:SetEnabled(false)
            end
        else
            DebugPrint("Switched to custom hearthstone selection")
            includeStandardCheckbox:SetEnabled(true)
            for _, checkbox in pairs(panel.hearthstoneCheckboxes or {}) do
                checkbox:SetEnabled(true)
                checkbox:SetChecked(HearthsDB.enabledHearthstones[checkbox.hearthstoneId] == true)
            end
        end

        if currentHearthstone and not IsHearthstoneEnabled(currentHearthstone) then
            SetupRandomHearthstone()
        end
    end)

    -- Header for individual selections
    local customHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customHeader:SetPoint("TOPLEFT", includeStandardCheckbox, "BOTTOMLEFT", 0, -15)
    customHeader:SetText("Individual Hearthstone Selection:")

    -- Container for individual hearthstone checkboxes
    panel.hearthstoneCheckboxes = {}

    -- Create scrollable frame for hearthstone list
    local scrollFrame = CreateFrame("ScrollFrame", "HearthsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", customHeader, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 20)
    scrollFrame:SetSize(400, 200)

    local scrollChild = CreateFrame("Frame", "HearthsScrollChild", scrollFrame)
    scrollChild:SetSize(380, 1) -- Height will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)

    local function RefreshHearthstoneList()
        -- Always scan for hearthstones to ensure the list is up to date
        ScanHearthstoneToys()
        DebugPrint("RefreshHearthstoneList: Found " .. #hearthstoneToys .. " hearthstones after scan")

        -- Debug: list all hearthstones found
        for i, hearthstone in ipairs(hearthstoneToys) do
            DebugPrint("  " .. i .. ": " .. hearthstone.name .. " (ID: " .. hearthstone.id .. ")")
        end

        -- Safeguard: If no hearthstones found, ensure at least the default one exists
        if #hearthstoneToys == 0 and HearthsDB.includeStandardHearthstone then
            DebugPrint("No hearthstones found in scan, adding default hearthstone")
            local defaultHearthstone = {
                id = 6948,
                name = "Hearthstone",
                icon = "Interface\\Icons\\INV_Misc_Rune_01",
                type = "item"
            }
            table.insert(hearthstoneToys, defaultHearthstone)
        end

        -- Clear existing checkboxes
        for _, checkbox in pairs(panel.hearthstoneCheckboxes) do
            checkbox:Hide()
            checkbox:SetParent(nil)
        end
        panel.hearthstoneCheckboxes = {}

        -- If switching to custom mode for the first time, initialize all as enabled
        if not HearthsDB.useAllHearthstones and not next(HearthsDB.enabledHearthstones) then
            for _, hearthstone in ipairs(hearthstoneToys) do
                if hearthstone.id ~= 6948 then -- Don't add standard hearthstone to this list
                    HearthsDB.enabledHearthstones[hearthstone.id] = true
                end
            end
        end

        -- Create checkboxes for each hearthstone in scroll child
        local yOffset = -10
        for i, hearthstone in ipairs(hearthstoneToys) do
            -- Don't create a checkbox for the standard hearthstone
            if hearthstone.id ~= 6948 then
                local container = CreateFrame("Frame", "HearthsContainer" .. i, scrollChild)
                container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
                container:SetSize(350, 25)

                local icon = container:CreateTexture(nil, "ARTWORK")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", container, "LEFT", 0, 0)
                icon:SetTexture(hearthstone.icon)

                local checkbox = CreateFrame("CheckButton", "HearthsCheckbox" .. i, container, "InterfaceOptionsCheckButtonTemplate")
                checkbox:SetPoint("LEFT", icon, "RIGHT", 5, 0)
                checkbox.Text:SetText(hearthstone.name)
                checkbox.hearthstoneId = hearthstone.id

                checkbox:SetScript("OnClick", function(self)
                    if not HearthsDB.useAllHearthstones then
                        HearthsDB.enabledHearthstones[hearthstone.id] = self:GetChecked()
                        local status = self:GetChecked() and "enabled" or "disabled"
                        DebugPrint(hearthstone.name .. " " .. status)

                        local allEnabled = true
                        for _, h in ipairs(hearthstoneToys) do
                            if h.id ~= 6948 and not HearthsDB.enabledHearthstones[h.id] then
                                allEnabled = false
                                break
                            end
                        end
                        if allEnabled and HearthsDB.includeStandardHearthstone then
                            HearthsDB.useAllHearthstones = true
                            useAllCheckbox:SetChecked(true)
                            includeStandardCheckbox:SetEnabled(false)
                            for _, cb in pairs(panel.hearthstoneCheckboxes) do
                                cb:SetChecked(true)
                                cb:SetEnabled(false)
                            end
                            DebugPrint("All hearthstones enabled, switched back to 'Use All' mode")
                        end

                        if self:GetChecked() then
                            if not currentHearthstone or (frame and not frame:IsShown()) then
                                SetupRandomHearthstone()
                            end
                        else
                            if currentHearthstone and hearthstone.id == currentHearthstone.id then
                                SetupRandomHearthstone()
                            end
                        end
                    end
                end)

                panel.hearthstoneCheckboxes[i] = checkbox
                yOffset = yOffset - 30
            end
        end

        -- Set scroll child height based on content
        scrollChild:SetHeight(math.max(200, (#hearthstoneToys - 1) * 30 + 20))

        -- Set initial states
        debugCheckbox:SetChecked(HearthsDB.debug)
        useAllCheckbox:SetChecked(HearthsDB.useAllHearthstones)
        includeStandardCheckbox:SetChecked(HearthsDB.includeStandardHearthstone)

        local visibilityTexts = {
            always = "Always Visible",
            never = "Never Visible",
            mouseover = "Show on Mouseover"
        }
        UIDropDownMenu_SetText(visibilityDropdown, visibilityTexts[HearthsDB.visibilityMode] or "Always Visible")

        if HearthsDB.useAllHearthstones then
            includeStandardCheckbox:SetEnabled(false)
            for _, checkbox in pairs(panel.hearthstoneCheckboxes) do
                checkbox:SetChecked(true)
                checkbox:SetEnabled(false)
            end
        else
            includeStandardCheckbox:SetEnabled(true)
            for _, checkbox in pairs(panel.hearthstoneCheckboxes) do
                checkbox:SetEnabled(true)
                checkbox:SetChecked(HearthsDB.enabledHearthstones[checkbox.hearthstoneId] == true)
            end
        end
    end

    panel.RefreshHearthstoneList = RefreshHearthstoneList

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    panel.category = category

    return panel
end

-- Retry mechanism for initialization
local initializationRetries = 0
local initializationInProgress = false
local isInitialized = false
local maxRetries = 3

local function AttemptInitialization()
    if isInitialized then
        return
    end
    if initializationInProgress then
        DebugPrint("Initialization already in progress, skipping this attempt")
        return
    end
    initializationInProgress = true

    initializationRetries = initializationRetries + 1
    DebugPrint("Initialization attempt " .. initializationRetries .. "/" .. maxRetries)

    -- Scan for hearthstones first
    ScanHearthstoneToys()

    -- Validate that we have usable hearthstones
    if ValidateInitialization() then
        DebugPrint("Initialization successful, creating button")
        CreateHearthstoneButton()
        if not optionsPanel then
            optionsPanel = CreateOptionsPanel()
        end
        initializationInProgress = false
        isInitialized = true
    else
        if initializationRetries < maxRetries then
            initializationInProgress = false
            DebugPrint("Initialization failed, retrying in 3 seconds...")
            C_Timer.After(3, AttemptInitialization)
        else
            initializationInProgress = false
            DebugPrint("Initialization failed after " .. maxRetries .. " attempts. Toy box or SavedVariables may not be ready.")
        end
    end
end

-- Function to set up a new random hearthstone for the existing button
function SetupRandomHearthstone()
    if not frame or #hearthstoneToys == 0 then
        return
    end

    local availableHearthstones = {}
    local shortestCooldownHearthstones = {}
    local shortestTime = math.huge

    DebugPrint("Checking cooldowns for all hearthstones:")
    for _, hearthstone in ipairs(hearthstoneToys) do
        local onCooldown = IsOnCooldown(hearthstone)
        local enabled = IsHearthstoneEnabled(hearthstone)
        local remaining = GetRemainingCooldown(hearthstone)
        DebugPrint("  " .. hearthstone.name .. ": " .. (onCooldown and ("on cooldown (" .. math.floor(remaining) .. "s)") or "available") .. (enabled and "" or " (disabled)"))

        if enabled then
            -- 1. Check if any are off cooldown
            if not onCooldown then
                table.insert(availableHearthstones, hearthstone)
            else
                -- 2. Track shortest cooldown times
                if remaining < shortestTime then
                    shortestTime = remaining
                    shortestCooldownHearthstones = {hearthstone}
                elseif remaining == shortestTime then
                    table.insert(shortestCooldownHearthstones, hearthstone)
                end
            end
        end
    end

    -- 1. If any are off cooldown, pick one using bad luck protection
    if #availableHearthstones > 0 then
        currentHearthstone = SelectHearthstoneWithLuckProtection(availableHearthstones)
        if currentHearthstone then
            DebugPrint("Selected available hearthstone: " .. currentHearthstone.name)
        end
    -- 2. If not, pick from those with shortest cooldown using bad luck protection
    elseif #shortestCooldownHearthstones > 0 then
        currentHearthstone = SelectHearthstoneWithLuckProtection(shortestCooldownHearthstones)
        if currentHearthstone then
            DebugPrint("Selected hearthstone with shortest cooldown: " .. currentHearthstone.name .. " (" .. math.floor(shortestTime) .. "s remaining)")
        end
    else
        -- No enabled hearthstones found at all
        currentHearthstone = nil
        DebugPrint("No enabled hearthstones found, hiding button")
    end

    -- Update the button for the new hearthstone or hide it if none selected
    if currentHearthstone then
        UpdateButtonForHearthstone(currentHearthstone)
        UpdateButtonVisibility()
    else
        -- Hide the button when no hearthstones are enabled
        frame:Hide()
        DebugPrint("Button hidden - no enabled hearthstones")
    end

    if currentHearthstone then
        DebugPrint("Switched to: " .. currentHearthstone.name .. " (ID: " .. currentHearthstone.id .. ")")
    end
end

-- Initialize the addon
local eventFrame = CreateFrame("Frame")
local optionsPanel = nil
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leaving combat
eventFrame:RegisterEvent("NEW_TOY_ADDED")  -- New toy learned
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        DebugPrint("Addon loaded, initializing SavedVariables")
        InitializeSavedVars()
    elseif event == "PLAYER_LOGIN" then
        DebugPrint("Player logged in, attempting initialization")
        AttemptInitialization()
    elseif (event == "LOADING_SCREEN_DISABLED" or event == "UNIT_SPELLCAST_STOP") and pendingRotation then
        -- Loading screen ended, delay rotation to ensure cooldowns are updated
        -- But only if not in combat
        C_Timer.After(2.0, function()
            if pendingRotation and not UnitAffectingCombat("player") then
                -- Increment usage for the hearthstone that was just used
                if currentHearthstone then
                    IncrementHearthstoneUsage(currentHearthstone)
                end
                SetupRandomHearthstone()
                pendingRotation = false
                DebugPrint("Loading screen ended, rotated hearthstone")
            elseif pendingRotation and UnitAffectingCombat("player") then
                DebugPrint("Skipping rotation - player in combat")
                -- Keep pendingRotation true so it will rotate when combat ends
            end
        end)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" and arg1 == "player" and pendingRotation then
        -- Hearthstone cast was interrupted
        pendingRotation = false
        DebugPrint("Hearthstone interrupted, not rotating")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat - handle pending rotation when combat ends
        if pendingRotation then
            -- Increment usage for the hearthstone that was just used
            if currentHearthstone then
                IncrementHearthstoneUsage(currentHearthstone)
            end
            SetupRandomHearthstone()
            pendingRotation = false
            DebugPrint("Combat ended, rotated hearthstone")
        end
    elseif event == "NEW_TOY_ADDED" then
        -- Toy collection changed, check for new hearthstones
        DebugPrint("Toy collection updated, rescanning for hearthstones...")
        local oldCount = #hearthstoneToys
        ScanHearthstoneToys()
        local newCount = #hearthstoneToys

        if newCount > oldCount then
            DebugPrint("Found " .. (newCount - oldCount) .. " new hearthstone(s)!")
            -- If we found new hearthstones and no current one is selected, pick one
            if not currentHearthstone and frame then
                local availableHearthstones = {}
                for _, hearthstone in ipairs(hearthstoneToys) do
                    if not IsOnCooldown(hearthstone) and IsHearthstoneEnabled(hearthstone) then
                        table.insert(availableHearthstones, hearthstone)
                    end
                end

                if #availableHearthstones > 0 then
                    currentHearthstone = SelectHearthstoneWithLuckProtection(availableHearthstones)
                    if currentHearthstone then
                        UpdateButtonForHearthstone(currentHearthstone)
                        UpdateButtonVisibility()
                        DebugPrint("Auto-selected new hearthstone: " .. currentHearthstone.name)
                    end
                end
            end
        end

        -- Refresh options panel if it's open
        if optionsPanel and optionsPanel:IsShown() and optionsPanel.RefreshHearthstoneList then
            optionsPanel.RefreshHearthstoneList()
        end
    end
end)

-- Slash command to open settings
SLASH_HEARTHS1 = "/hearths"
SlashCmdList["HEARTHS"] = function(msg)
    if not optionsPanel then
        optionsPanel = CreateOptionsPanel()
    end
    -- Always refresh the hearthstone list when opening options
    if optionsPanel.RefreshHearthstoneList then
        optionsPanel.RefreshHearthstoneList()
    end
    Settings.OpenToCategory(optionsPanel.category:GetID())
end
