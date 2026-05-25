# 02 主角席位与 UI

## 2.1 席位配置（`config/match_config.json`）

| 字段 | 默认 | 说明 |
|------|------|------|
| seat_count | 4 | 2~8，对局人数 |
| player_seat | 0 | 主角席位；-1 为纯 Bot |
| player_character_id | hero | 主角角色 id |

## 2.2 玩家状态扩展

`PlayerState` 增加：

- `is_human: bool` — 是否主角
- `passed_this_round: bool` — 本轮是否点击放弃
- `silver` — 局内货币（出价扣款在成交时结算，MVP 仅校验上限）

## 2.3 BidWindow 输入

| 动作 | 行为 |
|------|------|
| 加价 | 出价 = `min_next_bid` |
| 自定义出价 | 输入 >= `min_next_bid` |
| 本轮放弃 | 本窗口不再自动加价；下轮可继续 |

## 2.4 UI 节点（`scenes/main.tscn`）

- `HighestBidLabel` — 当前最高价
- `LeaderLabel` — 领先者
- `BidTimerLabel` — 窗口倒计时
- `RaiseButton` / `CustomBidLineEdit` / `PassRoundButton` — 主角操作

## 2.5 信号

- `open_board_updated(board)` — 刷新明拍面板
- `player_bid_accepted(seat, amount)` / `player_bid_rejected(reason)`
