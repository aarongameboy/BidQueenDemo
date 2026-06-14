# 游戏音乐设计方案 · 全界面 BGM/SFX 规范

> **文档版本**：v1.0（AIT-25）  
> **对应实现**：`scripts/audio/bgm_player.gd` · `config/audio_screens.json` · `assets/music/`

## 1. 设计目标

为 BidQueen Demo 的**每一个可进入界面**定义可循环的背景音乐（BGM），并与现有四张地图主题曲（JY / AL / CA / CS）形成统一听感：

- 题材：**中世纪幻想 × 王冠竞拍会**（与 `docs/art_concept/medieval_anime_auction_art_direction.md` 一致）
- 气质：华丽但克制；金属、羊皮纸、蜡封、圣铃、暗金；**禁止**现代 EDM、科幻霓虹、街机 chiptune
- 功能：界面切换时自动切歌；结算 / 匹配 / 过场 CG 有明确情绪转折

## 2. 全局音色与混音

| 要素 | 规范 |
| --- | --- |
| 主调性 | 大厅与商都偏 **C / G 大调**；修道院 **A / D 小调**；王陵 **E 小调 + 低弦** |
| 配器 | 鲁特/竖琴垫、弦乐 pad、圣铃、少量铜管点缀、手鼓/沙锤作节奏（仅榜单/匹配） |
| 循环 | 32s 无缝循环；Intro ≤ 2s；避免突兀断点 |
| 响度 | 对局 BGM 0 dB；子界面 −1～−3 dB；CG 过场 **duck −12 dB** |
| 文件 | 地图主题曲 `*.mp3`；元游戏占位循环 `meta_*.wav`（可后续替换为正式编曲） |

## 3. 界面 → 音乐映射

### 3.0 每界面 sonic identity

| screen_id | 3 个形容词 | 玩家情绪 | 乐器 / 风格参考 | 玩法状态关联 |
| --- | --- | --- | --- | --- |
| `lobby` | 温暖、繁华、可信赖 | 回到资产与入口总览，准备下一轮竞拍 | 鲁特琴、柔和弦乐、轻金币打击；中世纪商都主题 | 默认大厅状态；无具体对局压力时持续循环 |
| `map_selection` | 开阔、谨慎、期待 | 比较地图收益与风险 | 羊皮纸感竖琴分解、低弦铺底、轻钟点缀 | 进入地图列表时切入；确认匹配/房间后离开 |
| `matchmaking` | 紧张、脉冲、克制 | 等待对手匹配，心跳逐步上升 | 108 BPM 低频脉冲、短铃、弱手鼓 | 快速匹配开始时切入；匹配完成后转地图对局曲 |
| `room_battle` | 亲近、低声、待命 | 与好友集结、等待准备 | 柔和 pad、低音拨弦、轻微对位旋律 | 房间大厅/准备状态循环；开局后转地图对局曲 |
| `match` | 竞逐、压迫、华丽 | 进入正式拍卖，关注出价与落槌 | 按地图主题使用 JY/AL/CA/CS；弦乐与圣铃强化节拍 | 由 `map_id` 决定曲目；竞拍阶段保持地图身份 |
| `settlement` | 收束、闪耀、释然 | 清算收益、查看回收与奖励 | 明亮钟琴、金币质感打击、缓慢和声收束 | 结算 tick `start` 时切入；直到回大厅前保持 |
| `shop` | 轻快、精明、亲切 | 浏览购买与交易确认 | C 大调竖琴垫、木质短音、铜铃点缀 | 商店打开时切入；关闭回主流程后恢复对应界面 |
| `warehouse` | 低沉、尘封、秩序 | 管理库存、整理格子 | A 小调低弦、暗色 pad、少量木盒敲击 | 仓库打开时切入；拖拽整理时不增加节奏压力 |
| `collection` | 庄重、晶亮、珍藏 | 查看藏品与品质筛选 | D 大调玻璃钟、宽弦乐、轻奖杯泛音 | 收藏界面循环；突出“陈列”而非交易 |
| `characters` | 优雅、自信、人物感 | 浏览代理人与出战配置 | G 大调弦乐 pad、鲁特琴、短促礼仪铜管 | 角色界面打开时切入；换人时保持稳定背景 |
| `leaderboard` | 竞争、冷静、节拍化 | 比较排名、观察榜单变化 | E 小调 92 BPM 脉冲、低鼓、短弦拨奏 | 排行榜打开时切入；日/周/月切换不重启情绪 |
| `encyclopedia` | 安静、神秘、可阅读 | 查阅规则、图鉴和资料 | 高频 bell、轻羽笔刷感噪声、低音量 pad | 百科可在大厅或对局内打开；音量低于其他界面 |
| `cinematic` | 聚焦、戏剧、悬停 | 观看过场，不被 BGM 抢对白/提示 | 不换曲；当前曲 duck -12 dB，保留空间给 CG 声音 | `MatchCinematicOverlay` 播放期间压低，结束恢复 |

### 3.1 主流程

