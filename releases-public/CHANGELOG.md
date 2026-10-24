# Changelog

## {{version}}

- An update installs into the existing folder, including a 0.1.12 install in `%LOCALAPPDATA%\Programs\Prompt Picker`. It does not add a second copy. A silent upgrade overwrites that folder and does not run the previous uninstaller. Setup does not relaunch, delete, or move its own exe. The first launch removes a leftover copy in another folder and points the Desktop shortcut at the running program.
- The uninstaller shows one window, closes Prompt Picker first, and does not start the app.
- The installer asks for a folder. The suggested folder is `C:\Prompt Picker` when it can be created, otherwise a Prompt Picker folder in your user profile. A path with a space is kept in full.
- Only a Desktop shortcut is created. It does not carry an AppUserModelID. An old Start Menu shortcut named Prompt Picker is removed. That shortcut was the "Unspecified error": it stored AppUserModelID `com.lineko.promptpicker`.
- Each launch writes `%APPDATA%\Prompt Picker\startup.log`.
- A picked prompt whose label matches New shows a remove button on that result chip. Removing the label updates the modified time and can be undone or redone.
- Uninstall can keep data or wipe everything. Keep data also keeps settings and install choices. The next install prefills that folder and those options, and restores the settings. Wipe everything removes them.
- Settings includes Contact: Discord, Patreon, X, then Telegram.

## 0.1.12

- Shortcuts repair themselves on launch. A missing install folder is not reused. A startup error offers a repair dialog. A clean-machine check runs before a release is published.
