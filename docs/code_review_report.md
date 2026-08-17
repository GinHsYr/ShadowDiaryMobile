# 代码审查报告

> **项目**: ShadowDiaryMobile
> **检查时间**: 2026-08-17
> **检查范围**: `lib/`、`test/`、`android/`、`windows/` 及根目录构建配置（排除生成目录和生成的本地化绑定）
> **文件总数**: 118 个源代码、测试、原生与配置文件
> **问题总数**: 10（仅保留当前未处理问题）

---

## 概览统计

| 类别 | Critical | High | Medium | Low | 合计 |
|------|----------|------|--------|-----|------|
| Bug 检测 | 0 | 0 | 0 | 0 | 0 |
| 冗余检测 | 0 | 0 | 0 | 0 | 0 |
| 改进点 | 0 | 0 | 0 | 0 | 0 |
| 风险点 | 0 | 2 | 3 | 2 | 7 |
| 不合理处 | 0 | 0 | 2 | 1 | 3 |
| **合计** | **0** | **2** | **5** | **3** | **10** |

已完成的问题不再列入本报告；其回归结果保留在“验证记录”中。

---

## 1. Bug 检测

当前没有未处理的 Bug。已完成的 Bug 修复已从本报告移除。

---

## 2. 冗余检测

当前没有未处理的冗余项。已完成的清理项已从本报告移除。

---

## 3. 改进点

当前没有未处理的性能或功能改进项。已完成的优化项已从本报告移除。

---

## 4. 风险点

> 潜在的运行风险、数据安全、兼容性问题

### K-01 备份加密密钥与加密数据库位于同一 ZIP

- 文件: `lib/core/backup/backup_export_service.dart:159`
- 严重程度: High
- 类别: 风险
- 状态: 延后（本轮安全项仅报告）
- 描述: `backup-key.json` 以明文随加密数据库一起导出，拿到 ZIP 的主体也能取得解密密钥；该设计提供格式兼容性但不提供离线机密性。
- 建议: 在新的、显式版本化的备份格式中支持用户口令派生密钥或系统密钥封装，并保留 v5 导入兼容。

### K-02 release 仍使用 debug signing

- 文件: `android/app/build.gradle.kts:29`
- 严重程度: High
- 类别: 风险
- 状态: 延后（本轮安全项仅报告）
- 描述: 当前 release 构建使用 debug keystore，不能作为正式商店签名策略，也会影响升级链和供应链可信度。
- 建议: 通过本地/CI secret 注入正式 signingConfig，禁止密钥和密码进入仓库。

### K-03 Android 全局允许明文网络流量

- 文件: `android/app/src/main/AndroidManifest.xml:10`
- 严重程度: Medium
- 类别: 风险
- 状态: 延后（本轮安全项仅报告）
- 描述: LAN 同步使用 `ws://`，因此应用全局开启 cleartext。业务载荷另有会话加密，但握手元数据和其他未来请求仍受全局策略影响。
- 建议: 评估局域网 TLS 或更窄的网络安全配置，避免为整个应用永久放开明文流量。

### K-04 加密 WebSocket 帧在解码前没有长度上限

- 文件: `lib/core/sync/sync_client.dart:620`
- 严重程度: Medium
- 类别: 风险
- 状态: 延后（本轮安全项仅报告）
- 描述: 资产分块解码后会校验 192 KiB，但 `nextEncrypted` 在解密、JSON 和 base64 解析前未限制原始帧大小，异常或恶意对端可制造内存压力。
- 建议: 在不改变 wire protocol 的前提下，对原始文本/二进制帧、manifest 数量和 base64 编码长度增加前置上限。

### K-05 第三方插件尚未迁移到 Flutter Built-in Kotlin

- 文件: `pubspec.yaml:16`
- 严重程度: Medium
- 类别: 风险
- 状态: 延后
- 描述: release 构建警告 `file_picker` 和 `flutter_image_compress_common` 仍应用 Kotlin Gradle Plugin，未来 Flutter 版本会将其视为构建错误。
- 建议: 在升级 Flutter 前跟踪插件版本并验证迁移；不要在本轮无行为回归基线时强升主版本。

### K-06 Android Studio 与 command-line tools 的 SDK XML 版本不一致

- 文件: `android/build.gradle.kts:1`
- 严重程度: Low
- 类别: 风险
- 状态: 延后
- 描述: AAB 构建报告工具只理解 SDK XML v3，但发现 v4 文件；当前构建成功，未来工具组合可能失败。
- 建议: 在 CI/开发环境统一 Android Studio、SDK command-line tools 和 JDK 17 版本。

