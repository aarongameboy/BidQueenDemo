# 05 编码执行顺序与验收

## 5.1 已完成（本迭代）

1. 明拍规则脚本 + `match_config.json`
2. `match_controller` 窗口式公开竞价
3. 主角 UI（加价 / 自定义 / 放弃）
4. 道具三表 + 500 条 `items_master.csv`
5. `item_catalog.gd` + `warehouse` 池抽样

## 5.2 建议下一步

1. 仓库二维摆放 UI（按 size_w/size_h 可视化）
2. 加载真实 icon 纹理
3. 热重载配置（F5 或调试键）
4. Bot 明拍参数调参工具

## 5.3 验收清单

- [ ] 主角 seat 0 可与 Bot 完成一局明拍
- [ ] UI 实时显示最高价与领先者
- [ ] 封盘无新价时成交；全程无出价则流拍
- [ ] 开箱物品来自 `items_master`，含名称/品质/价格
- [ ] 同 `match_seed` 生成仓库可复现
- [ ] `validate_item_tables.gd` 无报错

## 5.4 Godot 路径

`projectPath`: `D:\bidKingDemo`

```powershell
& "D:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe" --path "D:\bidKingDemo"
```
