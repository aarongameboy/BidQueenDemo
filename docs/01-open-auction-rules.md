# 01 明拍规则（Open Auction）

## 1.1 与暗拍差异

| 维度 | 暗拍（旧） | 明拍（新） |
|------|-----------|-----------|
| 出价可见性 | 轮末才公开 | 实时公开最高价与领先者 |
| 出价次数 | 每轮 1 次密封 | 窗口期内可多次加价 |
| 结束条件 | 速胜倍率（1/2 名差） | 封盘无新价 / 速购价 / 达最大轮次 |

## 1.2 回合状态机

```
RoundStart -> OpenBoard -> BidWindow -> CloseBid -> RoundResolve -> (下一 round 或 AuctionWon)
```

- **OpenBoard**：广播 `current_highest_bid`、`current_leader_seat`、`min_next_bid`
- **BidWindow**：持续 `bid_window_seconds`，允许加价
- **CloseBid**：本轮无人加价则封盘
- **RoundResolve**：判定提前结束或进入下一轮

## 1.3 加价规则

- `min_raise`：固定步进（默认 50,000 银币）
- 有效出价：`bid >= min_next_bid` 且 `bid <= seat.silver`
- `min_next_bid = max(starting_bid, current_highest_bid + min_raise)`（当前价为 0 时用 `starting_bid`）

## 1.4 结束条件

1. **封盘成交**：`CloseBid` 时已有有效最高价，且本轮窗口内无新加价 → 成交
2. **速购（quick_buy）**：`highest_bid >= reserve_quick_buy` → 立即成交
3. **硬上限**：达到 `max_rounds` 后按最高价成交；若仍为 0 则流拍
4. **流拍**：全程无人出价 → 无赢家，跳过开箱，全员净收益 0

## 1.5 数据结构 `OpenAuctionBoard`

| 字段 | 类型 | 说明 |
|------|------|------|
| current_highest_bid | int | 当前最高价 |
| current_leader_seat | int | 领先席位，-1 表示无 |
| min_next_bid | int | 下次最低有效出价 |
| round_index | int | 当前轮次 1..max_rounds |
| raises_this_round | int | 本轮加价次数 |
| window_active | bool | 是否在出价窗口 |

## 1.6 实现文件

- 规则：`scripts/match/open_auction_rules.gd`
- 驱动：`scripts/match/match_controller.gd`
- 常量：`scripts/autoload/game_constants.gd`、`config/match_config.json`