| 界面 | screen_id | 曲目 | 情绪 / 设计说明 |
| --- | --- | --- | --- |
| 主大厅 | `lobby` | **JY** · 琥珀商馆 | 玩家回到「琥珀港」资产面板；温暖商都、金币 K 线与快速匹配入口；与地图 `dam` 共享主题曲强化品牌记忆 |
| 地图选择 | `map_selection` | **meta_map_select** · 航线图 | 略压低能量；羊皮纸地图展开、模式/门票抉择；四图预览时不抢戏 |
| 快速匹配 | `matchmaking` | **meta_matchmaking** · 候场铃 | 108 BPM 脉冲渐强；5–10s 假匹配等待制造紧张感 |
| 房间对战 | `room_battle` | **meta_room** · 好友房 | 低声 pad + 轻微对位；房主等人、准备按钮；不抢语音/聊天位（预留） |
| 对局拍卖 | `match` | **按 map_id** → JY/AL/CA/CS | 进入 `start_match` 后切换；四图各用主题曲，竞拍节奏跟拍点走 |
| 结算 | `settlement` | **meta_settlement** · 落槌清算 | 落槌瞬间切入；金币堆叠、回收条、认领按钮；比地图曲更「收束」 |
| 过场 CG | `cinematic` | duck 当前曲 **−12 dB** | 不硬切歌；`MatchCinematicOverlay` 播放期间压低，结束后恢复 |

### 3.2 元游戏子界面（从大厅进入）

| 界面 | screen_id | 曲目 | 情绪 / 设计说明 |
| --- | --- | --- | --- |
| 商店 | `shop` | **meta_shop** · 琥珀柜台 | C 大调竖琴垫；买卖确认、战术道具分类；轻快但不滑稽 |
| 仓库 | `warehouse` | **meta_warehouse** · 禁录库房 | A 小调低弦；格子拖拽、入库/out；尘埃感 |
| 收藏 | `collection` | **meta_collection** · 藏家陈列厅 | D 大调；奖杯与品质筛选；略庄严 |
| 角色 | `characters` | **meta_characters** · 代理人名册 | G 大调；切换出战角色、立绘展示 |
| 排行榜 | `leaderboard` | **meta_leaderboard** · 竞拍榜 | E 小调 + 92 BPM 脉冲；日/周/月榜切换保持同一 loop |
| 百科 | `encyclopedia` | **meta_encyclopedia** · 禁录图鉴 | 高频 bell 点缀；阅读向、音量 −3 dB；对局内也可打开 |

### 3.3 地图主题曲（对局内）

| map_id | 地图名 | 曲目 | 设计关键词 |
| --- | --- | --- | --- |
| `dam` | 琥珀商馆 | **JY** | 商都、金币、入门友好 |
| `valley` | 银雾修道院 | **AL** | 圣铃、薄雾、禁录院 |
| `aerospace` | 星塔穹庭 | **CA** | 星象、秘藏、高塔 |
| `prison` | 黑蔷薇王陵 | **CS** | 王陵、黑蔷薇威压、最高爆率 |

## 4. 界面切换规则（实现）

```
大厅 ──→ 子界面（shop/warehouse/...）     切到 meta_* 
子界面 ──×→ 返回大厅                       恢复 JY
大厅 ──→ 地图选择                         meta_map_select
地图选择 ──→ 快速匹配                     meta_matchmaking ──→ 对局 map BGM
地图选择 ──→ 房间                         meta_room ──→ 对局 map BGM
对局 ──→ 结算 begin                       meta_settlement
对局 ──→ CG                               duck，不换曲
结算认领 ──→ 仍在对局结束态               保持 settlement 或 map（当前：保持 settlement 直至回大厅）
```

代码入口：`MatchUI._play_screen_bgm(screen_id, context)` → `BgmPlayer.play_for_screen()`。

## 5. 音效（SFX）预留 · 未实装

| 场景 | 建议音效 | 优先级 |
| --- | --- | --- |
| 加价 / 落槌 | 金属槌 + 金币溅射 | P0 |
| 按钮 / 导航 | 短促石板点击 | P1 |
| 匹配成功 | 单音圣铃 | P1 |
| 稀有掉落揭示 | 品质色 chime（Q3+） | P2 |
| Toast 提示 | 轻羽笔刷 | P3 |

> Demo 阶段仅落地 BGM 路由；SFX 待美术音频迭代。

## 6. 资源生成与替换

占位循环由 `_tools/generate_screen_bgm.py` 生成（32s 立体声 WAV）。正式版建议：

1. 按本表「设计说明」交编曲；导出 **OGG/Vorbis** 或 **MP3**，替换 `assets/music/meta_*.wav`
2. 更新 `config/audio_screens.json` 中 `path`
3. Godot 重新 import 即可，**无需改代码**

## 7. 验收清单

- [ ] 进大厅听到 JY
- [ ] 打开商店 / 仓库 / 收藏 / 角色 / 排行榜 / 百科，BGM 各自不同且可循环
- [ ] 选图界面为 meta_map_select；快速匹配为 meta_matchmaking
- [ ] 四张地图对局分别播放 JY / AL / CA / CS
- [ ] 结算开始时切 meta_settlement
- [ ] CG 播放时 BGM 明显压低，结束后恢复
