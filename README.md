# MathAtlas

macOS 数学题库管理应用，支持 LaTeX 渲染、侧边栏筛选与 PDF 导出。

## 功能

- **题目管理** — 创建、编辑、整理数学题目，支持分类（填空题、选择题、解答题）、标签、来源与备注。
- **LaTeX 渲染** — 基于 KaTeX + WKWebView，完整支持 `\boxed{}`、`\begin{cases}`、`\textbf{}` 等语法。
- **多级题库** — 内置高中、初中题库（含 2026 上海春考种子数据），可自定义创建题库。
- **侧边栏筛选** — 按题型、标签、试卷出处筛选，支持右键重命名/删除标签与来源。
- **自定义分类** — 创建自定义题型，可自由选择 SF Symbol 图标与颜色。
- **批量操作** — 多选题目后批量添加标签、移动到其他题库、删除或加入待打印队列。
- **待打印队列** — 管理导出题目列表，支持拖拽排序、一页一题、自由设置每道题预留空行、插入空白页。
- **PDF 导出** — 通过 Pandoc + XeLaTeX 导出 PDF，包含页码与页脚水印（使用 PingFang SC 渲染中文）。
- **Markdown 导出** — 将待打印题目导出为 Markdown 文件。
- **中英双语** — 完整的中文 / English 界面切换。
- **动画风格** — 展开或滑入两种详情页切换动画。

## 系统要求

- macOS 26 或更高版本
- PDF 导出需要安装 [Pandoc](https://pandoc.org) 与 [XeLaTeX](https://tug.org/mactex/)（推荐 BasicTeX）

## 快速开始

1. 用 Xcode 打开 `MathAtlas.xcodeproj`。
2. 构建并运行（Cmd+R）。
3. 浏览种子题目，或创建自己的题目。

### 安装 PDF 导出依赖

```bash
# 安装 Homebrew（如已安装可跳过）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Pandoc
brew install pandoc

# 安装 BasicTeX（含 XeLaTeX，约 100MB）
brew install basictex
```

## 项目结构

```
MathAtlas/
├── MathAtlas.xcodeproj
├── MathAtlas/              # 应用入口（AppDelegate、ContentView）
├── Views/                  # SwiftUI 视图
│   ├── ProblemDetailView   # 题目详情（含 LaTeX 渲染）
│   ├── ProblemEditorView   # 创建/编辑题目表单
│   ├── ProblemCardView     # 题目列表卡片
│   ├── ProblemListView     # 可搜索的题目列表
│   ├── SettingsView        # 通用设置与数据管理
│   ├── AISettingsView      # AI 配置
│   └── AboutView           # 关于窗口
├── Models/                 # 数据层
│   ├── Problem             # 题目模型与种子数据
│   ├── ProblemStore        # 增删改查与持久化
│   ├── Settings            # 应用设置与提示词管理
│   ├── DeepSeekClient      # DeepSeek API 客户端
│   ├── LocaleManager       # 双语本地化
│   ├── DependencyChecker   # Pandoc/XeLaTeX 依赖检测
│   ├── KeychainManager     # Keychain 安全存储
│   └── PrintQueueManager   # 待打印队列状态
├── Components/             # 可复用组件
│   ├── LaTeXParser         # LaTeX → HTML 转换器
│   ├── KaTeXWebView        # KaTeX WebView 渲染
│   ├── PlainTextWebView    # 无滚动 WebView
│   └── NonScrollingWebView # 滚动禁用包装器
└── Resources/              # 资源、本地化、字体
```

## 开源协议

本项目采用 **MathAtlas Source Available License**，详见 [LICENSE](./LICENSE)。

简要说明：

- 允许查看、学习、修改源代码用于个人、教育或研究目的。
- 未经授权，不得用于商业用途，不得公开分发修改版本，不得销售或转授权。
- 使用本软件必须保留原始版权声明。
- 商业使用需另行取得版权持有人的书面授权。

Copyright (c) 2026-present TrustedInstaller64。保留所有权利。
