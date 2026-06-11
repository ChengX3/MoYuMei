# MoYuMei / 摸鱼没

一个 macOS 菜单栏应用，用来记录当前 App 使用时间，区分「摸鱼」「搬砖」和「加班」，并根据薪资设置实时估算今日进账。

## 功能

- 菜单栏常驻，不显示 Dock 图标
- 实时显示今日进账、搬砖收入、摸鱼收入和加班收入
- 自动记录前台 App 使用时长
- 支持配置摸鱼名单和搬砖名单
- 支持月薪、工作日、工作时间、午休时间和加班规则设置
- 支持摸鱼日报、应用排行、数据导入导出
- 支持开机自启

## 技术栈

- Swift
- SwiftUI
- AppKit
- MenuBarExtra
- ServiceManagement
- UniformTypeIdentifiers
- Xcode Asset Catalog
- macOS 14.0+

## 使用教程

1. 启动 `MoYuMei.app`。
2. 在 macOS 菜单栏点击鱼形图标打开主面板。
3. 进入设置，先配置月薪、工作日、开工/收工时间和午休时间。
4. 在「摸鱼名单」和「搬砖名单」中添加对应 App。
5. 日常使用时保持应用运行，MoYuMei 会根据前台 App 自动记录使用时长。
6. 需要手动切换状态时，可在底部切换「摸鱼 / 搬砖」。
7. 在「摸鱼日报」中查看每日概览、应用排行和加班记录。

## 构建教程

### 环境要求

- macOS 14.0 或更高版本
- Xcode 16 或更高版本

### 本地构建

1. 克隆仓库：

```bash
git clone https://github.com/ChengX3/MoYuMei.git
cd MoYuMei
```

2. 使用 Xcode 打开项目：

```bash
open MoYuMei.xcodeproj
```

3. 在 Xcode 中选择 `MoYuMei` target。
4. 如需真机运行或导出应用，在 `Signing & Capabilities` 中选择自己的 Apple Developer Team。
5. 点击 `Run` 或 `Product > Build`。

说明：仓库不会提交开发者 Team ID。选择 Team 后，Xcode 可能会在本地修改 `project.pbxproj`，提交前请确认不要把个人签名团队信息提交到公开仓库。

### 打包 DMG

先在 Xcode 中构建出 `MoYuMei.app`，再准备一个包含应用和 Applications 快捷方式的目录：

```bash
mkdir -p dmg-root
ditto /path/to/MoYuMei.app dmg-root/MoYuMei.app
ln -s /Applications dmg-root/Applications
hdiutil create -volname MoYuMei -srcfolder dmg-root -ov -format UDZO MoYuMei.dmg
```

生成后可校验：

```bash
hdiutil verify MoYuMei.dmg
```

## 注意事项

- 本项目会读取当前前台 App 信息，用于统计应用使用时长。
- 数据默认保存在本机，不依赖远程服务器。
- 未经过签名和 notarization 的本地构建版本，在其他设备上打开时可能触发 macOS 安全提示。

## 禁止商用

本项目仅供学习、交流、比赛展示和个人非商业使用。未经作者明确书面授权，禁止将本项目或其衍生版本用于任何商业用途，包括但不限于售卖、付费分发、商业 SaaS、企业内部分发、广告变现或作为商业产品的一部分。

## 开发者信息

- 开发者：ChengX3
- 项目地址：https://github.com/ChengX3/MoYuMei


## 鸣谢

- [Linux.do](https://linux.do/) 社区
