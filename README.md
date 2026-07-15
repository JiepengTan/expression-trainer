# Expression Trainer

Expression Trainer 是一个帮助用户训练口语表达清晰度的多端应用。仓库目前包含已经完成 P0 功能闭环的原生 iOS 客户端，以及原有的 Electron 桌面客户端。

| 客户端 | 状态 | 目录 |
|---|---|---|
| iOS | P0 功能与模拟器验收已完成 | `clients/ios/exp-trainer` |
| Electron 桌面版 | 可用 | 仓库根目录 |

## iOS 客户端

iOS 客户端基于 Swift 6、SwiftUI、Observation、SwiftData、AVAudioEngine 和 Apple SpeechAnalyzer 开发，最低支持 iOS 26.0，首版面向 iPhone 竖屏和深色外观。

### 已实现功能

- 三步首次引导、隐私说明、麦克风与语音识别权限处理。
- 首页空状态、回访状态、最近训练、快速开始和同题复练。
- 训练主题、单一目标、训练时长和实时 AI 配置。
- 录音、暂停、继续、结束、中断处理和异常草稿恢复。
- Apple SpeechAnalyzer 普通话实时识别、partial 字幕替换和 final 字幕持久化。
- 口头禅、犹豫词、笼统词分析，以及有效时长、有效字数和语速统计。
- 可编辑逐字稿、版本化确认、本地训练复盘和唯一的“下次重点”。
- 历史记录、左滑删除、清除全部数据、设置和训练复练。
- 纯文本逐字稿及 Markdown 报告分享，可选择是否包含完整逐字稿。
- App Attest 匿名会话、实时 AI 反馈和 SSE 深度报告客户端；关闭 AI 时不会发起云端请求。
- 16 个主要页面状态、5 个异常浮层及对应 UI 测试启动场景。
- Dynamic Type、VoiceOver 语义、减少动态效果和小屏适配。

详细产品与技术资料：

- [iOS 产品需求](Docs/ios-app-prd.md)
- [iOS UI 信息架构](Docs/ios-app-ui-information-architecture.md)
- [iOS 技术架构](Docs/ios-native-app-technical-architecture.md)

### 环境要求

- macOS 和 Xcode 26.6 或兼容的更新版本。
- iOS 26.0 以上的 iPhone 模拟器；语音识别验收建议使用真机。
- 真机运行时需要有效的 Apple Developer Team 和签名配置。
- AI 为可选功能；未配置后端时，本地训练、逐字稿校正和本地报告仍可正常使用。

### 使用 Xcode 构建和运行

在仓库根目录执行：

```bash
open clients/ios/exp-trainer/exp-trainer.xcodeproj
```

打开工程后：

1. 选择 `exp-trainer` Scheme。
2. 选择一台 iOS 26.0 以上的 iPhone 模拟器或已配置签名的真机。
3. 点击 Run，或使用快捷键 `Command + R`。
4. 首次开始训练时，按系统提示授予麦克风和语音识别权限。SpeechAnalyzer 可能需要先下载普通话语言资源。

### 使用命令行构建和测试

以下命令均在仓库根目录执行：

```bash
# 构建 iOS App
make ios-build

# 运行领域、存储和训练闭环测试
make ios-test

# 运行全部 21 个设计状态的 UI 冒烟测试
make ios-ui-smoke

# 检查工程中是否误提交供应商密钥
make ios-secret-scan

# 执行密钥检查、构建和单元测试
make ios-ci
```

默认测试设备为 `iPhone 17 Pro`。本机模拟器名称不同时，可以覆盖目标设备：

```bash
make ios-test IOS_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'
```

### 可选：配置 AI 后端

复制本地配置模板：

```bash
cp clients/ios/exp-trainer/Configuration/Local.example.xcconfig \
   clients/ios/exp-trainer/Configuration/Local.xcconfig
```

然后在 `Local.xcconfig` 中设置后端代理地址：

```text
BACKEND_BASE_URL = https:/$()/api.example.com
```

`Local.xcconfig` 已被 Git 忽略。App 只连接自有后端代理，不要在 iOS 工程、配置文件或 App 包中写入 DeepSeek、OpenAI 等供应商密钥。

后端未配置时，AI 区域会降级为本地复盘，不影响离线训练闭环。Sherpa-ONNX 目前仅作为协议层回退方案；只有 Apple SpeechAnalyzer 真机验收未达到门槛时才需要接入。

### iOS 工程结构

```text
clients/ios/exp-trainer/
├── Configuration/          # Debug、Staging、Release 和本地配置模板
├── Scripts/                # CI 密钥检查脚本
├── exp-trainer/
│   ├── App/                # App 入口、依赖注入、导航和功能开关
│   ├── DesignSystem/       # 品牌颜色、排版和通用组件
│   ├── Domain/             # 状态机、指标、词库及 AI 数据结构
│   ├── Features/           # 引导、首页、训练、复盘、历史和设置
│   ├── Persistence/        # SwiftData V1 Schema 与 Repository
│   ├── Resources/          # 本地化、隐私清单及资源
│   └── Services/           # 音频、SpeechAnalyzer、AI、权限和分享
├── exp-trainerTests/       # 单元与集成测试
└── exp-trainerUITests/     # 21 个设计状态 UI 冒烟测试
```

