# BidKing Demo · 本地美术资源库

类似设计系统文档的静态页面，用于查看项目内美术资源、Godot 引用路径、文案说明与颜色/字体规范。

## 打开方式

1. 生成/更新清单（资源或代码变更后执行）：

```bash
python tools/generate_asset_library.py
```

2. 用浏览器打开（**必须先执行第 1 步**，生成 `preview/` 预览图）：

**推荐（含本地编辑，仅本机）**：

```bash
python tools/serve_asset_library.py
```

访问 http://127.0.0.1:8765/ ，打开顶部 **编辑模式**，修改描述/备注后点 **保存**，写入 `docs/asset-library/overrides.json`。再次运行生成器会把 overrides 合并进 `manifest.json`。

**只读预览**（不可保存到磁盘）：

```bash
cd docs/asset-library
python -m http.server 8765
```

访问 http://localhost:8765（编辑内容可暂存浏览器 localStorage，可点「导出 JSON」）

> 服务仅绑定 `127.0.0.1`，外网无法访问。不要用 `file://` 打开页面。

## 给 Cursor 批量替换用

- 每张资源卡片可 **复制** `res://assets/...` 路径
- 「代码引用」列出 `.gd` / `.json` / `.tscn` / `.csv` 中的行号
- 「缺失资源」表列出代码引用但磁盘不存在的路径（如字体、`close.png`）

更新资源后重新运行生成器，再刷新页面即可。

## 维护描述文案

- **网页编辑**：`serve_asset_library.py` + 编辑模式 → `overrides.json`
- **代码维护**：`tools/generate_asset_library.py` 的 `MANUAL_DESC`
- **自动说明**：`characters.json` / `items_master.csv` / `map_modes.json`
