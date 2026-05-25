# 04 概率表（三层）

## 4.1 表文件

| 文件 | 作用 |
|------|------|
| `config/spawn_pool_table.csv` | 每场先抽 pool |
| `config/items_master.csv` | pool 内按 weight 抽道具 |
| `config/quality_modifier_table.csv` | 按场次修正品质权重 |

## 4.2 抽样流程

```
match_seed -> RNG
  -> roll spawn_pool_table (pool_weight)
  -> roll items in pool (item weight * quality_modifier)
  -> check warehouse grid fits (size_w x size_h)
  -> retry up to max_place_retries, else downgrade pool
```

## 4.3 spawn_pool_table 字段

- `pool_tag`, `pool_weight`, `min_items`, `max_items`, `enabled`

## 4.4 quality_modifier_table 字段

- `context`（match_default / round_3+ 等）
- `quality`, `multiplier`

## 4.5 校验

`scripts/tools/validate_item_tables.gd` — 权重和、enabled 道具数、icon 路径格式。
