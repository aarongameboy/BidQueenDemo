# 03 道具主表（500 条）

## 3.1 文件

`config/items_master.csv`

## 3.2 字段

| 列名 | 必填 | 说明 |
|------|------|------|
| item_id | 是 | 唯一 id，如 `itm_00001` |
| item_name | 是 | 显示名 |
| size_w | 是 | 格子宽 1~3 |
| size_h | 是 | 格子高 1~3 |
| base_price | 是 | 基础价格（银币） |
| icon_path | 是 | `res://assets/icons/items/{item_id}.png` |
| quality | 是 | white/green/blue/purple/gold/red |
| quality_color | 是 | HEX，如 `#9C27B0` |
| pool_tag | 是 | 随机池标签 |
| weight | 是 | 池内权重 |
| enabled | 是 | 1/0 |

## 3.3 品质色（默认）

| quality | quality_color |
|---------|---------------|
| white | #B0B0B0 |
| green | #4CAF50 |
| blue | #2196F3 |
| purple | #9C27B0 |
| gold | #FFC107 |
| red | #F44336 |

## 3.4 尺寸分布（500 条目标）

- 1x1: 30%
- 1x2 / 2x1: 25%
- 2x2: 25%
- 2x3 / 3x2: 12%
- 3x3: 8%

## 3.5 生成工具

`_tools/generate_items_master.py` — 可重复生成并覆盖 CSV。