真机发布前仍需完成 30 分钟中文 ASR 评测、10 分钟 Instruments、两台真机端到端验收，以及真实后端和 App Attest 联调。

## Electron 桌面版

### 功能

- 🎤 **实时语音识别**：基于 Sherpa-ONNX，完全离线，中文优化
- 📝 **全屏字幕显示**：黑底大字，实时显示你说的每一句话
- 🔍 **词库分析**：自动检测填充词、犹豫词、笼统词，给出精准替代
- 🤖 **AI反馈**：支持 Groq/OpenAI/DeepSeek/Ollama 多后端
- 📊 **分析报告**：6维度深度分析（逻辑/直接性/填充词/密度/词汇/亮点）

### 安装

#### 1. 克隆项目并安装依赖

```bash
cd expression-trainer
npm install
```

#### 2. 下载语音识别模型

需要下载 Sherpa-ONNX 的 streaming paraformer 中英双语模型：

```bash
cd models

# 方法一：使用 wget
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2
tar xvf sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2

# 方法二：使用 huggingface
# https://huggingface.co/csukuangfj/sherpa-onnx-streaming-paraformer-bilingual-zh-en
```

下载后 `models/` 目录应包含：
```
models/
└── sherpa-onnx-streaming-paraformer-bilingual-zh-en/
    ├── encoder.int8.onnx
    ├── decoder.int8.onnx
    └── tokens.txt
```
#### 3. 启动应用

```bash
npm start
```

#### 4. 配置 AI 后端

启动后点击右上角 ⚙️ 进入设置页面。

推荐配置：

| 后端 | 费用 | 速度 | 获取方式 |
|------|------|------|----------|
| DeepSeek | 极低 | 快 | [platform.deepseek.com](https://platform.deepseek.com) |
| OpenAI | 中等 | 快 | [platform.openai.com](https://platform.openai.com) |
| Ollama | 免费 | 取决于硬件 | [ollama.com](https://ollama.com) 本地运行 |

**推荐 deepseek**：生成报告质量高，且成本极低。

### 使用说明

1. **点击「开始录制」** → 对着麦克风说话
2. **实时字幕**会在屏幕中央显示你说的内容
3. **左侧面板**实时统计填充词/犹豫词/笼统词
4. **右侧面板**每50字会给出AI实时反馈
5. **说完后点击「结束」** → 可以点「生成报告」获取完整分析

### 字幕颜色含义

| 颜色 | 含义 |
|------|------|
| 🔴 红色波浪下划线 | 填充词（嗯、啊、那个、然后…） |
| 🟠 橙色 | 犹豫词（可能、也许、我觉得…） |
| 🟡 黄色虚线 | 笼统词（有精准替代建议） |
| 🟢 绿色 | 有力表达（好句子！） |

### 技术架构

```
┌─────────────────────────────────────────┐
│ Electron 主进程                          │
│  ├── Sherpa-ONNX (离线语音识别)          │
│  ├── 词库匹配 (emotion-lexicon.json)     │
│  └── AI反馈 (多后端 HTTP API)            │
├─────────────────────────────────────────┤
│ 渲染进程 (Chromium)                      │
│  ├── 全屏字幕显示                        │
│  ├── 实时统计面板                        │
│  └── 分析报告弹窗                        │
└─────────────────────────────────────────┘
```

### 词库说明

`data/emotion-lexicon.json` 基于大连理工情感词库7大类结构，包含：

- **130+ 情绪词**：分类（喜怒哀惧恶惊）+ 强度（1-9）
- **笼统词→精准词映射**：25组高频替代建议
- **填充词表**：24个常见口头禅
- **犹豫词表**：19个弱化表达
- **程度词梯度**：弱→中→强→极 四级
- **画面化描述**：10组「抽象→具象」转换
- **犹豫→直接转换**：8组对照示例

### 开发

```bash
# 开发模式（带DevTools）
npm run dev

# 目录结构
├── main.js              # Electron主进程
├── preload.js           # preload脚本
├── src/
│   ├── index.html       # 主界面
│   ├── settings.html    # 设置页
│   ├── styles.css       # 样式
│   ├── app.js           # 前端逻辑
│   └── settings.js      # 设置逻辑
├── lib/
│   ├── asr.js           # 语音识别
│   ├── lexicon.js       # 词库匹配
│   ├── ai-feedback.js   # AI反馈
│   └── prompts.js       # Prompt模板
├── data/
│   └── emotion-lexicon.json
└── models/              # Sherpa-ONNX模型（需下载）
```

### 桌面版系统要求

- macOS 12+ / Windows 10+ / Linux
- Node.js 18+
- 麦克风权限
- （可选）网络连接（用于AI反馈，词库分析可离线）

## License

MIT
