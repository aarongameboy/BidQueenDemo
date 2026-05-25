/* 本地编辑：仅 localhost + serve_asset_library.py 可写磁盘 */
const LS_KEY = "bidking-asset-library-overrides";

let editMode = false;
let editCapable = false;
let overrides = { version: 1, assets: {}, tokens: { brand: {}, nav_icons: {} } };
let dirty = false;

function isLocalHost() {
  const h = location.hostname;
  return h === "localhost" || h === "127.0.0.1" || h === "::1";
}

export async function probeEditCapability() {
  if (!isLocalHost()) {
    editCapable = false;
    return false;
  }
  try {
    const res = await fetch("/api/edit-capable", { cache: "no-store" });
    if (!res.ok) return false;
    const data = await res.json();
    editCapable = Boolean(data.editable);
    return editCapable;
  } catch {
    editCapable = false;
    return false;
  }
}

export async function loadOverrides() {
  if (editCapable) {
    try {
      const res = await fetch("/api/overrides", { cache: "no-store" });
      if (res.ok) {
        overrides = await res.json();
        return overrides;
      }
    } catch {
      /* fall through */
    }
  }
  try {
    const res = await fetch("./overrides.json", { cache: "no-store" });
    if (res.ok) {
      overrides = await res.json();
      return overrides;
    }
  } catch {
    /* ignore */
  }
  const raw = localStorage.getItem(LS_KEY);
  if (raw) {
    try {
      overrides = JSON.parse(raw);
    } catch {
      overrides = { version: 1, assets: {}, tokens: { brand: {}, nav_icons: {} } };
    }
  }
  return overrides;
}

export function applyOverridesToManifest(manifest) {
  const assets = overrides.assets || {};
  for (const cat of manifest.categories || []) {
    for (const item of cat.items || []) {
      const ov = assets[item.path];
      if (!ov) continue;
      if (ov.description != null) item.description = ov.description;
      if (ov.note != null) item.userNote = ov.note;
    }
  }
  for (const m of manifest.missingAssets || []) {
    const ov = assets[m.path];
    if (ov?.note) m.userNote = ov.note;
    if (ov?.description) m.missingNote = ov.description;
  }
  const brand = overrides.tokens?.brand || {};
  for (const [idx, ov] of Object.entries(brand)) {
    const c = manifest.tokens?.brand?.[Number(idx)];
    if (c && ov.usage != null) c.usage = ov.usage;
    if (c && ov.name != null) c.name = ov.name;
  }
  const nav = overrides.tokens?.nav_icons || {};
  for (const ic of manifest.tokens?.nav_icons || []) {
    const ov = nav[ic.file];
    if (ov?.label != null) ic.label = ov.label;
    if (ov?.note != null) ic.userNote = ov.note;
  }
  return manifest;
}

function ensureAssetOverride(path) {
  if (!overrides.assets[path]) overrides.assets[path] = {};
  return overrides.assets[path];
}

export function setAssetDescription(path, text) {
  ensureAssetOverride(path).description = text;
  dirty = true;
}

export function setAssetNote(path, text) {
  ensureAssetOverride(path).note = text;
  dirty = true;
}

export function setBrandToken(index, field, text) {
  if (!overrides.tokens.brand) overrides.tokens.brand = {};
  if (!overrides.tokens.brand[String(index)]) overrides.tokens.brand[String(index)] = {};
  overrides.tokens.brand[String(index)][field] = text;
  dirty = true;
}

export function setNavIcon(file, field, text) {
  if (!overrides.tokens.nav_icons) overrides.tokens.nav_icons = {};
  if (!overrides.tokens.nav_icons[file]) overrides.tokens.nav_icons[file] = {};
  overrides.tokens.nav_icons[file][field] = text;
  dirty = true;
}

export function isEditMode() {
  return editMode;
}

export function setEditMode(on) {
  editMode = on;
}

export function isDirty() {
  return dirty;
}

export function markClean() {
  dirty = false;
}

export function canSaveToDisk() {
  return editCapable && isLocalHost();
}

export async function saveOverrides() {
  overrides.updatedAt = new Date().toISOString();
  if (canSaveToDisk()) {
    const res = await fetch("/api/overrides", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(overrides),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.error || `保存失败 (${res.status})`);
    }
    markClean();
    return "disk";
  }
  localStorage.setItem(LS_KEY, JSON.stringify(overrides));
  markClean();
  return "localStorage";
}

