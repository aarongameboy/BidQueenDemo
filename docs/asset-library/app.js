/* BidKing Demo · 本地美术资源库 */
import {
  probeEditCapability,
  loadOverrides,
  applyOverridesToManifest,
  isEditMode,
  setEditMode,
  isDirty,
  markClean,
  discardLocalDraft,
  saveOverrides,
  canSaveToDisk,
  renderEditToolbar,
  refreshEditToolbar,
  descFieldHtml,
  noteFieldHtml,
  bindEditFields,
} from "./edit.js";

let manifest = null;
let activeTab = "assets";
let searchQuery = "";

async function loadManifest() {
  const res = await fetch("./manifest.json");
  if (!res.ok) throw new Error("无法加载 manifest.json，请先运行 tools/generate_asset_library.py");
  manifest = await res.json();
}

function $(sel) {
  return document.querySelector(sel);
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function copyText(text, btn) {
  navigator.clipboard.writeText(text).then(() => {
    const old = btn.textContent;
    btn.textContent = "已复制";
    setTimeout(() => { btn.textContent = old; }, 1200);
  });
}

function matchesSearch(item) {
  if (!searchQuery) return true;
  const q = searchQuery.toLowerCase();
  const blob = [
    item.path,
    item.fileName,
    item.description,
    item.userNote,
    ...(item.usages || []).map((u) => `${u.file}:${u.line} ${u.snippet}`),
  ].join(" ").toLowerCase();
  return blob.includes(q);
}

function assetMediaUrl(item) {
  if (!item.exists) return "";
  if (item.previewUrl) return item.previewUrl;
  if (item.webUrl) return item.webUrl;
  return item.relFile || "";
}

function renderAssetCard(item) {
  const missing = !item.exists;
  const mediaUrl = assetMediaUrl(item);
  let previewHtml = "";
  if (item.ext === ".mp3" && mediaUrl) {
    previewHtml = `<audio controls src="${escapeHtml(mediaUrl)}"></audio>`;
  } else if (mediaUrl && /\.(png|jpe?g|svg|webp)$/i.test(item.ext)) {
    previewHtml = `<img src="${escapeHtml(mediaUrl)}" alt="${escapeHtml(item.fileName)}" loading="lazy" />`;
  } else if (item.ext === ".ttf" || item.ext === ".otf") {
    previewHtml = `<div class="placeholder">字体文件<br>${escapeHtml(item.fileName)}</div>`;
  } else {
    previewHtml = `<div class="placeholder">无预览</div>`;
  }

  const usages = item.usages || [];
  const usageHtml = usages.length
    ? `<details class="usages"><summary>代码引用 (${item.usageCount})</summary><ul>${usages
        .map(
          (u) =>
            `<li><strong>${escapeHtml(u.file)}:${u.line}</strong><br>${escapeHtml(u.snippet)}</li>`
        )
        .join("")}</ul></details>`
    : `<div class="usages">无代码引用记录</div>`;

  return `
    <article class="asset-card ${missing ? "missing" : ""}" data-path="${escapeHtml(item.path)}">
      <div class="preview">
        ${missing ? '<span class="flag-missing">磁盘缺失</span>' : ""}
        ${previewHtml}
      </div>
      <div class="card-body">
        <h3>${escapeHtml(item.fileName)}</h3>
        ${descFieldHtml(item.path, item.description)}
        ${noteFieldHtml(item.path, item.userNote)}
        <div class="path-row">
          <code>${escapeHtml(item.path)}</code>
          <button type="button" class="copy-btn" data-copy="${escapeHtml(item.path)}">复制</button>
        </div>
        ${usageHtml}
      </div>
    </article>`;
}

function renderAssetsPanel() {
  const main = $("#main-content");
  let html = "";

  if (manifest.stats.missingOnDisk > 0) {
    html += `<div class="alert">有 <strong>${manifest.stats.missingOnDisk}</strong> 个路径在代码/config 中被引用但磁盘上不存在（多为字体或 close.png）。见下方「缺失资源」或运行生成器后对照修复。</div>`;
  }

  html += `<section class="section" id="sec-all"><h2>全部资源</h2><p class="lead">共 ${manifest.stats.assetFiles} 个文件，${manifest.stats.referencedPaths} 条 res:// 引用。生成时间：${escapeHtml(manifest.generatedAt)}</p><div class="card-grid" id="grid-all"></div></section>`;

  for (const cat of manifest.categories) {
    html += `<section class="section" id="sec-${cat.id}"><h2>${escapeHtml(cat.name)}</h2><p class="lead">${cat.count} 项</p><div class="card-grid" id="grid-${cat.id}"></div></section>`;
  }

  if (manifest.missingAssets?.length) {
    html += `<section class="section" id="sec-missing"><h2>缺失资源</h2><p class="lead">代码中有引用但 assets 目录未找到</p><div class="table-wrap"><table><thead><tr><th>路径</th><th>引用次数</th><th>示例</th>${isEditMode() ? "<th>备注</th>" : ""}</tr></thead><tbody>`;
    for (const m of manifest.missingAssets) {
      const u = m.usages?.[0];
      const noteCell = isEditMode()
        ? `<td><textarea class="edit-field note-edit" data-edit="note" data-path="${escapeHtml(m.path)}" rows="2">${escapeHtml(m.userNote || m.missingNote || "")}</textarea></td>`
        : m.userNote || m.missingNote
          ? `<td class="user-note">${escapeHtml(m.userNote || m.missingNote)}</td>`
          : "";
      html += `<tr class="missing"><td><code>${escapeHtml(m.path)}</code></td><td>${m.usageCount}</td><td>${u ? escapeHtml(`${u.file}:${u.line}`) : "—"}</td>${noteCell}</tr>`;
    }
    html += `</tbody></table></div></section>`;
  }

  main.innerHTML = html;

  const allItems = manifest.categories.flatMap((c) => c.items);
  const filtered = allItems.filter(matchesSearch);

  const gridAll = $("#grid-all");
  if (gridAll) gridAll.innerHTML = filtered.map(renderAssetCard).join("");

  for (const cat of manifest.categories) {
    const grid = document.getElementById(`grid-${cat.id}`);
    if (!grid) continue;
    const items = cat.items.filter(matchesSearch);
    grid.innerHTML = items.map(renderAssetCard).join("");
  }

  document.querySelectorAll(".copy-btn").forEach((btn) => {
    btn.addEventListener("click", () => copyText(btn.dataset.copy, btn));
  });
  bindEditFields(main, onEditFieldChange);
}

function renderColorsPanel() {
  const t = manifest.tokens;
  const main = $("#main-content");
  let html = `<section class="section"><h2>颜色规范</h2><p class="lead">品牌色来自 docs/art_concept；品质色与 GameConstants.QUALITY_COLOR_HEX 一致。</p>`;

  html += `<h3 style="margin:24px 0 12px;font-size:16px">品牌主色（美术方案）</h3><div class="token-grid">`;
  t.brand.forEach((c, idx) => {
    const usageHtml = isEditMode()
      ? `<textarea class="edit-field" data-edit="brand" data-brand-idx="${idx}" data-field="usage" rows="2">${escapeHtml(c.usage)}</textarea>`
      : escapeHtml(c.usage);
    html += `<div class="token-swatch"><div class="chip" style="background:${c.hex}"></div><div class="info"><strong>${escapeHtml(c.name)}</strong><br><span class="hex">${c.hex}</span><br>${usageHtml}</div></div>`;
  });
  html += `</div>`;

  html += `<h3 style="margin:24px 0 12px;font-size:16px">道具品质色</h3><div class="token-grid">`;
  for (const q of t.quality) {
    html += `<div class="token-swatch"><div class="chip" style="background:${q.hex}"></div><div class="info"><strong>${escapeHtml(q.label)} · ${q.key}</strong><br><span class="hex">${q.hex}</span></div></div>`;
  }
  html += `</div>`;

  html += `<h3 style="margin:24px 0 12px;font-size:16px">UI 常用色（代码）</h3><div class="table-wrap"><table><thead><tr><th>名称</th><th>Hex 近似</th><th>Godot RGB</th><th>来源</th></tr></thead><tbody>`;
  for (const u of t.ui_accents) {
    html += `<tr><td>${escapeHtml(u.name)}</td><td>${u.hex}</td><td>${escapeHtml(u.rgb)}</td><td>${escapeHtml(u.file)}</td></tr>`;
  }
  html += `</tbody></table></div></section>`;
  main.innerHTML = html;
  bindEditFields(main, onEditFieldChange);
}

function renderFontsPanel() {
  const t = manifest.tokens;
  const main = $("#main-content");
  let html = `<section class="section"><h2>字体规范</h2><p class="lead">见 scripts/ui/font_util.gd。视口 ${t.viewport.width}×${t.viewport.height}。</p>`;

  for (const f of t.fonts) {
    const status = f.exists ? '<span style="color:var(--ok)">文件存在</span>' : '<span style="color:var(--danger)">文件缺失（使用系统回退）</span>';
    html += `<div class="font-sample">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
        <strong>${escapeHtml(f.role)}</strong>${status}
      </div>
      <div class="sample-title">${f.role === "标题" ? "王冠竞拍会" : "出价已提交，等待其他玩家"}</div>
      <div class="sample-body">${escapeHtml(f.code)}<br>回退：${escapeHtml(f.fallback)}</div>
      <ul style="margin:8px 0 0;padding-left:18px;font-size:12px;color:var(--muted)">`;
    for (const p of f.paths) {
      html += `<li><code>${escapeHtml(p)}</code></li>`;
    }
    html += `</ul></div>`;
  }
  main.innerHTML = html;
}

function renderNavIconsPanel() {
  const icons = manifest.tokens.nav_icons;
  const main = $("#main-content");
  let html = `<section class="section"><h2>导航图标</h2><p class="lead">lobby_ui.gd · ICONS_DIR · 运行时 Shader 染色 NAV_ICON_TINT</p><div class="card-grid">`;
  for (const ic of icons) {
    const path = `res://assets/ui/icons/${ic.file}`;
    const imgUrl = `preview/assets/ui/icons/${ic.file}`;
    const titleHtml = isEditMode()
      ? `<input class="edit-field title-edit" data-edit="nav" data-file="${escapeHtml(ic.file)}" data-field="label" value="${escapeHtml(ic.label)}" />`
      : escapeHtml(ic.label);
    html += `
      <article class="asset-card">
        <div class="preview" style="background:#1a2030">
          <img src="${escapeHtml(imgUrl)}" alt="${ic.label}" style="width:48px;height:48px;filter:brightness(1.2)" />
        </div>
        <div class="card-body">
          <h3>${titleHtml}</h3>
          <p class="desc">action: ${escapeHtml(ic.action)}</p>
          ${noteFieldHtml(path, ic.userNote, "nav")}
          <div class="path-row">
            <code>${path}</code>
            <button type="button" class="copy-btn" data-copy="${path}">复制</button>
          </div>
        </div>
      </article>`;
  }
  html += `</div></section>`;
  main.innerHTML = html;
  document.querySelectorAll(".copy-btn").forEach((btn) => {
    btn.addEventListener("click", () => copyText(btn.dataset.copy, btn));
  });
  bindEditFields(main, onEditFieldChange);
}

function renderSidebar() {
  const nav = $("#sidebar-nav");
  let html = `<h3>资源分类</h3><a class="nav-item" data-jump="sec-all">全部资源 <span class="badge">${manifest.stats.assetFiles}</span></a>`;
  for (const cat of manifest.categories) {
    html += `<a class="nav-item" data-jump="sec-${cat.id}">${escapeHtml(cat.name)} <span class="badge">${cat.count}</span></a>`;
  }
  if (manifest.missingAssets?.length) {
    html += `<a class="nav-item" data-jump="sec-missing">缺失资源 <span class="badge">${manifest.missingAssets.length}</span></a>`;
  }
  nav.innerHTML = html;
  nav.querySelectorAll(".nav-item").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      const id = el.dataset.jump;
      document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
      nav.querySelectorAll(".nav-item").forEach((n) => n.classList.remove("active"));
      el.classList.add("active");
    });
  });
}

