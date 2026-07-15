# Expression Trainer iOS UI 图像生成规格

## 生成方式

- 模式：内置 `image_gen`，每个画面单独生成。
- 用例分类：`ui-mockup`。
- 参考图：`/Users/tjp/Downloads/Generated image 3 (6).png`，只作为视觉风格参考，不是编辑目标。
- 交付目录：`output/imagegen/ios-ui-v1/`。
- 画布：单张竖屏 iPhone 高保真界面，完整屏幕正视图；不展示手、桌面、透视设备模型或多屏拼贴。

## 全局视觉提示词

Use case: ui-mockup
Asset type: shippable high-fidelity iPhone app screen
Input images: Image 1 is the sole visual style reference. Reuse its dark premium expression-coaching design language, palette, card treatment, voice-wave motif, semantic underlines, spacing rhythm and restrained glow; do not copy its multi-device presentation board.
Style/medium: realistic production-ready native iOS product UI, not concept art, not a marketing poster.
Composition/framing: one straight-on portrait iPhone screen filling the canvas; correct iOS safe areas; 9:41 status bar; clean 8-point grid; generous margins; clear vertical hierarchy; practical tappable controls.
Color palette: near-black #0D0F0E and charcoal #1A1D1B; warm ivory #F4F0E8; primary orange #E86F25; amber #FFB547; teal #27C2A0; muted gold #D8C44F.
Typography: highly legible modern Chinese sans-serif with a subtle editorial condensed character for large headings; warm ivory body copy; strong hierarchy.
Components: thin warm-gray outlines, charcoal cards, orange primary buttons, teal positive cards and stars, orange/amber semantic underlines, tiny voice-ribbon accents only where useful.
Constraints: render only the requested screen; all visible Chinese text must be verbatim and legible; no invented copy; no Latin placeholder text; no watermark; no gradients outside restrained orange or teal emphasis cards; no excessive neon; no glossy 3D; no fake device bezel; no desktop layout.

## 21 张画面

### 01 — `s01-a-product-value.png`

Primary request: S01-A onboarding product-value screen.
Layout: compact brand mark at top; expressive voice-ribbon illustration in upper-middle; large two-line headline; three benefit rows with small teal check or star icons; bottom orange primary button and understated text link.
Text (verbatim): "Expression Trainer", "把每一次开口，都变成有效训练", "实时看见表达问题", "训练后得到具体改法", "按同一主题再次练习", "继续", "跳过介绍".

### 02 — `s01-b-privacy.png`

Primary request: S01-B onboarding privacy explanation screen.
Layout: back arrow and progress indicator; title; two comparison cards labeled local and AI, with local card subtly teal and AI card subtly amber; three short privacy rows; privacy-policy link; fixed orange primary button.
Text (verbatim): "隐私与数据", "基础训练在本机完成", "本地训练", "录音转文字与客观统计", "AI 深度分析", "开启后会发送你确认的逐字稿", "默认不保存原始录音", "查看隐私政策", "我明白了".

### 03 — `s01-c-permissions.png`

Primary request: S01-C permission preparation screen before system permission dialogs.
Layout: back arrow and progress; title and short explanation; microphone permission card and speech recognition card, both showing "尚未请求"; small local-processing badge; fixed orange primary button; quiet secondary link.
Text (verbatim): "准备开始训练", "需要两项权限", "麦克风", "用于录下你的表达", "语音识别", "用于生成实时逐字稿", "尚未请求", "本地处理", "允许并继续", "稍后设置".

### 04 — `s02-home-empty.png`

Primary request: S02 training home first-use empty state.
Layout: top greeting and settings icon; large orange start card with microphone-wave icon; small example preview card explaining the future result using one highlighted sentence and one teal next-focus line; local/AI status badges; native two-item bottom tab bar with Training selected.
Text (verbatim): "今天想练什么？", "开始第一次训练", "主题和目标都可以跳过", "训练后你会看到", "表达问题", "具体改法", "下一次只练一个重点", "本地训练可用", "AI 已开启", "训练", "历史".

### 05 — `s02-home-returning.png`

Primary request: S02 training home returning-user state.
Layout: top greeting and settings icon; prominent orange start card; "上次训练" section with a large charcoal summary card, topic, duration, goal, metrics and teal next-focus strip; outlined repeat button; local/AI badges; bottom tab bar with Training selected.
Text (verbatim): "今天想练什么？", "开始一次训练", "快速开始", "上次训练", "为什么要做这个产品", "3分12秒", "先说结论", "口头禅 8", "下次重点", "开头第一句先给出判断", "按这个主题再练一次", "本地训练可用", "AI 已开启", "训练", "历史".

### 06 — `s03-new-training-default.png`