export function discardLocalDraft() {
  dirty = false;
}

export function downloadOverridesBackup() {
  const blob = new Blob([JSON.stringify(overrides, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "overrides.json";
  a.click();
  URL.revokeObjectURL(a.href);
}

export function renderEditToolbar(container, { onSave, onDiscard, onToggle }) {
  const local = isLocalHost();
  const saveHint = editCapable
    ? "可保存到 docs/asset-library/overrides.json"
    : local
      ? "请用 python tools/serve_asset_library.py 启动以写入磁盘"
      : "非本机地址，不可编辑";

  container.innerHTML = `
    <div class="edit-bar ${editMode ? "active" : ""}" id="edit-bar">
      <label class="edit-toggle">
        <input type="checkbox" id="edit-mode-toggle" ${editMode ? "checked" : ""} ${local ? "" : "disabled"} />
        编辑模式
      </label>
      <span class="edit-hint">${saveHint}</span>
      <div class="edit-actions ${editMode ? "" : "hidden"}">
        <button type="button" class="edit-btn primary" id="edit-save-btn" ${dirty ? "" : "disabled"}>保存</button>
        <button type="button" class="edit-btn" id="edit-discard-btn">放弃未保存</button>
        <button type="button" class="edit-btn" id="edit-export-btn">导出 JSON</button>
      </div>
      ${dirty ? '<span class="edit-dirty">未保存</span>' : ""}
    </div>`;

  const toggle = container.querySelector("#edit-mode-toggle");
  toggle?.addEventListener("change", () => {
    setEditMode(toggle.checked);
    onToggle();
  });
  container.querySelector("#edit-save-btn")?.addEventListener("click", onSave);
  container.querySelector("#edit-discard-btn")?.addEventListener("click", onDiscard);
  container.querySelector("#edit-export-btn")?.addEventListener("click", downloadOverridesBackup);
}

export function refreshEditToolbar(container, opts) {
  renderEditToolbar(container, opts);
}

export function descFieldHtml(path, value, extraClass = "") {
  if (!editMode) {
    return `<p class="desc ${extraClass}">${escapeHtmlEdit(value)}</p>`;
  }
  return `<textarea class="edit-field desc-edit ${extraClass}" data-edit="desc" data-path="${escapeHtmlAttr(path)}" rows="3">${escapeHtmlEdit(value)}</textarea>`;
}

export function noteFieldHtml(path, value, kind = "asset") {
  const label = value || editMode ? "备注" : "";
  if (!editMode && !value) return "";
  if (!editMode) {
    return `<p class="user-note">${escapeHtmlEdit(value)}</p>`;
  }
  const dataKind = kind === "nav" ? "nav-note" : "note";
  const fileAttr = kind === "nav" ? ` data-file="${escapeHtmlAttr(path.replace(/^.*\//, ""))}"` : "";
  const pathAttr = kind === "asset" ? ` data-path="${escapeHtmlAttr(path)}"` : "";
  return `<label class="note-label">备注<textarea class="edit-field note-edit" data-edit="${dataKind}"${pathAttr}${fileAttr} rows="2" placeholder="本地备注，写入 overrides.json">${escapeHtmlEdit(value || "")}</textarea></label>`;
}

export function bindEditFields(root, onChange) {
  root.querySelectorAll("[data-edit]").forEach((el) => {
    el.addEventListener("input", () => {
      const path = el.dataset.path;
      const kind = el.dataset.edit;
      const file = el.dataset.file;
      const idx = el.dataset.brandIdx;
      const field = el.dataset.field;
      if (kind === "desc" && path) setAssetDescription(path, el.value);
      else if (kind === "note" && path) setAssetNote(path, el.value);
      else if (kind === "nav-note" && file) setNavIcon(file, "note", el.value);
      else if (kind === "brand" && idx != null) setBrandToken(Number(idx), field || "usage", el.value);
      else if (kind === "nav" && file) setNavIcon(file, field || "label", el.value);
      onChange();
    });
  });
}

function escapeHtmlEdit(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function escapeHtmlAttr(s) {
  return escapeHtmlEdit(s).replace(/'/g, "&#39;");
}
