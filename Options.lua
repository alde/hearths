Hearths.defaults = {
	profile = {
		useAllHearthstoneToys = true,
		includeDefaultHearthstone = false,
		includeAstralRecall = false,
		enabledHearthstones = {},
		availableHearthstones = {},
		debugMode = false,
		showCustomButton = false,
		customButtonPosition = nil,
	},
}

-- Convert hearthstone scan data to AceConfig options table format
function Hearths:ConvertHearthstonesToOptions(hearthstoneToys)
	local settings = {}
	for i, toy in pairs(hearthstoneToys) do
		settings[tostring(toy.id)] = {
			type = "toggle",
			order = i + 1,
			name = toy.name,
			image = toy.icon,
		}
	end
	return settings
end

Hearths.options = {
	type = "group",
	name = "Hearths - Hearthstone Randomizer",
	handler = Hearths,
	get = "GetValue",
	set = "SetValue",
	args = {
		macro = {
			type = "group",
			name = "Macro",
			order = 1,
			inline = true,
			args = {
				pickupMacro = {
					type = "execute",
					order = 1,
					name = function()
						if GetCursorInfo() then
							return "Cancel Pickup"
						end
						return "Pick Up Macro"
					end,
					desc = "Click to pick up the HEARTHS macro, then place it on your action bars. Click again to cancel.",
					func = function()
						if GetCursorInfo() then
							ClearCursor()
							return
						end
						local macroIndex = GetMacroIndexByName("HEARTHS_BTN")
						if macroIndex > 0 then
							PickupMacro(macroIndex)
						else
							Hearths:Print("No macro available yet. Try /hearths refresh first.")
						end
					end,
				},
				refreshMacro = {
					type = "execute",
					order = 2,
					name = "Refresh",
					desc = "Re-roll the random hearthstone selection",
					func = function()
						Hearths.App:RefreshSelectedHearthstone()
					end,
				},
			},
		},
		settings = {
			type = "group",
			name = "Settings",
			order = 5,
			inline = true,
			args = {
				showCustomButton = {
					type = "toggle",
					order = 1,
					name = "Show Custom Button",
					desc = "Show a movable on-screen button for your hearthstone. Alt-drag to reposition.",
				},
				debugMode = {
					type = "toggle",
					order = 2,
					name = "Debug Mode",
					desc = "Enable or Disable debug output",
				},
				hearthsKeybinding = {
					type = "keybinding",
					order = 3,
					name = "keybind",
					desc = "Random Hearthstone Keybind. Shift for Dalaran, Ctrl for Garrison.",
				},
			},
		},
		stones = {
			type = "group",
			name = "Stones",
			order = 10,
			inline = true,
			args = {
				useAllHearthstoneToys = {
					type = "toggle",
					order = 2,
					name = "Use All Hearthstone Toys",
					desc = function()
						local count = 0
						for _ in pairs(Hearths.db.profile.availableHearthstones) do count = count + 1 end
						return "Automatically include all Hearthstone toys in the randomizer (" .. count .. " found)"
					end,
				},
				includeDefaultHearthstone = {
					type = "toggle",
					order = 3,
					name = "Include Default Hearthstone",
					desc = function()
						if Hearths.App:IsDefaultHearthstoneAvailable() then
							return "Include default Hearthstone in the randomizer"
						else
							return "No default hearthstone available"
						end
					end,
					disabled = function()
						local unavailable = not Hearths.App:IsDefaultHearthstoneAvailable()
						Hearths.options.args.stones.args.includeDefaultHearthstone.descStyle = unavailable and "inline" or "tooltip"
						return unavailable
					end,
				},
				includeAstralRecall = {
					type = "toggle",
					order = 4,
					name = "Include Astral Recall",
					desc = function()
						if Hearths.App:IsPlayerShaman() then
							return "Include Astral Recall in the randomizer"
						else
							return "Only available for shamans"
						end
					end,
					disabled = function()
						local unavailable = not Hearths.App:IsPlayerShaman()
						Hearths.options.args.stones.args.includeAstralRecall.descStyle = unavailable and "inline" or "tooltip"
						return unavailable
					end,
				},
			},
		},
		selectedHearthstones = {
			type = "group",
			order = 20,
			name = "Available Hearthstones",
			disabled = function() return Hearths.db.profile.useAllHearthstoneToys end,
			set = function(info, value)
				Hearths.db.profile.enabledHearthstones[info[#info]] = value
			end,
			get = function(info) return Hearths.db.profile.enabledHearthstones[info[#info]] end,
			args = {},
		},
	},
}

function Hearths:GetValue(info)
	return self.db.profile[info[#info]]
end

function Hearths:SetValue(info, value)
	local settingKey = info[#info]
	local previousValue = self.db.profile[settingKey]

	self.db.profile[settingKey] = value

	if settingKey == "hearthsKeybinding" then
		self.UI:UpdateKeybinding(previousValue, value)
	elseif settingKey == "showCustomButton" then
		self.UI:ToggleCustomButton(value)
	end

	self.Debug:Log("Setting changed:", settingKey, tostring(value))
end
