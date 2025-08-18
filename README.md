# Hearths - Smart Random Hearthstone Rotation

A World of Warcraft addon that provides intelligent, automatic rotation through your hearthstone collection with a single, convenient button.

## Features

### 🎯 Core Functionality
- **Automatic Detection**: Discovers all your hearthstone toys and adds new ones automatically
- **Intelligent Rotation**: Only rotates to hearthstones that are off cooldown
- **Cooldown Fallback**: When all hearthstones are on cooldown, shows the one with shortest remaining time
- **Class Integration**: Shamans automatically get Astral Recall included in rotation
- **Real-time Cooldown Display**: Visual cooldown sweep and countdown text

### ⌨️ Controls
- **Left-click**: Use current hearthstone and rotate to next available
- **Shift-click**: Use Dalaran Hearthstone (if available)
- **Ctrl-click**: Use Garrison Hearthstone (if available)
- **Alt-drag**: Reposition button anywhere on screen

### 🛠️ Commands
```
/hearths debug on|off    - Toggle debug logging
/hearths reset          - Reset button position to center
/hearths               - Show help
```

### 🧠 Smart Behavior
- **Excluded from Rotation**: Dalaran and Garrison hearthstones (available via modifier keys)
- **Event-Driven**: Responds to loading screens and spell completion for seamless rotation
- **Persistent Settings**: Button position and preferences saved between sessions
- **Performance Optimized**: Cooldown checks throttled to once per second

## Installation

1. Download the addon files
2. Extract to your `World of Warcraft/_retail_/Interface/AddOns/Hearths/` folder
3. Restart WoW or reload UI (`/reload`)
4. The hearthstone button will appear in the center of your screen

## Configuration

### Debug Mode
Enable debug logging to see detailed information about hearthstone detection and rotation:
```
/hearths debug on
```

This will show messages like:
```
[Hearths Debug] Added to rotation: Hearthstone
[Hearths Debug] Added to rotation: Astral Recall
[Hearths Debug] Checking cooldowns for all hearthstones:
[Hearths Debug]   Hearthstone: available
[Hearths Debug]   Astral Recall: on cooldown (485s)
[Hearths Debug] Selected available hearthstone: Hearthstone
```

### Button Positioning
- **Move**: Hold Alt and drag the button to desired location
- **Reset**: Use `/hearths reset` to return to screen center
- Position is automatically saved and restored between sessions

## How It Works

1. **Startup**: Scans your toy collection and spell book for hearthstones
2. **Selection**: Chooses a random available hearthstone for the button
3. **Usage**: When clicked, uses the hearthstone and marks for rotation
4. **Rotation**: After successful teleport, automatically switches to next available hearthstone
5. **Cooldown Management**: Always prioritizes hearthstones that are ready to use

## Technical Details

### Secure Implementation
- Uses `SecureActionButtonTemplate` for protected function compatibility
- Works in combat and restricted environments
- Proper event handling for reliable rotation timing

### Performance
- Cooldown checks limited to once per second
- Efficient tooltip scanning on startup only
- Minimal memory footprint

## TODO

### 🎨 UI Integration
- [ ] **ElvUI Integration**: Native styling support for ElvUI users
- [ ] **Masque Support**: Allow button skinning with Masque/ButtonFacade
- [ ] **Custom Styling Options**: Size, border, font customization via slash commands

### 🔧 Enhanced Features
- [ ] **Favorite Hearthstones**: Pin specific hearthstones to always appear in rotation

### 🌍 Localization
- [ ] **Multi-language Support**: Translate all user-facing text
- [ ] **Localized Tooltip Scanning**: Support for non-English game clients

## Contributing

This addon was developed for my own needs, but contributions are welcome!

### Development Setup
1. Clone the repository
2. Enable debug mode: `/hearths debug on`
3. Test changes with `/reload`

### Code Style
- Follow existing patterns for SecureActionButtonTemplate usage
- Use descriptive debug logging for new features
- Maintain compatibility with restricted environments

## License

This project is licensed under the MIT License. Feel free to modify and redistribute.

---

*Transform your hearthstone experience from decision paralysis to one-click convenience!*
