# Figma → Godot UI 工作流

Figma 制作面板、边框、图标和装饰等美术素材；Godot 负责场景组合、布局、输入、数据绑定与运行时行为。用户手动导出和导入最终素材，并在 Godot 中完成视觉验收。布局任务默认只改原生场景、控件和必要的呈现脚本，不生成或修改图片，也不要求自动截图或像素比对。

## 文件与职责

| 类型 | 放置与职责 |
| --- | --- |
| 视觉素材 | 当前卡牌美术在 `ExpeditionSystem/BattleSystem/CardSystem/Arts/`，字体在 `Arts/Fort/`，共用主题在 `Arts/Theme/`；保持已有引用。新共用 UI 美术建议手动导入 `Arts/UI/CombatHUD/`、`Arts/UI/DeckEditor/` 或 `Arts/UI/Shared/`，本任务不创建这些素材目录 |
| 可复用 UI 场景 | `CombatHUD.tscn`、`WeaponDeckEditor.tscn` 和 `WeaponDeckCard.tscn` 保留各自的编辑与组合边界 |
| 布局组 | `HandLayout`、`EnemyStatus`、`PlayerInformation`、`ActionButtons`、`CombatPanel`、`ReservePanel` 是所在场景内的组，用原生 anchors、offsets、Container 和 Theme 常量调整 |
| 数据驱动控件 | 生命值、行动图标、动态手牌和牌组卡片由现有接口更新；素材不能替代这些控件或成为玩法数据来源 |

新素材推荐语义化英文 snake_case：`combat_enemy_health_frame.png`、`combat_draw_frame.png`、`deck_reserve_panel.png`。按用途和状态命名，不使用 `Group 54` 等 Figma 默认导出名；需要状态时添加 `_normal`、`_hover`、`_pressed`、`_disabled`。已有文件不因新约定而批量重命名。是否使用 PNG、SVG 或其他 Godot 支持的格式由素材需要决定；导入后在编辑器检查尺寸和透明边缘，不手写 `.import` 或 UID。

## 本次场景调整入口

下表的节点路径相对各自场景根节点。先调整所属组，再细调组内元素；改变 Container 子节点的位置应使用 margin、separation、size flags 或 minimum size。

| 场景与节点 | Inspector 调整点 |
| --- | --- |
| `ExpeditionSystem/BattleSystem/UI/CombatHUD.tscn` → `EnemyStatus` | 上方偏左血条组的 anchors/offsets；`HealthBar` 调厚度，`HealthValue` 调数值位置，`IntentPlaceholders` 调行动间距，`IntentTemplate` 调图标 minimum size |
| 同场景 → `PlayerInformation/HealthPanel` | 左下玩家生命横条、数值与资源读数的位置；`HealthBar` 的 Theme Overrides 控制背景和填充样式 |
| 同场景 → `PlayerInformation/StaminaPips`、`ManaPips` | 手牌下方资源标记组的 anchors/offsets、HBox separation 和子节点 minimum size；四格只表达现有资源比例，不定义资源上限 |
| 同场景 → `ActionButtons` | 右侧 VBox 的 anchors/offsets、alignment、separation；按钮 minimum size、字体与 Theme Overrides |
| `ExpeditionSystem/BattleSystem/CardSystem/CardSystem.tscn` → `HandLayout` | 下方中间的手牌可用范围；运行时按真实数量在此范围内居中并等比缩放，不直接拖动运行时 `PlayerHandDeck` 来调整布局 |
| `player_hand_deck.tscn` 根节点 | HBox separation；`Hand Layout` 中既有左右预留宽度与底部留白。当前实例预留为 0，由 `HandLayout` 自身给周边组留空间 |
| `BaseSystem/UI/WeaponDeckEditor.tscn` → `Window` | 窗口外边距；Panel 的 StyleBox content margins 控制内边距；`Content` 的 separation 控制标题、牌区、状态区间距 |
| 同场景 → `Window/Content/DeckLayers/CombatPanel`、`ReservePanel` | 上方较窄实战区和下方较宽备用区的 anchors/offsets、StyleBox 内边距；两区当前分开排列，实战纵向滚动、备用横向滚动 |
| 同场景 → `%CombatGrid`、`%ReserveRow`、`%CombatPadding` | 列数、行列间距、备用卡间距、滚动内边距；列数只是呈现参数，不能改变战斗容量 |
| 牌组编辑器根节点 → `Card Layout/preferred_card_scale` | 首选等比缩放；空间不足时统一缩小以适配备用区高度和实战区列宽。放大卡片时也要给所属牌区增加空间 |

`CombatHUD.gd` 的控件引用分为 `Player Status`、`Enemy Status`、`Actions` 和 `Intent Preview`。引用是场景接线，不是布局参数，不应为调整位置而清空或改接。玩家横条与数值使用同一个 `display_state(snapshot)` 数据源。

HUD 独立场景原先保存为隐藏状态，编辑时可临时显示根节点；实际 `ExpeditionSystem.tscn` 保留 `CombatHUD.visible = true` 的实例覆盖，整层显隐仍由 BattleManager 控制。手牌实际路径为 `BattleSystem/UI/CardSystem/HandLayout/PlayerHandDeck`。不要在父场景重新添加旧路径的覆盖。

