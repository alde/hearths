# Hearths

A WoW addon that randomly picks a hearthstone toy from your collection, with LiteMount-style priorities, cooldown handling, Shaman Astral Recall support, and a collection browser that tells you where to get the ones you're missing.

## What it does

Creates and manages a macro named `HEARTHS_BTN` that casts a random hearthstone from your collection. Drag it to your action bars from the settings window or from `/macro`.

## Features

- Detects every hearthstone toy you own (known catalogue + tooltip scan for brand-new ones)
- **Priorities** per hearthstone, like LiteMount: Never / Normal / More often (2x) / A lot more (6x) / Always
- **Collection page**: all hearthstones, collected and missing, with where/how to get each missing one, grouped into *obtainable now*, *seasonal*, *shop* and *no longer available*. Searchable by name, source, category or expansion.
- Skips hearthstones you can't use on the current character (covenant hearthstones, Draenic Hologem)
- Cooldown handling (skips toys on cooldown) and optional "avoid repeats"
- Optional Shaman Astral Recall fallback when everything is on cooldown
- Modifier keys - Shift for Dalaran Hearthstone, Ctrl for Garrison Hearthstone
- Configurable keybinding
- Profiles

## Commands

- `/hearths` - Open settings
- `/hearths collection` - Browse all hearthstones and set priorities
- `/hearths missing` - Print missing hearthstones and how to get them, and open the Missing view
- `/hearths list` - Show the current rotation
- `/hearths refresh` - Rescan toys and re-roll selection
- `/hearths debug on|off` - Enable/disable debug logging

## Settings

`/hearths`, or Options > AddOns > Hearths > Open Hearths Settings.

- **General**: pick up the macro, re-roll, keybinding, include the default Hearthstone, Astral Recall fallback, avoid repeats, default priority for new hearthstones
- **Collection**: every hearthstone with priority controls (click +/- or mouse wheel) and source info for missing ones. Shift-click links an item in chat.
- **Profiles**: switch, create, copy, delete, reset

## Adding a new hearthstone

New hearthstone toys work automatically as soon as you own one (tooltip scan). To give one source info and show it as "missing" to people who don't have it, add an entry to `Data.lua`.

## Dependencies

Ace3 (LibStub, CallbackHandler, AceAddon, AceEvent, AceDB, AceConsole) via `.pkgmeta` for CurseForge packaging.

## License

MIT
