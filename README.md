# Hearths

Random hearthstone rotation addon for World of Warcraft.

## What it does

Provides a single button that cycles through your hearthstone collection. Automatically detects all hearthstones in your toy box and only uses ones that are off cooldown.

## Features

- Automatic hearthstone detection
- Smart cooldown management
- Custom hearthstone selection via options panel
- Moveable button (Alt+drag)
- Works with Shaman Astral Recall

## Usage

**Left-click**: Use current hearthstone and rotate to next
**Shift-click**: Dalaran Hearthstone (if available)
**Ctrl-click**: Garrison Hearthstone (if available)
**Alt-drag**: Move button

## Commands

```
/hearths options     - Open settings
/hearths debug on    - Enable debug logging
/hearths reset       - Reset button position
```

## Options

Access via Interface → AddOns → Hearths or `/hearths options`

- Toggle debug mode
- Choose "Use All" or select specific hearthstones
- Individual hearthstone toggles with icons

## TODO

- ElvUI integration
- Masque support for button skinning

## License

MIT
