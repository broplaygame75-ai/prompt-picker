# Security

Prompt Picker is a Windows desktop app. It is not code-signed. Prompts, settings, and logs stay on the PC in `%APPDATA%\Prompt Picker`. They are not uploaded by the app.

## Reporting a problem

Prefer Discord, which is checked most often: https://discord.gg/yH5AAdj5qY

You can also open a GitHub issue with the bug-report template, or use the other contacts listed in [SUPPORT.md](SUPPORT.md). Telegram is checked less often.

Please include the app version, the Windows version, what you did, and the relevant lines from:

- `%APPDATA%\Prompt Picker\startup.log`
- `%APPDATA%\Prompt Picker\crash.log`

Do not send prompt text or exported JSON unless you mean to share it. Those files can contain your own notes.

## SmartScreen

Windows may say "Windows protected your PC" because the installer is unsigned. Click **More info**, then **Run anyway**. Do not turn off SmartScreen or Defender to install this app.
