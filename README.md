# macOS Performance Tweaks

A professional zsh script for optimizing macOS systems.

This script applies various tweaks, such as reducing UI transparency, disabling Spotlight, cleaning caches, and more – with logging, interactive selection, and a summary.

## Features

- Reduce UI transparency & motion
- Disable Spotlight indexing
- Set local default save location for new documents
- Disable Stage Manager (macOS Ventura or newer)
- Hide Control Center widgets
- Disable automatic software updates
- Disable Siri & analytics
- Clean system & user caches
- Disable Gatekeeper & app quarantine
- Delete Xcode DerivedData

## Usage

1. Download and make the script executable:

   ```bash
   curl -O https://raw.githubusercontent.com/hadzicni/macos-performance-tweaks/main/optimize-for-macos.sh
   chmod +x optimize-for-macos.sh
   ```

2. Run the script:

   ```bash
   ./optimize-for-macos.sh
   ```

   Optional automatic mode (no prompts):

   ```bash
   ./optimize-for-macos.sh --auto
   ```

3. A restart is recommended to apply all changes.

All actions are logged to `~/macos_tweaks.log`.

## Warnings

- Some tweaks require root privileges (sudo).
- Disabling Spotlight indexing will make search unavailable until re-enabled with sudo mdutil -a -i on.
- Cleaning caches may cause apps to rebuild data (slower start until reindexed).
- Changes may affect system features or third-party applications.
- Use at your own risk!

## Contributing
Contributions, suggestions, and pull requests are welcome.

## License

This project is licensed under the Apache License 2.0. See the LICENSE file for details.
