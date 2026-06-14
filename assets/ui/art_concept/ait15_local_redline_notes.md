# AIT-15 局部视觉标注说明

依据：`bidqueen-art-direction`、`frontend-design`、当前 Godot 真实截图、`main.tscn`、`player_seat_card.gd`、`character_selection_ui.gd`。

说明：当前会话没有可用的 `taste skill` 插件；本稿按已安装的美术方向与产品/UI 设计能力做局部标注。v3/v4 整屏 mockup 已撤回，不作为实现参考。

## 交付文件

- 角色页真实截图红线：`res://assets/ui/art_concept/character_profile_redline_v1_real_screenshot.png`
- 角色页真实截图原图：`res://assets/ui/art_concept/character_profile_real_capture_v1.png`

HUD 可操作阶段截图仍被开场过场层挡住，本轮不再用伪造整屏图替代。HUD 只给现有节点的局部样式说明。

## HUD 局部样式说明

保留当前三栏结构：

- 左：`LeftPanel / PlayersList`
- 中：`CenterPanel / SkillEffectsList / BidArea`
- 右：`RightPanel / LootPanelHost`

只优化 `PlayerSeatCard` 的可读性：

- `custom_minimum_size = Vector2(410, 110)` 不改。
- `ROUND_SLOT_SIZE = Vector2(46, 88)` 不改，避免影响五轮记录密度。
- 当前轮格：保留宝石青方向，但提高可读层级。建议 `border_color = #40C2B8`、2px；背景从现有青色加深，避免和文字抢。
- 已出价格：金额字号从 9 提到 11～12；颜色用王冠金 `#D8A84E`，让出价比边框更醒目。
- 已用道具格：保持紫色边框，但道具 icon 下方金额/状态不要挤压；必要时把道具图标降到 32px，给出价文字留底部空间。
- 隐藏当前轮出价 `"..."`：不要用小号灰字，改成居中、12～13px、宝石青弱亮，明确这是“待揭示”而不是空格。
- 主角席位：继续用金色 3px 外框 + `主角` 小章；不要拆成独立主角卡。
- 领先席位：继续用青色 3px 外框；可在姓名行右侧加小王冠 icon，但不新增一列。

不做：

- 不移动仓库格。
- 不把技能卡放回左侧。
- 不重做三栏比例。
- 不新增 HUD 功能字段。

## 角色页局部样式说明

对应红线图编号：

1. 保留左侧单列角色选择。只强化选中态：宝石青描边、头像轻微提亮、名称可读；不新增底部角色列表。
2. 保留下方信息面板。当前半透明深色面板位置是对的，只整理文字层级，不改成立绘右侧档案页。
3. 单技能表达。现有字段是 `skill_name` + `skill_desc`，视觉上改为：技能名金色加粗、触发时机做小胶囊、效果描述保留一条。
4. 出战按钮状态。已出战时降低饱和度；可出战时才用酒红底 + 金边主按钮。

建议文字层级：

- 角色名：20～22px，羊皮纸白/浅金。
- 职阶/派系：13～14px，低一档灰蓝，不抢技能名。
- `局内技能`：12px 小标题。
- 技能名：16～18px，王冠金 `#D8A84E`。
- 触发标签：`开局` / `每轮` / `第5轮`，宝石青描边胶囊。
- 技能描述：13～14px，最多两行，直接使用 `config/characters.json` 的 `skill_desc`。

不做：

- 不新增多技能槽。
- 不新增第二套角色列表。
- 不改技能机制和字段。
- 不改立绘层级和角色页主构图。
