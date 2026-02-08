# Hearths

A WoW addon that randomly selects from your hearthstone toys, with cooldown management and Shaman Astral Recall support.

## What it does

Creates and manages a macro named `HEARTHS_BTN` that casts a random hearthstone from your collection. Drag it to your action bars from the options panel or from `/macro`.

## Features

- Scans your toy box for all hearthstone toys automatically
- Randomizes hearthstone selection on each use
- Cooldown handling (skips toys on cooldown)
- Optional Shaman Astral Recall fallback when toys are on cooldown
- Modifier keys - Shift for Dalaran Hearthstone, Ctrl for Garrison Hearthstone
- Configurable keybinding
- Excludes non-hearthstone toys with tooltips that look like hearthstones

## Commands

- `/hearths` - Open settings panel
- `/hearths list` - Show currently enabled hearthstones
- `/hearths refresh` - Rescan toys and re-roll selection
- `/hearths debug on|off` - Enable/disable debug logging

## Options

Available in the WoW addon settings panel (Options > Addons > Hearths) or via `/hearths`.

- Pick Up Macro: Click to put the HEARTHS_BTN macro on your cursor for action bar placement
- Use All Hearthstone Toys: Include all detected hearthstone toys in rotation
- Include Default Hearthstone: Add the standard Hearthstone item to rotation (if available)
- Include Astral Recall: Add Astral Recall for Shaman characters
- Individual Hearthstone Toggles: Fine-grained control when "Use All" is disabled
- Keybinding: Custom hotkey (With hard-coded modifiers Shift for Dalaran, Ctrl for Garrison)

## Dependencies

Ace3 libraries managed via `.pkgmeta` for CurseForge packaging.

## License

MIT
