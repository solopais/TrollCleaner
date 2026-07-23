# TrollCleaner

基于 TrollStore 的 iOS 深度清理工具。

## 功能

- **全 App 缓存扫描** — 遍历所有已安装 App 的缓存目录并按大小排序
- **一键清理** — 批量清理所有 App 缓存
- **微信专项清理** — 安全清理微信缓存，保留聊天记录
- **系统缓存清理** — OTA 残留、日志、系统缓存
- **回收站机制** — 清理前自动备份，支持恢复
- **安全模式** — 防止误删用户数据

## 构建要求

- macOS 13+（Ventura 或更新）
- Xcode 15+
- iOS 15.0+ 的测试设备
- 设备已安装 TrollStore

## 构建步骤

### 1. 创建 Xcode 项目

```bash
# 在 Mac 上执行
cd ~/Desktop
mkdir TrollCleanerBuild
cd TrollCleanerBuild

# 创建 Swift 包
swift package init --type executable --name TrollCleaner
```

### 2. 替换源码

将所有源码文件（`Sources/TrollCleaner/` 下的文件）复制到 Xcode 项目对应目录。

### 3. 配置 Xcode 项目

1. 用 Xcode 打开 `Package.swift` 或创建新的 iOS App 项目
2. **必须操作 — 配置 entitlements**：
   - 在 Targets → Signing & Capabilities 中，点击 "+ Capability"
   - 添加 "App Sandbox"，关闭 Sandbox
   - 或者直接使用项目附带的 `TrollCleaner.entitlements` 文件
   - 在 Build Settings → Signing → Code Signing Entitlements 指向该文件

3. **部署目标**：设置 iOS Deployment Target ≥ 15.0

4. **签名提示**：TrollStore App 使用自签名证书即可，不要用 Apple 开发者证书签名

### 4. 构建

- Product → Build（⌘B）
- 确保编译成功（Warning 可忽略）

### 5. 生成 TrollStore IPA

方法一 — 使用 Xcode 的 Archive 功能：
1. Product → Archive
2. Distribute App → Custom → "Export as IPA"
3. 将导出的 .ipa 通过 TrollStore 安装

方法二 — 直接安装 .app：
1. Build 完成后，在 Products 目录找到 `TrollCleaner.app`
2. 用 `ldid` 或 `codesign` 重新签名（因为 TrollStore 会用自己的签名覆盖）
3. 打包为 .ipa：`zip -r TrollCleaner.ipa Payload/`
4. 通过 TrollStore 打开 .ipa 安装

### 6. 安装到设备

1. 将 `.ipa` 传到 iOS 设备（AirDrop / 文件传输 / 自建服务器）
2. 用 TrollStore 打开 → 自动安装

## 项目结构

```
TrollCleaner/
├── Sources/
│   └── TrollCleaner/
│       ├── TrollCleanerApp.swift     # App 入口
│       ├── ContentView.swift         # Tab 导航
│       ├── Models/
│       │   └── Models.swift          # 数据模型
│       ├── Views/
│       │   ├── DashboardView.swift   # 首页仪表盘
│       │   ├── ScannerView.swift     # App 缓存列表
│       │   ├── WeChatCleaningView.swift  # 微信专项清理
│       │   └── SettingsView.swift    # 设置
│       └── Utils/
│           ├── FileScanner.swift     # 扫描引擎
│           ├── CleanupManager.swift  # 清理管理器
│           └── Formatters.swift      # 格式化工具
├── Resources/
│   └── Info.plist
├── TrollCleaner.entitlements
└── README.md
```

## 工作原理

TrollCleaner 利用 TrollStore 的 CoreTrust 漏洞获得的完整文件系统权限：

1. 读取 `/var/mobile/Containers/Data/Application/` 下的所有 App 数据容器
2. 扫描每个容器中的 `Library/Caches/`、`tmp/`、`Library/SplashBoard/` 目录
3. 统计可清理空间，按 App 展示
4. 清理时先移入回收站（`/var/mobile/Documents/TrollCleanerTrash/`），支持还原

## 安全说明

- TrollCleaner **不会**删除用户的 Documents 目录或聊天记录
- 所有删除操作前会经过二次确认
- 提供回收站机制，可恢复误删内容
- 微信清理只针对临时缓存，不影响聊天消息数据库

## 免责声明

本工具仅用于学习和研究。使用本工具清理系统文件可能带来不可预期的后果，请自行承担风险。
