# Hearths

Random hearthstone rotation addon for World of Warcraft.

## What it does

Provides a single button that cycles through your hearthstone collection. Automatically detects all hearthstones in your toy box and only uses ones that are off cooldown.

## Features

- Automatic hearthstone detection
- Smart cooldown management
- Custom hearthstone selection via options panel
- Button visibility modes (always visible, never visible, show on mouseover)
- Keybinding support for random hearthstone usage
- Additional keybindings for Dalaran and Garrison hearthstones
- Moveable button (Alt+drag)
- Works with Shaman Astral Recall

## Usage

**Button Interactions:**
- **Left-click**: Use current hearthstone and rotate to next
- **Shift-click**: Dalaran Hearthstone (if available)
- **Ctrl-click**: Garrison Hearthstone (if available)
- **Alt-drag**: Move button

**Keybindings:**
- Configure in Interface → Key Bindings → Hearths
- Available bindings:
  - "Use Random Hearthstone" - Uses current hearthstone and rotates to next
  - "Use Dalaran Hearthstone" - Direct access to Dalaran Hearthstone (if owned)
  - "Use Garrison Hearthstone" - Direct access to Garrison Hearthstone (if owned)
- Shows current binding status in settings panel

## Commands

```
/hearths             - Open settings panel
```

## Options

Access via `/hearths` command

- **Visibility modes**: Always visible, never visible, show on mouseover
- **Debug logging**: Toggle debug output
- **Hearthstone selection**: Choose "Use All" or select specific hearthstones
- **Individual toggles**: Enable/disable specific hearthstones with icons
- **Keybinding status**: Shows current keybinding configuration

## TODO

- ElvUI integration
- Masque support for button skinning
- Button scaling options

## License

MIT
