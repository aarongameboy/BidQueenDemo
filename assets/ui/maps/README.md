# 选图界面 — 地图预览图

将各地图的竖版预览图放在本目录，文件名与 `config/map_modes.json` 中 `preview_image` 一致。

| 地图 | 配置文件路径 | 建议尺寸 |
|------|----------------|----------|
| 琥珀商馆 | `map_dam.png` | 约 220×420 px（竖版） |
| 银雾修道院 | `map_valley.png` | 同上 |
| 星塔穹庭 | `map_aerospace.png` | 同上 |
| 黑蔷薇王陵 | `map_prison.png` | 同上 |

修改预览图：编辑 `config/map_modes.json` 里对应地图的 `preview_image` 字段即可，无需改代码。

特性文案：同文件中 `feature_text` 字段（`|` 分隔，显示在右侧难度面板下方）。
