// da_tack UI. Receives state from the client via window messages and drives
// edits back through NUI fetch callbacks. Live preview: every action re-reads the
// equipped set returned by the client and updates highlights.

const RES = "da_tack";
const $ = (id) => document.getElementById(id);

const state = {
  pedType: null,
  categories: [],
  catIndex: -1,      // keyboard cursor over categories
  activeCat: null,   // { name, hash }
  items: [],         // entries (flat) or styles (two-axis) for the active category
  itemIndex: -1,     // keyboard/drag cursor over the item list
  equipped: new Set(),
  occupied: new Set(), // category names that currently have an item equipped
  selected: null,    // entry currently showing the tint stepper
  mandatory: false,  // active category can't be emptied (hide "remove")
  // two-axis (body / hair / eyes): a style list + a color/tone/tint dropdown
  twoAxis: false,
  axis: null,        // "color" | "skin" | "tint"
  variants: [],      // [{ key, label }] dropdown options
  variantKey: null,  // current dropdown selection
  variantByCat: {},  // remember the chosen variant per category
};

let dragging = false;   // left mouse held over the item list (drag to try on)
let lastDragIdx = -1;
let suspended = false;  // a higher-priority mode is active: ignore our input

function post(cb, body) {
  return fetch(`https://${RES}/${cb}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(body || {}),
  }).then((r) => r.json().catch(() => ({}))).catch(() => ({}));
}

function setEquipped(list) {
  state.equipped = new Set((list || []).map((h) => h >>> 0));
}

// Apply an edit result: refresh equipped + occupied-category dots, re-render both.
function applyResult(r) {
  setEquipped(r.equipped);
  if (r.cats) state.occupied = new Set(r.cats);
  // keep the dropdown in sync with whatever color/tone is actually on the body
  if (state.twoAxis) {
    const eq = equippedTwoAxis();
    if (eq) state.variantKey = eq.variantKey;
  }
  renderCategories();
  renderItems();
}

// An entry is equipped if any of its variants is on; returns the variant index (1-based) or 0.
function equippedVariant(entry) {
  for (let i = 0; i < entry.variants.length; i++) {
    if (state.equipped.has(entry.variants[i] >>> 0)) return i + 1;
  }
  return 0;
}

// ---- two-axis helpers ----
// A "style" entry has a byVariant map (color/tone axis); a leftover row that
// doesn't fit the scheme is a plain entry with a single-hash variants list.
const isStyle = (e) => !!(e && e.byVariant);

// The hash for a style at a given variant key, falling back to its first
// available variant (a few styles are missing a color/tone).
function styleVariantHash(style, vk) {
  if (style.byVariant[vk] != null) return style.byVariant[vk];
  const keys = Object.keys(style.byVariant);
  return keys.length ? style.byVariant[keys[0]] : null;
}

// Is any hash of this entry (style variants, or a plain row) currently on?
function isOn(entry) {
  if (isStyle(entry)) {
    for (const k in entry.byVariant) if (state.equipped.has(entry.byVariant[k] >>> 0)) return true;
    return false;
  }
  return (entry.variants || []).some((h) => state.equipped.has(h >>> 0));
}

// Which (style, variant) is currently equipped in a two-axis category, or null.
function equippedTwoAxis() {
  for (const s of state.items) {
    if (!isStyle(s)) continue;
    for (const k in s.byVariant) {
      if (state.equipped.has(s.byVariant[k] >>> 0)) return { styleKey: s.key, variantKey: k };
    }
  }
  return null;
}

// ---- rendering ----
function renderCategories() {
  const el = $("categories");
  el.innerHTML = "";
  for (const cat of state.categories) {
    const d = document.createElement("div");
    const active = state.activeCat && state.activeCat.name === cat.name ? " active" : "";
    const occ = state.occupied.has(cat.name) ? " occupied" : "";
    d.className = "cat" + active + occ;
    const name = document.createElement("span"); name.className = "cat-name"; name.textContent = cat.label || cat.name;
    const dot = document.createElement("span"); dot.className = "cat-dot";
    d.appendChild(name); d.appendChild(dot);
    d.onclick = () => selectCategory(cat);
    el.appendChild(d);
  }
}

function renderItems() {
  $("remove").classList.toggle("hidden", !!state.mandatory);
  renderAxis();
  const el = $("items");
  el.innerHTML = "";
  const view = state.items;
  if (!view.length) {
    el.innerHTML = `<div class="empty">no items</div>`;
    renderTintBar();
    renderCount();
    return;
  }
  view.forEach((entry, i) => {
    const on = state.twoAxis ? isOn(entry) : equippedVariant(entry) > 0;
    const row = document.createElement("div");
    row.className = "item" + (on ? " equipped" : "") + (i === state.itemIndex ? " focused" : "");
    row.dataset.idx = i;   // index into the VISIBLE list; click/drag via delegation
    const dot = document.createElement("span"); dot.className = "item-dot";
    const name = document.createElement("span"); name.className = "item-name"; name.textContent = entry.label;
    row.appendChild(dot); row.appendChild(name);
    if (!state.twoAxis && entry.variants.length > 1) {
      const tag = document.createElement("span"); tag.className = "item-tag";
      tag.textContent = `×${entry.variants.length}`;
      row.appendChild(tag);
    }
    el.appendChild(row);
  });
  renderTintBar();
  renderCount();
}

// A dim count line at the foot of the list (e.g. "312 items").
function renderCount() {
  const el = $("count");
  const total = state.items.length;
  el.textContent = total ? `${total} item${total === 1 ? "" : "s"}` : "";
}

// The color/tone dropdown above the style list (two-axis categories only).
// Hidden while a leftover row (one that doesn't fit the scheme) is selected.
function renderAxis() {
  const bar = $("axisbar");
  const showForSel = !state.selected || isStyle(state.selected);
  if (!state.twoAxis || !state.variants.length || !showForSel) { bar.classList.add("hidden"); return; }
  bar.classList.remove("hidden");
  $("axis-label").textContent = state.axis === "skin" ? "skin tone" : "color";
  const cur = state.variants.find((v) => v.key === state.variantKey);
  $("axis-cur").textContent = cur ? cur.label : "—";
  const list = $("axis-list");
  list.innerHTML = "";
  for (const v of state.variants) {
    const o = document.createElement("div");
    o.className = "dd-opt" + (v.key === state.variantKey ? " sel" : "");
    o.textContent = v.label;
    o.onclick = () => { closeAxis(); setVariant(v.key); };
    list.appendChild(o);
  }
}

function renderTintBar() {
  const bar = $("tintbar");
  const entry = state.selected;
  if (state.twoAxis || !entry || entry.variants.length < 2) { bar.classList.add("hidden"); return; }
  const idx = equippedVariant(entry);
  $("tint-name").textContent = entry.label;
  $("tint-pos").textContent = idx ? `${idx} / ${entry.variants.length}` : `– / ${entry.variants.length}`;
  bar.classList.remove("hidden");
}

function renderOutfits(slots) {
  const el = $("outfits");
  el.innerHTML = "";
  for (const slot of slots || []) {
    const chip = document.createElement("div");
    chip.className = "slot-chip";
    const name = document.createElement("span");
    name.className = "slot-name"; name.textContent = slot;
    name.onclick = () => post("loadTack", { slot }).then(applyResult);
    const del = document.createElement("span");
    del.className = "slot-del"; del.textContent = "✕";
    del.onclick = (e) => { e.stopPropagation(); post("deleteTack", { slot }).then((r) => renderOutfits(r.outfits)); };
    chip.appendChild(name); chip.appendChild(del);
    el.appendChild(chip);
  }
}

function refreshHighlights() {
  renderItems();
}

// ---- actions ----
function selectCategory(cat) {
  state.activeCat = cat;
  state.catIndex = state.categories.findIndex((c) => c.name === cat.name);
  state.selected = null;
  state.itemIndex = -1;
  closeAxis();
  renderCategories();
  post("items", { category: cat.name }).then((r) => {
    state.mandatory = !!r.mandatory;
    state.twoAxis = !!r.twoAxis;
    if (r.twoAxis) {
      state.axis = r.axis;
      state.variants = r.variants || [];
      state.items = r.styles || [];   // rows are styles; color picked via dropdown
      state.variantKey = state.variantByCat[cat.name]
        || (state.variants[0] && state.variants[0].key) || null;
    } else {
      state.items = r.items || [];
    }
    applyResult(r);   // syncs variantKey to whatever is equipped, if anything
  });
}

// Equip an entry. For flat categories `variantIdx` picks the tint; for two-axis
// categories the variant comes from the dropdown selection.
function equipEntry(entry, variantIdx) {
  state.selected = entry;
  const i = state.items.indexOf(entry);
  if (i >= 0) state.itemIndex = i;
  const hash = state.twoAxis
    ? (isStyle(entry) ? styleVariantHash(entry, state.variantKey) : entry.variants[0])
    : entry.variants[(variantIdx || 1) - 1];
  if (hash != null) post("equip", { hash }).then(applyResult);
}

// equip the entry under a row element (click / drag)
function tryOn(entry) {
  if (state.twoAxis) equipEntry(entry, 0);
  else equipEntry(entry, equippedVariant(entry) || 1);
}

function equipRow(row) {
  const entry = state.items[Number(row.dataset.idx)];
  if (entry) tryOn(entry);
}

// Change the active color/tone/tint. If a style is on, re-equip it in the new
// variant; otherwise just remember the choice for the next style pick.
function setVariant(vk) {
  state.variantKey = vk;
  if (state.activeCat) state.variantByCat[state.activeCat.name] = vk;
  const eq = equippedTwoAxis();
  const style = eq ? state.items.find((s) => s.key === eq.styleKey) : state.selected;
  if (isStyle(style)) {
    const hash = styleVariantHash(style, vk);
    if (hash != null) { post("equip", { hash }).then(applyResult); return; }
  }
  renderItems();
}

function closeAxis() { $("axis-list").classList.add("hidden"); }

// ---- keyboard / drag navigation ----
function stepCategory(delta) {
  if (!state.categories.length) return;
  let i = state.catIndex < 0 ? 0 : (state.catIndex + delta + state.categories.length) % state.categories.length;
  selectCategory(state.categories[i]);
  const el = $("categories").children[i];
  if (el) el.scrollIntoView({ block: "nearest" });
}

function stepItem(delta) {
  const view = state.items;
  if (!view.length) return;
  state.itemIndex = state.itemIndex < 0
    ? (delta > 0 ? 0 : view.length - 1)
    : (state.itemIndex + delta + view.length) % view.length;
  tryOn(view[state.itemIndex]);
  const el = $("items").children[state.itemIndex];
  if (el) el.scrollIntoView({ block: "nearest" });
}

function stepTint(delta) {
  const entry = state.selected;
  if (!entry || entry.variants.length < 2) return;
  let idx = equippedVariant(entry) || 1;
  idx = ((idx - 1 + delta + entry.variants.length) % entry.variants.length) + 1;
  equipEntry(entry, idx);
}

// ---- wiring ----
$("close").onclick = () => post("close");
$("strip").onclick = () => post("stripAll").then(applyResult);
$("remove").onclick = () => {
  if (!state.activeCat || state.mandatory) return;
  state.selected = null;
  post("removeCategory", { categoryHash: state.activeCat.hash, category: state.activeCat.name }).then(applyResult);
};
$("save").onclick = () => {
  const slot = $("slot").value.trim() || "default";
  post("saveTack", { slot }).then((r) => renderOutfits(r.outfits));
};
$("tint-prev").onclick = () => stepTint(-1);
$("tint-next").onclick = () => stepTint(1);

// color/tone/tint dropdown: toggle on its button, close on any outside click
$("axis-btn").onclick = (e) => { e.stopPropagation(); $("axis-list").classList.toggle("hidden"); };
document.addEventListener("click", (e) => { if (!$("axis-dd").contains(e.target)) closeAxis(); });

document.addEventListener("keydown", (e) => {
  if (!visible() || suspended) return;
  const typing = document.activeElement && document.activeElement.tagName === "INPUT";
  switch (e.key) {
    case "Escape": post("close"); break;
    case "ArrowLeft": if (typing) return; e.preventDefault(); stepCategory(-1); break;
    case "ArrowRight": if (typing) return; e.preventDefault(); stepCategory(1); break;
    case "ArrowUp": e.preventDefault(); stepItem(-1); break;   // works while filtering too
    case "ArrowDown": e.preventDefault(); stepItem(1); break;
  }
});

// Click / drag to try on: mousedown on an item equips it; dragging over rows with
// the button held equips each one passed over. Delegated to the container so it
// survives the re-render each equip triggers.
$("items").addEventListener("mousedown", (e) => {
  if (e.button !== 0 || suspended) return;
  const row = e.target.closest(".item");
  if (!row) return;
  e.preventDefault();
  dragging = true;
  lastDragIdx = Number(row.dataset.idx);
  equipRow(row);
});
$("items").addEventListener("mouseover", (e) => {
  if (!dragging) return;
  const row = e.target.closest(".item");
  if (!row) return;
  const idx = Number(row.dataset.idx);
  if (idx === lastDragIdx) return;   // don't re-equip the same row
  lastDragIdx = idx;
  equipRow(row);
});
window.addEventListener("mouseup", (e) => { if (e.button === 0) { dragging = false; lastDragIdx = -1; } });

// Middle-click passthrough (MCP). The browser keeps receiving mouse events while
// passthrough is active (focus stays true, game input kept alive), so JS drives it:
//   tap  (< QUICK_MS)  -> toggle MCP on; tap again to toggle off
//   hold (> QUICK_MS)  -> momentary; releasing returns focus to the UI
const QUICK_MS = 400;
let mcp = false;
let quickPress = false;
const visible = () => !$("app").classList.contains("hidden");

window.addEventListener("mousedown", (e) => {
  if (e.button !== 1 || !visible() || suspended) return;
  e.preventDefault();
  if (mcp) {
    mcp = false;
    post("deactivateMCP");
  } else {
    quickPress = true;
    setTimeout(() => { quickPress = false; }, QUICK_MS);
    mcp = true;
    post("activateMCP");
  }
});
window.addEventListener("mouseup", (e) => {
  if (e.button !== 1 || !visible() || suspended) return;
  if (mcp && !quickPress) { mcp = false; post("deactivateMCP"); } // long hold released
});
window.addEventListener("auxclick", (e) => { if (e.button === 1) e.preventDefault(); });

window.addEventListener("message", (ev) => {
  const m = ev.data || {};
  if (m.action === "open") {
    state.pedType = m.pedType;
    state.categories = m.categories || [];
    state.activeCat = null;
    state.catIndex = -1;
    state.itemIndex = -1;
    state.selected = null;
    state.mandatory = false;
    state.twoAxis = false;
    state.variants = [];
    state.variantKey = null;
    state.variantByCat = {};
    closeAxis();
    dragging = false; lastDragIdx = -1;
    suspended = false;
    setEquipped(m.equipped);
    state.occupied = new Set(m.cats || []);
    $("ped").textContent = m.pedType || "—";
    renderCategories();
    renderOutfits(m.outfits);
    $("items").innerHTML = `<div class="empty">pick a category</div>`;
    $("count").textContent = "";
    $("tintbar").classList.add("hidden");
    $("axisbar").classList.add("hidden");
    $("remove").classList.remove("hidden");
    mcp = false;
    $("app").classList.remove("hidden");
  } else if (m.action === "close") {
    mcp = false;
    $("app").classList.add("hidden");
  } else if (m.action === "suspend") {
    suspended = true;           // a higher-priority mode owns input now
    dragging = false; lastDragIdx = -1;
    closeAxis();
  } else if (m.action === "resume") {
    suspended = false;          // we're the active editor again
  } else if (m.action === "mcp") {
    mcp = !!m.active;            // sync with the client (covers game-side exits)
  } else if (m.action === "state") {
    setEquipped(m.equipped);
    refreshHighlights();
  }
});
