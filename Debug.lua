Hearths.Debug = {}

function Hearths.Debug:Log(...)
	if Hearths.db and Hearths.db.profile and Hearths.db.profile.debugMode then
		print("|cFFFF8040[Hearths]|r", ...)
	end
end
