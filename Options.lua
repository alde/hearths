Hearths.defaults = {
	profile = {
		useAllHearthstoneToys = true,
		includeDefaultHearthstone = false,
		includeAstralRecall = false,
		enabledHearthstones = {},
		availableHearthstones = {},
		debugMode = false,
	},
}

function Hearths:Option_ConditionalTooltip(condition)
	if condition then
		return "tooltip"
	else
		return "inline"
	end
end

-- https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables
Hearths.options = {
	type = "group",
	name = "Hearths - Hearthstone Randomizer",
	handler = Hearths,
	get = "GetValue",
	set = "SetValue",
	args = {
		settings = {
			type = "group",
			name = "Settings",
			order = 5,
			inline = true,
			args = {
				debugMode = {
					type = "toggle",
					order = 1,
					name = "Debug Mode",
					desc = "Enable or Disable debug output",
				},
				hearthsKeybinding = {
					type = "keybinding",
					order = 2,
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
					desc = "Automatically include all Hearthstone toys in the randomizer",
				},
				includeDefaultHearthstone = {
					type = "toggle",
					order = 3,
					name = "Include Default Hearthstone",
					desc = function()
						if Hearths:IsDefaultHearthstoneAvailable() then
							return "Include default Hearthstone in the randomizer"
						else
							return "No default hearthstone available"
						end
					end,
					descStyle = Hearths:Option_ConditionalTooltip(Hearths:IsDefaultHearthstoneAvailable()),
					disabled = not Hearths:IsDefaultHearthstoneAvailable(),
				},
				includeAstralRecall = {
					type = "toggle",
					order = 4,
					name = "Include Astral Recall",
					desc = function ()
						if Hearths:IsPlayerShaman() then
							return "Include Astral Recall in the randomizer"
						else
							return "Only available for shamans"
						end
					end,
					descStyle = Hearths:Option_ConditionalTooltip(Hearths:IsPlayerShaman()),
					disabled = not Hearths:IsPlayerShaman()
				}
			}
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

-- for documentation on the info table
-- https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables#title-4-1
function Hearths:GetValue(info)
	return self.db.profile[info[#info]]
end

function Hearths:SetValue(info, value)
	local settingKey = info[#info]

	previousValue = self.db.profile[settingKey]

	self.db.profile[settingKey] = value

	if settingKey == "hearthsKeybinding" then
		if previousValue ~= "" then
			SetBinding(previousValue)
		end
		if value ~= "" then
			SetBindingClick(value, self.hearthsButton:GetName())
		end
	end

	Hearths:Debug(info[#info], tostring(value))
end
