# Prompt Picker

[![Latest release](https://img.shields.io/github/v/release/broplaygame75-ai/prompt-picker-releases)](https://github.com/broplaygame75-ai/prompt-picker-releases/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/broplaygame75-ai/prompt-picker-releases/total)](https://github.com/broplaygame75-ai/prompt-picker-releases/releases)

**18+.** Prompt Picker is for adults. The first launch asks "Are you 18 or older?"

Windows desktop app for picking and organizing prompts. This repository publishes installers and documentation only. Source code is not included.

## Download

Installers are on the [releases](https://github.com/broplaygame75-ai/prompt-picker-releases/releases) page.

- `PromptPicker-Setup-{{version}}.exe` is the installer. Auto-update uses this file and `latest.yml`. Leave those names as they are.
- `PromptPicker-{{version}}-Windows.zip` contains the installer, the install guide, and the pictures.

SHA-256 checksums for {{version}}:

| File | SHA-256 |
| --- | --- |
| `PromptPicker-Setup-{{version}}.exe` | `{{setup_sha256}}` |
| `PromptPicker-{{version}}-Windows.zip` | `{{zip_sha256}}` |

The same checksums are in the release notes.

## Install

1. Download the Setup exe, or open the zip and run the Setup exe inside it.
2. If Windows says "Windows protected your PC", click **More info**, then **Run anyway**. The app is not code-signed. Do not turn off SmartScreen or Defender.
3. Choose a folder. The suggested folder is `C:\Prompt Picker` when that location can be created. Otherwise it is a Prompt Picker folder in your user profile. Program files go in the folder you choose.
4. A Desktop shortcut is created. A Start Menu shortcut is not created, and an old Start Menu shortcut named Prompt Picker is removed.
5. Confirm you are 18 or older, then pick a prompt.

Pictures and the same steps in English, Tiếng Việt, 中文, and 한국어 are in the [install guide](guide/HOW-TO-INSTALL.md).

## Update

An update installs into the folder you already chose. It does not ask for a folder again and it does not delete prompts or settings. Prompts stay in `%APPDATA%\Prompt Picker\data`.

## Uninstall

Settings > Others and Windows Settings > Apps offer the same two choices.

**Uninstall, keep data** removes the app, shortcuts, uninstall entries, temporary files, and the updater cache. It keeps prompts, language, theme, sorts, hints, and every other preference, plus the chosen folder and the desktop shortcut choice. The next install opens with that folder filled in and those options selected, and the app restores the settings. Export a JSON backup first (Settings > Backup & Import) if you want a copy.

**Uninstall and wipe everything** removes the app, the prompts, the settings, the install folder, and the saved install choices. This cannot be undone.

## Contact

1. [Discord](https://discord.gg/yH5AAdj5qY) is the preferred contact. Fastest reply.
2. [Patreon](https://www.patreon.com/c/linekoaiart447658)
3. [X](https://x.com/lyht111222333)
4. [Telegram](https://t.me/linekoaiart) is checked less often.

## FAQ

**Where do my prompts go?** `%APPDATA%\Prompt Picker\data` (`prompts.json` and an images folder). Settings such as language, theme, sorts, and hints live in that data and in `%APPDATA%\Prompt Picker`.

**Will an update erase my prompts?** No. An update replaces the program files in the folder you chose.

**Why does SmartScreen warn me?** The installer is not code-signed. More info, then Run anyway, is the expected step. Leave SmartScreen and Defender on.

**Why was the old Start Menu shortcut an "Unspecified error"?** That shortcut stored an AppUserModelID the Start Menu could not activate. 0.1.13 does not create a Start Menu shortcut and removes the old one.

**What does "keep data" remember?** Prompts and every preference, the chosen folder, the installer language, and the desktop shortcut choice. The next install prefills those. "Wipe everything" removes them.

## Troubleshooting

- The app writes `%APPDATA%\Prompt Picker\startup.log` on each launch and `%APPDATA%\Prompt Picker\crash.log` when something fails. Include both when you report a bug, along with the app version, the Windows version, and the steps you took.
- If the Desktop shortcut is missing, open the app from the install folder once. It recreates the Desktop shortcut and removes a stale Start Menu shortcut.
- If an update from 0.1.6 or 0.1.7 does not finish, download this installer and run it once. Later updates can then install into the same folder.

## Community

Bug reports and feature requests use the issue templates. See [SUPPORT.md](SUPPORT.md), [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [CHANGELOG.md](CHANGELOG.md).