function scrollToSection(sectionId) {
  const el = document.getElementById(sectionId);
  if (!el) return;
  el.scrollIntoView({ behavior: "smooth", block: "start" });
}

function bindTocNav(tocRoot) {
  tocRoot.querySelectorAll("[data-jump]").forEach((link) => {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      scrollToSection(link.dataset.jump);
      tocRoot.querySelectorAll("[data-jump]").forEach((n) => n.classList.remove("active"));
      link.classList.add("active");
    });
  });
}

function renderToc() {
  const toc = $("#page-toc");
  if (activeTab !== "assets") {
    toc.innerHTML = "<h4>本页</h4><p class=\"toc-hint\">见主内容标题</p>";
    return;
  }
  let html = "<h4>本页</h4>";
  html += `<a href="#" class="toc-link" data-jump="sec-all">全部资源</a>`;
  for (const cat of manifest.categories) {
    html += `<a href="#" class="toc-link" data-jump="sec-${cat.id}">${escapeHtml(cat.name)}</a>`;
  }
  if (manifest.missingAssets?.length) {
    html += `<a href="#" class="toc-link" data-jump="sec-missing">缺失资源</a>`;
  }
  toc.innerHTML = html;
  bindTocNav(toc);
}

function switchTab(tab) {
  activeTab = tab;
  document.querySelectorAll("#main-tabs .view-tab").forEach((t) => {
    t.classList.toggle("active", t.dataset.tab === tab);
  });
  document.querySelector(".sidebar").classList.toggle("hidden", tab !== "assets");
  document.querySelector(".toc").classList.toggle("hidden", tab !== "assets");

  if (tab === "assets") renderAssetsPanel();
  else if (tab === "colors") renderColorsPanel();
  else if (tab === "fonts") renderFontsPanel();
  else if (tab === "icons") renderNavIconsPanel();

  renderToc();
}