Primary request: S03 new-training default configuration screen as a large native sheet.
Layout: top bar with cancel and centered title; optional topic field; six goal chips in a tidy grid with "先说结论" selected orange; five duration chips with 3 minutes selected; realtime AI toggle on with short privacy note; microphone and speech status row; fixed orange start button.
Text (verbatim): "取消", "开始一次训练", "主题（可选）", "例如：为什么要做这个产品", "这次重点练什么？", "减少口头禅", "先说结论", "表达更具体", "表达更直接", "结构更清楚", "自由练习", "目标时长", "1分", "3分", "5分", "10分", "不限时", "实时 AI 教练", "开启后会发送逐字稿用于反馈", "麦克风可用", "语音识别可用", "开始训练".

### 07 — `s04-live-recording.png`

Primary request: S04 distraction-free live training screen in recording state.
Layout: orange recording dot and "录音中" at top, large timer, topic and goal chips, slim non-countdown progress rail, one amber coach prompt banner, vertically stacked transcript bubbles with earlier sentence muted and current sentence bright, semantic orange/amber/teal underlines, compact metrics, bottom pause control and large orange stop control.
Text (verbatim): "录音中", "02:18", "为什么要做这个产品", "先说结论", "先把判断说出来", "嗯…我觉得吧，这个问题其实…", "可能有几个方面。", "我先说结论，这个产品能让人更快发现表达里的问题。", "口头禅 3", "犹豫词 1", "暂停", "结束".

### 08 — `s04-live-paused.png`

Primary request: S04 live training paused state, visibly calmer than recording.
Layout: amber pause icon and "已暂停" at top, timer frozen, topic and goal, coach banner dimmed with no activity, preserved transcript, compact metrics, large orange "继续训练" control and secondary outlined "结束" control.
Text (verbatim): "已暂停", "02:18", "为什么要做这个产品", "先说结论", "提示已暂停更新", "我先说结论，这个产品能让人更快发现表达里的问题。", "口头禅 3", "犹豫词 1", "继续训练", "结束".

### 09 — `s04-live-ending.png`

Primary request: S04 live training ending-processing state.
Layout: top status "正在结束" with timer; preserved topic, coach banner and transcript; subtle animated-looking voice ribbon resolving into a clean line; bottom inline processing card; all controls disabled and subdued, with no full-screen spinner.
Text (verbatim): "正在结束", "02:18", "为什么要做这个产品", "先说结论", "正在整理最后一句", "马上生成可校正的逐字稿", "我先说结论，这个产品能让人更快发现表达里的问题。".

### 10 — `s05-transcript-correction.png`

Primary request: S05 editable transcript correction screen.
Layout: back arrow and title; topic metadata; four compact local metric cards; short guidance text; large editable charcoal transcript field with cursor and semantic underlines; issue legend; quiet save action and fixed orange confirm button.
Text (verbatim): "确认逐字稿", "为什么要做这个产品", "3:12", "486字", "152字/分", "口头禅 8", "犹豫词 3", "修正明显识别错误，报告会使用你确认后的文字。", "嗯，我觉得这个产品就是能让人更快发现自己表达里的问题，然后知道下一次怎么练。", "口头禅", "犹豫词", "笼统表达", "亮点", "保存记录", "确认并查看复盘".

### 11 — `s06-report-local.png`

Primary request: S06 local review report before AI report generation.
Layout: back, title and share icon; topic/date/duration metadata; prominent teal next-focus card; local-statistics label and three compact metrics; frequent issue words; transcript entry row; AI deep-report card with orange action; fixed orange same-topic-practice button.
Text (verbatim): "训练复盘", "分享", "为什么要做这个产品", "今天 14:32 · 3分12秒", "下次只练这一件事", "开头第一句先给出判断", "练法：结论 → 两个理由", "本地统计", "486字", "152字/分", "口头禅 8", "高频问题词", "我觉得", "然后", "其实", "查看带标记逐字稿", "AI 深度报告", "使用你确认的逐字稿生成", "生成 AI 深度报告", "按同一主题再练一次".

### 12 — `s06-report-ai-loading.png`

Primary request: S06 report with AI generation in progress while local review remains fully visible.
Layout: same report hierarchy as local state; condensed teal next-focus and local stats remain; AI section expanded with three staged progress rows and a subtle orange voice-wave loader; small note that user may leave; fixed repeat button.
Text (verbatim): "训练复盘", "为什么要做这个产品", "下次只练这一件事", "开头第一句先给出判断", "本地统计", "AI 分析生成中", "正在理解表达结构", "正在寻找关键证据", "正在整理具体改法", "你可以先离开，完成后仍会保存在这里", "按同一主题再练一次".

### 13 — `s06-report-ai-complete.png`

