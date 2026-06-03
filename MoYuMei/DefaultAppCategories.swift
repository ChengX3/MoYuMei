import Foundation

enum DefaultAppCategories {
    static let fishing: Set<String> = [
        // 社交
        "com.tencent.xinWeChat",
        "com.tencent.qq",
        "org.telegram.desktop",
        "com.discord.Discord",
        "com.twitter.twitter-mac",
        "com.zhiliaoapp.musically",

        // 影音
        "com.bilibili.bili",
        "com.netease.163music",
        "com.spotify.client",
        "com.tencent.QQMusicMac",
        "com.apple.Music",
        "com.apple.TV",
        "io.iina.iina",
        "com.colliderli.iina",

        // 游戏
        "com.valvesoftware.steam",
        "com.epicgames.EpicGamesLauncher",
        "com.apple.Chess",

        // 社区/阅读
        "com.douban.Douban",
        "com.xiaohongshu.macOS",
        "daily.�.reddit",
        "com.readdle.smartemail-macos",
    ]

    static let working: Set<String> = [
        // 开发
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.jetbrains.intellij",
        "com.jetbrains.WebStorm",
        "com.jetbrains.pycharm",
        "com.jetbrains.goland",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "dev.warp.Warp-Stable",
        "com.github.atom",
        "com.sublimetext.4",

        // 办公
        "com.microsoft.Word",
        "com.microsoft.Excel",
        "com.microsoft.Powerpoint",
        "com.microsoft.Outlook",
        "com.microsoft.teams2",
        "com.kingsoft.wpsoffice.mac",
        "com.apple.iWork.Pages",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Keynote",
        "com.apple.mail",

        // 协作
        "com.electron.lark",
        "com.tencent.WeWorkMac",
        "com.DingTalkMac",
        "com.tinyspeck.slackmacgap",
        "us.zoom.xos",
        "com.hnc.Discord",

        // 设计
        "com.figma.Desktop",
        "com.bohemiancoding.sketch3",
        "com.adobe.Photoshop",
        "com.adobe.illustrator",

        // 笔记
        "notion.id",
        "md.obsidian",
        "com.apple.Notes",
    ]

    static var fishingCount: Int { fishing.count }
    static var workingCount: Int { working.count }
}
