# 如何安装 Prompt Picker {{version}}

**18+。** Prompt Picker 仅供 18 岁及以上的人使用。第一次打开时会问“你已年满 18 岁吗？”选“是”会继续并记在这台电脑上。选“否”会关闭应用。

这个文件夹里的图片是步骤示意图，不是你电脑上的截图。

Windows 会显示“Windows 已保护你的电脑”，因为这个应用没有代码签名。这个警告是正常的，并不表示文件被改过。不要关闭 SmartScreen 或 Defender。

## 1. 下载

下载 `PromptPicker-Setup-{{version}}.exe`，或打开 `PromptPicker-{{version}}-Windows.zip` 并运行里面的安装程序。发布页上的 `latest.yml` 请保持原样。已安装的应用靠它检查更新。

![下载](zh/01-download.png)

## 2. SmartScreen

打开安装程序。如果 Windows 显示“Windows 已保护你的电脑”：

1. 点击 **更多信息**（More info）。
2. 点击 **仍要运行**（Run anyway）。

![SmartScreen](zh/02-smartscreen.png)

## 3. 安装

安装程序会询问 Prompt Picker 的安装文件夹。如果可以创建，默认是 `C:\Prompt Picker`，否则是用户目录下的 Prompt Picker 文件夹。程序文件都放在你选择的文件夹里。只会在桌面创建快捷方式，不会创建开始菜单快捷方式，并会删除旧的开始菜单快捷方式 Prompt Picker。如果这台电脑已经装了 Prompt Picker，安装会覆盖那一份。提示词仍保存在 `%APPDATA%\Prompt Picker\data`。

![安装](zh/03-installer.png)

## 4. 第一次打开

确认你已年满 18 岁，然后抽取提示词。

![第一次打开](zh/04-first-launch.png)

## 5. 更新

更新会安装到你已经选择的文件夹。不会再次询问文件夹，也不会删除提示词或设置。

## 6. 卸载

设置 > 其他有两个选项。Windows 的设置 > 应用里也是这两个选项。

**卸载并保留数据**会移除应用、快捷方式、卸载项、临时文件和更新缓存。提示词、语言、主题、排序、提示以及其他偏好都会保留，安装文件夹和桌面快捷方式选择也会保留。下次安装会填入该文件夹和这些选项，并自动恢复设置。如果需要副本，请先导出 JSON 备份（设置 > 备份与导入）。

**卸载并清除全部内容**会移除应用、提示词、设置、安装文件夹和已保存的安装选择。无法撤销。

## 7. 联系

Discord 是首选联系方式，回复最快：https://discord.gg/yH5AAdj5qY

Patreon：https://www.patreon.com/c/linekoaiart447658

X：https://x.com/lyht111222333

Telegram 查看较少：https://t.me/linekoaiart
