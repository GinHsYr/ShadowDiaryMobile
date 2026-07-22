<h1 align="center">影迹</h1>
<h6 align="center">Shadow Diary</h6>

<p align="center">
  <img src="resources/icon.png" width="120" alt="Shadow Diary Logo" />
</p>

<p align="center">
  一个本地优先、注重隐私的日记应用，基于 Flutter 构建。<br/>
  寻找桌面端？<a href="https://github.com/GinHsYr/ShadowDiary">ShadowDiary 桌面端</a>
</p>

---

## 功能

### 日记
- **富文本编辑** — 基于 Quill 编辑器，支持加粗、斜体、下划线、删除线、对齐、引用等
- **日历视图** — 月份日历，标记有日记的日期，支持左右滑动切换月份
- **快捷跳转** — 今天、昨天、上周同日、上月同日一键跳转
- **心情与天气** — 记录每日心情（开心/兴奋/平静/疲惫/难过）和天气
- **图片插入** — 支持从相册选取图片，自动转为 WebP 格式，单篇最多 20 张
- **自动保存** — 700ms 防抖自动保存，切到后台时也会触发保存
- **全文搜索** — 基于 FTS5 的日记全文检索

### 档案
- **人物/其他档案** — 记录重要的人或事物，支持姓名、别名、描述、头像和图库
- **拼音排序** — 中文档案按拼音首字母 A-Z 分组，侧边字母索引导航
- **关联统计** — 日记中提及档案时自动统计提及次数

### 媒体
- **瀑布流画廊** — 统一浏览来自日记和档案的所有图片
- **分类筛选** — 全部 / 日记 / 档案 三类筛选
- **全屏查看** — 支持双指缩放、左右滑动浏览
- **来源追溯** — 查看图片所属的日记或档案，一键跳转到来源

### 统计
- 日记总数、连续写作天数、累计字数
- 月度写作进度条和百分比

### 外观
- **主题模式** — 跟随系统 / 浅色 / 深色
- **五种配色** — 中性黑、靛蓝、青绿、玫红，以及 Monet 系统动态取色（Android 12+）
- **Material 3** — 全面采用 Material Design 3
- **多语言** — 跟随系统 / 简体中文 / English

### 安全
- **应用锁** — 支持生物识别（指纹/面部/虹膜）和设备凭据（PIN/图案/密码）
- **后台自动锁定** — 切到后台后自动锁屏

### 数据
- **备份导入** — 支持从桌面端 ZIP 备份导入，提供预览面板
- **两种导入模式** — 覆盖导入（完全替换）/ 增量导入（仅导入缺失日期的日记）
- **加密存储** — 使用 SQLCipher 加密的备份数据库

---

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x / Dart 3.12+ |
| 状态管理 | flutter_riverpod |
| 路由 | go_router |
| 数据库 | SQLite + FTS5（内置 sqlite3mc） |
| 富文本 | flutter_quill |
| 主题 | dynamic_color (Monet) |
| 安全 | local_auth（生物识别） |
| 国际化 | intl / ARB |

---

## 开发

**环境要求**：Flutter ≥ 3.44.6、Dart ≥ 3.12.2、Android SDK、JDK 17。

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

**Android applicationId**：`com.shadowdiary.hsyr`

---

## 项目结构

```
lib/
  main.dart                  # 入口：初始化数据库、启动应用
  app/
    app.dart                 # MaterialApp.router 配置
    router.dart              # GoRouter 路由定义
    shell.dart               # 毛玻璃底部导航栏
  core/
    archives/                # 档案模型、仓库、拼音排序
    backup/                  # ZIP 备份导入
    database/                # SQLite 表结构、FTS5、触发器
    diary/                   # 日记模型、统计、仓库
    media/                   # 媒体库汇总
    security/                # 应用锁控制器与锁屏组件
    services/                # 图片服务、LAN 服务契约
    settings/                # 设置模型与控制器
    theme/                   # 主题定义（浅色/深色/配色方案）
    widgets/                 # 通用组件
  features/
    archives/                # 档案列表页、编辑页、图片查看器
    editor/                  # 富文本日记编辑器
    home/                    # 首页（日历、统计卡片）
    media/                   # 媒体画廊、图片查看器
    settings/                # 设置页
  l10n/                      # 国际化文件（中/英）
```

---

## License

MIT
