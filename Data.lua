-- Catalogue of every known hearthstone toy that shares the regular
-- Hearthstone's cooldown, with where/how to get it.
--
-- Owned toys that are NOT in this list are still picked up by the toy box
-- scan (tooltip match), so a brand-new hearthstone works in the randomizer
-- before it's added here - it just won't have source info.
--
-- category: shown as a badge in the Collection page and used for filtering.
-- status:   "available"  - can be earned right now
--           "seasonal"   - only during a recurring world event
--           "shop"       - real-money (Battle.net / in-game shop)
--           "unavailable"- removed / promo ended (may return)
-- restrict: optional usability restriction checked before rolling.

Hearths.Data = {}
local Data = Hearths.Data

Data.CATEGORIES = {
	holiday     = "Holiday",
	raid        = "Raid Drop",
	dungeon     = "Dungeon",
	vendor      = "Vendor",
	quest       = "Quest",
	achievement = "Achievement",
	covenant    = "Covenant",
	profession  = "Profession",
	puzzle      = "Secret",
	shop        = "Shop",
	promo       = "Promotion",
}

Data.STATUS_LABEL = {
	available   = "Available",
	seasonal    = "Seasonal",
	shop        = "Shop",
	unavailable = "Unavailable",
}

-- Covenant IDs from C_Covenants.GetActiveCovenantID()
local KYRIAN, VENTHYR, NIGHT_FAE, NECROLORD = 1, 2, 3, 4

