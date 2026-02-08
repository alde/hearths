# Hearths

Random hearthstone rotation addon for World of Warcraft.

## What it does

This addon no longer provides a custom in-game button. Instead, it creates and manages a macro named "HEARTHS_BTN" which you can drag to your action bars. This macro dynamically updates to cast a random, available hearthstone (toy, item, or spell) based on your preferences and cooldowns.

## Features

-   **Macro-based Activation**: Creates a macro named "HEARTHS_BTN" for you to use on your action bars.
-   **Dynamic Hearthstone Selection**: The macro automatically updates to use an available hearthstone.
-   **Automatic Hearthstone Detection**: Scans your toy box for all collectible hearthstones.
-   **Smart Cooldown Management**: Only uses hearthstones that are off cooldown.
-   **Shaman Astral Recall Priority**: For Shamans, if selected hearthstones are on cooldown, it will attempt to use Astral Recall instead (if enabled in options and off cooldown).
-   **Configurable Inclusions**: Option to include your default Hearthstone and Shaman's Astral Recall in the random rotation.
-   **Customizable Hearthstone Pool**: Select which specific hearthstone toys to include in the random rotation via the options panel.
-   **Integrated Options Panel**: All configurations are accessible through the standard World of Warcraft Interface options, powered by Ace3.

## Usage

1.  **Locate the Macro**: After enabling the addon, open your in-game macro interface (`/macro`).
2.  **Drag to Action Bar**: Find the macro named "HEARTHS_BTN" and drag it to your preferred action bar slot.
3.  **Click the Macro**: When you click this macro, it will attempt to use a random, available hearthstone from your configured pool.

## Commands

-   `/hearths` or `/hearths options` or `/hearths opts`: Opens the addon's settings panel in the Interface Options.
-   `/hearths refresh`: Forces a rescan of your available hearthstones and updates the macro selection.

## Options

Access via `/hearths` command or through `Interface Options > AddOns > Hearths`.

-   **Include Default Hearthstone**: Toggle to include your standard Hearthstone in the random pool.
-   **Include Astral Recall (Shaman only)**: Toggle to include Astral Recall in the random pool, and prioritize it when other hearthstones are on cooldown.
-   **Use All Hearthstone Toys**: Quickly enable/disable all detected hearthstone toys for the random pool.
-   **Individual Hearthstone Toggles**: Fine-grained control to enable or disable specific hearthstone toys from your collection for the random pool.
-   **Debug Logging**: Toggle debug output in your chat window.

## License

MIT