function onEditFieldChange() {
  refreshEditToolbar($("#edit-toolbar"), editToolbarHandlers());
  if (activeTab === "assets" && searchQuery) return;
}

const editToolbarHandlers = () => ({
  onToggle: () => {
    switchTab(activeTab);
    refreshEditToolbar($("#edit-toolbar"), editToolbarHandlers());
  },
  onSave: async () => {
    try {
      const where = await saveOverrides();
      applyOverridesToManifest(manifest);
      switchTab(activeTab);
      refreshEditToolbar($("#edit-toolbar"), editToolbarHandlers());
      const msg = where === "disk"
        ? "已保存到 overrides.json（重新生成 manifest 时会合并）"
        : "已保存到浏览器 localStorage（请导出 JSON 或改用 serve 脚本）";
      $("#edit-status").textContent = msg;
      setTimeout(() => { $("#edit-status").textContent = ""; }, 4000);
    } catch (err) {
      $("#edit-status").textContent = err.message;
    }
  },
  onDiscard: async () => {
    discardLocalDraft();
    await loadOverrides();
    applyOverridesToManifest(manifest);
    switchTab(activeTab);
    refreshEditToolbar($("#edit-toolbar"), editToolbarHandlers());
  },
});

function init() {
  $("#generated-meta").textContent = `生成于 ${manifest.generatedAt.slice(0, 19).replace("T", " ")} UTC`;
  renderSidebar();
  switchTab("assets");

  $("#search-input").addEventListener("input", (e) => {
    searchQuery = e.target.value.trim();
    if (activeTab === "assets") renderAssetsPanel();
  });

  const mainTabs = $("#main-tabs");
  mainTabs?.addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-tab]");
    if (!btn || !mainTabs.contains(btn)) return;
    switchTab(btn.dataset.tab);
  });

  refreshEditToolbar($("#edit-toolbar"), editToolbarHandlers());
}

async function bootstrap() {
  await loadManifest();
  await probeEditCapability();
  await loadOverrides();
  applyOverridesToManifest(manifest);
  init();
}

bootstrap().catch((err) => {
  document.body.innerHTML = `<pre style="padding:24px;color:#f88">${escapeHtml(err.message)}</pre>`;
});