### K-07 28 个依赖存在约束外的新版本

- 文件: `pubspec.yaml:8`
- 严重程度: Low
- 类别: 风险
- 状态: 延后
- 描述: `flutter analyze/test/build` 报告 28 个包有不兼容当前约束的新版本；这不等同于已知漏洞，但形成后续升级债务。
- 建议: 分批执行 `flutter pub outdated`、迁移说明审查和完整回归，避免一次性升级破坏 UI、数据库或平台插件。

---

## 5. 不合理处

> 反模式、命名不当、结构混乱等设计问题

### U-01 `SyncRepository` 混合过多职责

- 文件: `lib/core/sync/sync_repository.dart:34`
- 严重程度: Medium
- 类别: 不合理
- 状态: 延后
- 描述: 单文件约 900 行，同时承担快照、版本向量、冲突、实体映射、资产定位/哈希/安装和数据库写入，修改面较大。
- 建议: 在保持公开 API 和协议不变的前提下，后续拆分 asset store、record mapper 与 conflict store，避免一次重写。

### U-02 `BackupImportService` 同时承担解析、验证、解压和业务写入

- 文件: `lib/core/backup/backup_import_service.dart:1`
- 严重程度: Medium
- 类别: 不合理
- 状态: 延后
- 描述: 单文件超过 1,200 行，ZIP 布局验证、SQLCipher 检查、会话目录、资源安装和两种导入模式高度集中。
- 建议: 以现有 v5 测试为契约，后续提取只读 inspector、asset installer 和 transaction importer，逐步迁移而非一次重写。

### U-03 仓库指南引用的数据库说明文件缺失

- 文件: `resources/db.md`（缺失）
- 严重程度: Low
- 类别: 不合理
- 状态: 延后
- 描述: 仓库规则要求数据库与该文档保持一致，但实际 `resources/` 仅有 `icon.png`，无法从文档核对 schema 设计意图。
- 建议: 从可信历史或维护者资料恢复文档；在来源不明时不要根据当前 schema 反向伪造“规范”。

---

## 构建体积验证

| 产物 | 优化前基线 | 当前结果 | 相对基线 | 相对 Universal APK |
|------|-----------:|---------:|---------:|-------------------:|
| Universal APK（参考，不作为常规交付） | 77,716,593 B | 未重建 | - | - |
| armeabi-v7a APK | 25,783,653 B | 25,849,189 B | +0.254% | -66.739% |
| arm64-v8a APK | 27,289,929 B | 27,371,849 B | +0.300% | -64.780% |
| x86_64 APK | 28,891,685 B | 28,973,605 B | +0.284% | -62.719% |
| AAB | 76,920,226 B | 77,065,668 B | +0.189% | 商店按设备拆分 |

原生库约占 Universal APK 的 97.1%；保留 bundled SQLite/FTS5/SQLCipher 是数据库和加密兼容要求，不能以删除依赖换取表面体积下降。

## 验证记录

- `dart format lib test`：97 个 Dart 文件已检查，0 个待格式化。
- `flutter analyze`：通过，0 issues。
- `flutter test`：通过，156 tests。
- `flutter build apk --release --split-per-abi`：通过，三种 ABI 均生成。
- `flutter build appbundle --release`：通过。
- `flutter build windows --release`：通过，生成 `shadow_diary_mobile.exe`。
- `git diff --check`：通过（仅 Git 的 LF/CRLF 转换提示）。

## 总结与建议

当前报告只保留 10 项尚未处理的问题。剩余事项集中在备份密钥保护、正式 Android 签名、明文网络策略、同步帧资源上限、工具链升级和两个超大服务类的维护成本。其余已完成问题已从报告正文移除，并由 156 项测试及三平台 release 构建验证。

建议优先级：

1. 发布前完成正式 Android 签名，并明确备份 v6 的密钥保护策略。
2. 为同步加密帧和 manifest 增加解码前资源上限，再补充接收中断/恶意帧集成测试。
3. 分批升级 Kotlin 相关插件和 Android 工具链，每批执行当前 156 项测试及三平台 release 构建。
4. 以现有测试为契约渐进拆分 `SyncRepository` 与 `BackupImportService`，避免影响数据兼容。

---

*报告由 WorkBuddy Code Reviewer 自动生成*
