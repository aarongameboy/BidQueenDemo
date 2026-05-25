# BidKing Demo（Godot 4.6）

明拍 MVP：主角可参与、Bot 同场竞价、500 道具配置表驱动仓库生成。

## 运行

```powershell
& "D:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe" --path "D:\bidKingDemo"
```

Godot MCP `projectPath`: `D:\bidKingDemo`

## 配置

| 文件 | 说明 |
|------|------|
| [config/match_config.json](config/match_config.json) | 人数、主角席位、明拍窗口、加价步进 |
| [config/items_master.csv](config/items_master.csv) | 500 道具（尺寸/价格/icon/品质色） |
| [config/spawn_pool_table.csv](config/spawn_pool_table.csv) | 仓库池权重 |
| [config/quality_modifier_table.csv](config/quality_modifier_table.csv) | 品质修正 |

重新生成 500 道具：

```powershell
python _tools/generate_items_master.py
```

CSV 含中文时请保持 **UTF-8 带 BOM**（Excel 双击打开才不乱码）。若编辑后乱码，执行：

```powershell
python _tools/fix_csv_utf8_bom.py
```

## 设计文档

见 [docs/](docs/) 目录（01~05）。

## 校验

```powershell
& "D:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe" --path "D:\bidKingDemo" --headless --script res://scripts/tools/validate_item_tables.gd
```

## 主角操作

出价窗口内：**加价** / **自定义出价** / **本轮放弃**。