Data.HEARTHSTONES = {
	-- Holidays ----------------------------------------------------------
	{ id = 165669, name = "Lunar Elder's Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Lunar Festival (late Jan-Feb): Fariel Starsong in Nighthaven, Moonglade - 30 Coin of Ancestry." },
	{ id = 165670, name = "Peddlefeet's Lovely Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Love is in the Air (February): Kiera Torres / Lythianne Morningspear (Gala of Gifts) - 150 Love Tokens." },
	{ id = 165802, name = "Noble Gardener's Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Noblegarden (spring): Noblegarden Vendor/Merchant - 250 Noblegarden Chocolate." },
	{ id = 166746, name = "Fire Eater's Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Midsummer Fire Festival (June-July): Midsummer Supplier/Merchant in capitals - 300 Burning Blossoms." },
	{ id = 166747, name = "Brewfest Reveler's Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Brewfest (late Sep-early Oct): Belbi Quikswitch (Dun Morogh) / Blix Fixwidget (Durotar) - 200 Brewfest Prize Tokens." },
	{ id = 163045, name = "Headless Horseman's Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Hallow's End (mid Oct-Nov 1): Tricky Treats vendors - 150 Tricky Treats." },
	{ id = 162973, name = "Greatfather Winter's Hearthstone", category = "holiday", status = "seasonal", expansion = "BfA",
		source = "Feast of Winter Veil (Dec-Jan 2): loot from the Gently Shaken Gift under the tree in Orgrimmar/Ironforge." },

	-- Raid drops --------------------------------------------------------
	{ id = 209035, name = "Hearthstone of the Flame", category = "raid", status = "available", expansion = "Dragonflight",
		source = "Drop: Larodar, Keeper of the Flame - Amirdrassil, the Dream's Hope." },
	{ id = 236687, name = "Explosive Hearthstone", category = "raid", status = "available", expansion = "The War Within",
		source = "Drop: Stix Bunkjunker - Liberation of Undermine." },
	{ id = 246565, name = "Cosmic Hearthstone", category = "raid", status = "available", expansion = "The War Within",
		source = "Drop: Dimensius, the All-Devouring - Manaforge Omega." },
	{ id = 281615, name = "Shadeweaver's Hearthstone", category = "raid", status = "available", expansion = "Midnight", isNew = true,
		source = "Drop: Kith'ix (new raid in 12.1.5)." },

	-- Dungeons / world containers --------------------------------------
	{ id = 245970, name = "P.O.S.T. Master's Express Hearthstone", category = "dungeon", status = "available", expansion = "The War Within",
		source = "Loot the Mailroom Distribution inside the P.O.S.T. - Tazavesh, the Veiled Market (K'aresh)." },
	{ id = 188952, name = "Dominated Hearthstone", category = "dungeon", status = "available", expansion = "Shadowlands",
		source = "Reward from The Jailer's Gauntlet: Layer 2 in Torghast." },

	-- Vendors -----------------------------------------------------------
	{ id = 190237, name = "Broker Translocation Matrix", category = "vendor", status = "available", expansion = "Shadowlands",
		source = "Vilo in Zereth Mortis - 5,000 gold. Requires Exalted with the Enlightened." },
	{ id = 206195, name = "Path of the Naaru", category = "vendor", status = "available", expansion = "Legion",
		source = "Gaal at Krokul Hovel, Krokuun (Argus) - 90 Lightweave Cloth, 90 Empyrium, 900 Veiled Argunite. Requires the Scavenged Artifacts quest." },
	{ id = 228940, name = "Notorious Thread's Hearthstone", category = "vendor", status = "available", expansion = "The War Within",
		source = "Yamas the Provider, The Weaver's Lair (Azj-Kahet) - 3,000 Kej. Requires Mastermind with the Weaver, General or Vizier." },
	{ id = 235016, name = "Redeployment Module", category = "vendor", status = "available", expansion = "The War Within",
		source = "Reno Jackson - 5,000 Resonance Crystals." },
	{ id = 263933, name = "Preyseeker's Hearthstone", category = "vendor", status = "available", expansion = "Midnight",
		source = "Construct V'anore in Silvermoon - 800 Remnants of Anguish. Requires Preyseeker's Journey rank 6." },
	{ id = 265100, name = "Corewarden's Hearthstone", category = "vendor", status = "available", expansion = "Midnight",
		source = "Telemancer Astrandis in Silvermoon - 10 Voidlight Marl. Requires Delver's Journey rank 10." },

	-- Quests / achievements --------------------------------------------
	{ id = 257736, name = "Lightcalled Hearthstone", category = "quest", status = "available", expansion = "Midnight",
		source = "Quest reward: March on Quel'Danas." },
	{ id = 200630, name = "Ohn'ir Windsage's Hearthstone", category = "achievement", status = "available", expansion = "Dragonflight",
		source = "Achievement: Honor Our Ancestors (Ohn'ahran Plains)." },
	{ id = 210455, name = "Draenic Hologem", category = "quest", status = "available", expansion = "Dragonflight",
		source = "Draenei heritage questline - final quest Our Path Forward. Draenei / Lightforged only.",
		restrict = { race = { Draenei = true, LightforgedDraenei = true } } },

	-- Covenants (usable only while pledged to that covenant) -----------
	{ id = 184353, name = "Kyrian Hearthstone", category = "covenant", status = "available", expansion = "Shadowlands",
		source = "Adjutant Galos, Elysian Hold (Bastion) - 750 Reservoir Anima, Renown 11. Kyrian only.",
		restrict = { covenant = KYRIAN } },
	{ id = 183716, name = "Venthyr Sinstone", category = "covenant", status = "available", expansion = "Shadowlands",
		source = "Venthyr Sanctum anima vendor (Sinfall, Revendreth) - 750 Reservoir Anima, Renown 11. Venthyr only.",
		restrict = { covenant = VENTHYR } },
	{ id = 180290, name = "Night Fae Hearthstone", category = "covenant", status = "available", expansion = "Shadowlands",
		source = "Night Fae Sanctum anima vendor (Heart of the Forest, Ardenweald) - 750 Reservoir Anima, Renown 11. Night Fae only.",
		restrict = { covenant = NIGHT_FAE } },
	{ id = 182773, name = "Necrolord Hearthstone", category = "covenant", status = "available", expansion = "Shadowlands",
		source = "Necrolord Sanctum anima vendor (Seat of the Primus, Maldraxxus) - 750 Reservoir Anima, Renown 11. Necrolord only.",
		restrict = { covenant = NECROLORD } },

	-- Professions / secrets --------------------------------------------
	{ id = 64488, name = "The Innkeeper's Daughter", category = "profession", status = "available", expansion = "Cataclysm",
		source = "Archaeology: rare Dwarf artifact." },
	{ id = 168907, name = "Holographic Digitalization Hearthstone", category = "profession", status = "available", expansion = "BfA",
		source = "Junkyard Tinkering in Mechagon (Pascal-K1N6) - needs its blueprint." },
	{ id = 190196, name = "Enlightened Hearthstone", category = "puzzle", status = "available", expansion = "Shadowlands",
		source = "Six players using Sphere of Enlightened Cogitation on the pillars around the Forge of Afterlives (Zereth Mortis) open the Ponderer's Portal. Sphere comes from Enlightened Broker Supplies (paragon)." },

	-- Shop ---------------------------------------------------------------
	{ id = 172179, name = "Eternal Traveler's Hearthstone", category = "shop", status = "shop", expansion = "Shadowlands",
		source = "Battle.net Shop (originally Shadowlands Epic Edition)." },
	{ id = 193588, name = "Timewalker's Hearthstone", category = "shop", status = "shop", expansion = "Dragonflight",
		source = "Battle.net Shop (originally Dragonflight Epic Edition)." },
	{ id = 208704, name = "Deepdweller's Earthen Hearthstone", category = "shop", status = "shop", expansion = "The War Within",
		source = "Battle.net Shop (originally The War Within Epic Edition)." },
	{ id = 263489, name = "Naaru's Enfold", category = "shop", status = "shop", expansion = "Midnight",
		source = "Battle.net Shop - Outland Heroic Pack / Outland Epic Pack." },

	-- Promotions / retired ---------------------------------------------
	{ id = 54452, name = "Ethereal Portal", category = "promo", status = "unavailable", expansion = "Classic",
		source = "TCG loot card (Portal Stone) / 2023 Twitch drop. Not currently available; occasionally on the Black Market AH." },
	{ id = 93672, name = "Dark Portal", category = "promo", status = "unavailable", expansion = "Classic",
		source = "TCG loot card. Not currently available; occasionally on the Black Market AH." },
	{ id = 142542, name = "Tome of Town Portal", category = "promo", status = "unavailable", expansion = "Legion",
		source = "A Greedy Emissary (Diablo 20th anniversary) event. Event ended." },
	{ id = 212337, name = "Stone of the Hearth", category = "promo", status = "unavailable", expansion = "Dragonflight",
		source = "Dr. Boom during Hearthstone's 10th Anniversary event. Event ended." },
}

-- Separate cooldown, handled via modifier keys (not part of the rotation)
Data.SPECIAL = {
	DALARAN = 140192,
	GARRISON = 110560,
}

local byId
function Data:Get(id)
	if not byId then
		byId = {}
		for _, entry in ipairs(self.HEARTHSTONES) do
			byId[entry.id] = entry
		end
	end
	return byId[id]
end