这些界面保持原生编辑器可调。动态卡片和自定义缩放在运行时根据真实数据计算，不承诺编辑器中无数据时能预览完整牌组；本任务不为此增加 `@tool` 执行玩法逻辑。

## 替换空纹理槽

| 场景 | 已预留的空 `TextureRect` |
| --- | --- |
| `CombatHUD.tscn` | `EnemyStatus/PanelArt`、`EnemyStatus/HealthBar/FrameArt`、`EnemyStatus/IntentTemplate/IconArt`、`PlayerInformation/HealthPanel/PanelArt`、`PlayerInformation/HealthPanel/HealthBar/FrameArt`、`ActionButtons/{DrawButton,DiscardButton,AdvanceButton}/FrameArt` |
| `CardSystem.tscn` | `HandLayout/PanelArt` |
| `WeaponDeckEditor.tscn` | `Window/PanelArt`、`Window/Content/DeckLayers/{CombatPanel,ReservePanel}/PanelArt`、`Window/Content/Header/CloseButton/FrameArt` |

这些槽使用 `expand_mode = IGNORE_SIZE`、`mouse_filter = IGNORE`；多数仍为 `texture = null`，`CombatPanel/PanelArt` 已配置 CanvasTexture，具体内容以当前场景为准，保留已有配置。面板槽由所属 Container 填满内容范围，其余槽随父节点 anchors 填满；默认 stretch 为 Scale，保持比例的图标可在 Inspector 改为 Keep Aspect Centered。

用户导入素材后直接给槽的 `Texture` 赋值，不替换功能节点、不新增按钮回调。`FrameArt` 是覆盖层，使用中间透明的边框素材，避免盖住已有数值或按钮文字；完整按钮皮肤应配置原 Button 的 Theme Overrides / Styles（含各状态），血条背景和填充应配置 ProgressBar 的 background/fill StyleBox，需拉伸边框时使用 `StyleBoxTexture` 的 margin。当前 StyleBoxFlat 是可调整的原生占位样式，接入正式素材时按需替换。行动图标从隐藏模板复制，其 `IconArt` 会随模板进入动态实例。

有明显独立编辑价值、复用或替换边界的复杂组件才提取 `.tscn`。小图标、标签、留白、纯逻辑节点和与父场景紧耦合的组保留内联；组件数量不是模块化质量指标。保持父场景是清晰的组合入口。

## 数据和交互边界

BattleManager 汇总显示快照；CombatHUD 仅显示并发出抽牌、弃牌、推进意图。CardManager 管理战斗牌堆，PlayerHandDeck 与 CardLogic 保留现有输入、锁定、悬停和离场回报。手牌数量来自实际状态，不按目标稿固定五张。

WeaponInstance / CardContainer / CardInstance 持有武器和有序牌组。WeaponDeckEditor 从当前模型创建可重复卡片；WeaponDeckCard 复用 Card.tscn 的 `presentation_only` 和 `display_instance()`，不创建替代 RuntimeCard。WeaponDeckRegion 与适配层只转发意图，Base 校验会话后的源牌和容量，并移动同一个实例。素材、布局列数、可见数量不能改变容量、UID、修饰器、顺序、保存时机或模态控制。

WeaponDeckEditor 独立场景根节点保持可见，便于直接编辑；BaseUI 和远征 UISystem 中的实例默认隐藏，由运行时拥有者显式打开/关闭。EDIT 展示原双牌组；Tab 的 COMBAT_VIEW 复用同一场景和卡面，只隐藏 ReservePanel，不改变两个面板的 anchors/offsets。只读模式按实例关闭编辑输入，保留卡片上的原生滚轮传播；不要为只读模式复制布局、扩张 CombatPanel 或禁用 ScrollContainer。

## 远征发现地图

`ExpeditionSystem/UISystem/ExpeditionMap.tscn` 是独立全屏 Control，实例在 Expedition 的 UISystem CanvasLayer。根节点 `Map Colors` 调整房间框、玩家圆和初始菱形颜色；`Map Layout` 调整首选方框尺寸、间距、内边距和线宽。背景为原生 ColorRect。绘制层只接收已发现坐标，按原网格位置等比布局，不创建逐房场景或显示未知占位/连接线。

独立场景根节点保持可见；其纯表现 `@tool` 脚本用隔离单位样例提供编辑预览，无 World/Expedition 依赖。运行时 _ready 自动隐藏，由 ExpeditionManager 的 M 输入控制显隐，预览样例不进入运行时快照。菱形大于圆且先画，玩家位于初始房时仍可辨认两个标记。

## 验证与交付

先核对 diff、NodePaths、导出引用、信号、动画轨道与资源路径。使用 `tools/godot_cli.ps1` 做定向 headless 加载和必要的交互逻辑探针；临时脚本放 `.ai/tmp/`，日志留 `.ai/runtime/`，结束后清理一次性文件及本次进程，保留用户 Editor。

定向探针应覆盖场景加载/实例化、外层 Expedition 继承路径、HUD 快照和按钮链、实际手牌、牌组绑定、原实例转移、容量拒绝、旧会话拒绝、关闭和重开。它不替代真实鼠标拖拽、视觉、字体、分辨率或导出验收，也不要求自动截图、颜色评分或反复视觉回归。

交付时说明改动场景、可调入口、素材槽、执行过的检查和未验证边界。最终 Figma 素材接入、尺寸/间距微调、文字与皮肤效果、画面与输入手感由用户在 Godot 中验收。