Primary request: S06 complete AI deep report screen showing the most actionable upper viewport.
Layout: back, title, share; teal next-focus card; labels clearly distinguish AI analysis from local statistics; one teal highlight evidence card, one amber problem evidence card, and an orange-accent rewrite comparison card with three labeled rows; fixed repeat button.
Text (verbatim): "训练复盘", "AI 分析", "总体诊断", "观点明确，但结论出现得稍晚", "说得好的地方", "这个产品能让人更快发现表达里的问题。", "最值得修改", "我觉得这个问题其实可能有几个方面。", "原句", "我觉得这个问题其实可能有几个方面。", "推荐表达", "我的判断是：这个产品值得做。", "为什么", "先给判断，再补充理由，听者更容易跟上。", "按同一主题再练一次".

### 14 — `s07-history-empty.png`

Primary request: S07 training history empty state.
Layout: large title; centered restrained voice-ribbon illustration fading into a teal arrow; concise empty-state message; orange first-training button; bottom tab bar with History selected.
Text (verbatim): "训练历史", "还没有训练记录", "完成第一次训练后，你的逐字稿和复盘会保存在这里。", "开始第一次训练", "训练", "历史".

### 15 — `s07-history-populated.png`

Primary request: S07 training history populated state.
Layout: large title; date-grouped vertical list with three charcoal session summary cards; each has topic, time, goal chip, one metric, and AI/local badge; bottom tab bar with History selected.
Text (verbatim): "训练历史", "今天", "为什么要做这个产品", "3:12 · 先说结论", "口头禅 8", "AI 报告已完成", "7月13日", "自由练习", "1:48 · 表达更具体", "口头禅 3", "本地复盘", "7月11日", "项目周报", "5:04 · 结构更清楚", "犹豫词 5", "AI 报告已完成", "训练", "历史".

### 16 — `s08-settings-default.png`

Primary request: S08 native grouped settings screen.
Layout: back and title; compact dark grouped-list sections with chevrons, toggles and status badges; training preferences, AI/privacy, permissions, data management, about; destructive data action isolated at bottom in red-orange outline.
Text (verbatim): "设置", "训练偏好", "默认训练目标", "先说结论", "默认训练时长", "3分钟", "实时教练提示", "AI 与隐私", "实时 AI 反馈", "AI 数据使用说明", "隐私政策", "权限与语音识别", "麦克风", "已允许", "语音识别", "已允许", "离线语音资源", "已就绪", "打开系统设置", "数据管理", "12 条训练记录 · 8.6 MB", "原始录音默认不保存", "清除全部训练数据", "关于", "版本 1.0.0", "帮助与反馈".

### 17 — `o01-permission-denied.png`

Primary request: O01 permission-denied custom bottom sheet over a dimmed S03 screen.
Layout: rounded charcoal bottom sheet with microphone icon, direct title, one-sentence explanation, orange primary button and quiet secondary button; underlying new-training screen remains recognizable but dimmed.
Text (verbatim): "无法开始录音", "麦克风权限已关闭。允许访问后，才能开始表达训练。", "打开系统设置", "暂时不训练".

### 18 — `o02-speech-resource-preparing.png`

Primary request: O02 offline speech-resource preparation custom sheet over a dimmed permission screen.
Layout: rounded charcoal sheet with teal/orange voice-wave icon; title; download size and Wi-Fi note; 68% progress bar; practical storage note; orange continue-later-safe action and secondary cancel.
Text (verbatim): "正在准备离线语音识别", "下载后，即使网络不稳定也能生成逐字稿。", "156 MB · 建议使用 Wi‑Fi", "68%", "还需要约 320 MB 可用空间", "后台继续", "取消下载".

### 19 — `o03-abandon-training.png`

Primary request: O03 exit-or-abandon confirmation action sheet over a dimmed paused live-training screen, assuming useful transcript already exists.
Layout: rounded charcoal bottom sheet; safe option visually primary, save option outlined, destructive abandon option red-orange text; concise explanation.
Text (verbatim): "要结束这次训练吗？", "已确认的逐字稿和 2分18秒训练内容还在。", "继续训练", "保存当前内容", "放弃训练".

### 20 — `o04-recording-interrupted.png`

Primary request: O04 system-interrupted recording state as an inline alert sheet over the preserved live-training UI.
Layout: amber phone/microphone interruption icon; title and understandable reason; preserved transcript visible behind; statement that content is safe; orange resume button and outlined finish-and-save button.
Text (verbatim): "录音已暂停", "电话占用了麦克风。", "已确认的逐字稿和计时都已保留。", "继续训练", "结束并保存".

### 21 — `o05-delete-confirmation.png`

Primary request: O05 destructive single-session deletion confirmation sheet over a dimmed history screen.
Layout: rounded charcoal bottom sheet; small session summary card with topic and date; irreversible warning; safe cancel button primary or high-emphasis, destructive delete button clearly red-orange and separated.
Text (verbatim): "删除这次训练？", "为什么要做这个产品", "今天 14:32 · 3分12秒", "逐字稿、本地复盘和 AI 报告都会被删除，且无法撤销。", "取消", "删除训练".
