#!/usr/bin/env bash
# desc: Generate a static HTML dashboard from show/todo/venue data
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh" && load_config

SHOWS_DIR="${REPO_ROOT}/$(cfg '.entities.shows.dir')"
RUNS_DIR="${REPO_ROOT}/$(cfg '.entities.runs.dir')"
INDEX="${REPO_ROOT}/$(cfg '.entities.shows.index_path')"
PEOPLE="${REPO_ROOT}/$(cfg '.registries.people.path')"
VENUES="${REPO_ROOT}/$(cfg '.registries.venues.path')"
TODOS="${REPO_ROOT}/$(cfg '.registries.todos.path')"
OUTPUT="${REPO_ROOT}/dashboard.html"

# ── Preflight checks ───────────────────────────────────────────────
for f in "$PEOPLE" "$VENUES" "$TODOS"; do
  if [ ! -f "$f" ]; then
    echo "Missing ${f}" >&2
    exit 1
  fi
done
if [ ! -f "$INDEX" ]; then
  echo "Missing ${INDEX} — run ./bandlab-cli build-index first" >&2
  exit 1
fi

echo "Building dashboard data..."

# ── Build run name lookup ───────────────────────────────────────────
# Maps run keys to short display names (strip "spring-2026-" prefix)
run_names="{}"
for run_json in "${RUNS_DIR}"/*/run.json; do
  [ -f "$run_json" ] || continue
  run_id=$(jq -r '.id' "$run_json")
  # Strip tour prefix to get short name, e.g. "spring-2026-southeast" → "southeast"
  short="${run_id##*-2026-}"
  run_names=$(echo "$run_names" | jq --arg k "$run_id" --arg v "$short" '. + {($k): $v}')
done

# ── Check advancing status for each show ────────────────────────────
# Produces a JSON object: { "show-id": { "has_thread": bool, "has_confirmed": bool, ... } }
adv_status="{}"
file_status="{}"

while IFS= read -r show_id; do
  dir="${SHOWS_DIR}/${show_id}"
  has_thread=false
  has_confirmed=false
  has_contract_pdf=false
  has_contract_summary=false
  has_tech_pack=false

  [ -f "${dir}/advancing/thread.md" ] && has_thread=true
  [ -f "${dir}/advancing/confirmed.md" ] && has_confirmed=true
  [ -f "${dir}/tech-pack.md" ] && has_tech_pack=true
  [ -f "${dir}/source/summary.md" ] && has_contract_summary=true

  # Check for any PDF in source/
  if compgen -G "${dir}/source/"*.pdf > /dev/null 2>&1; then
    has_contract_pdf=true
  fi

  adv_status=$(echo "$adv_status" | jq \
    --arg id "$show_id" \
    --argjson thread "$has_thread" \
    --argjson confirmed "$has_confirmed" \
    '. + {($id): {"has_thread": $thread, "has_confirmed": $confirmed}}')

  file_status=$(echo "$file_status" | jq \
    --arg id "$show_id" \
    --argjson thread "$has_thread" \
    --argjson confirmed "$has_confirmed" \
    --argjson cpdf "$has_contract_pdf" \
    --argjson csum "$has_contract_summary" \
    --argjson tech "$has_tech_pack" \
    '. + {($id): {"thread_md": $thread, "confirmed_md": $confirmed, "contract_pdf": $cpdf, "contract_summary": $csum, "tech_pack": $tech}}')
done < <(jq -r 'keys[]' "$INDEX")

# ── Build the combined data blob ────────────────────────────────────
# This JSON object gets embedded in the HTML as `const DATA = ...`
DATA=$(jq -n \
  --slurpfile shows "$INDEX" \
  --slurpfile people "$PEOPLE" \
  --slurpfile venues "$VENUES" \
  --slurpfile todos "$TODOS" \
  --argjson run_names "$run_names" \
  --argjson adv_status "$adv_status" \
  --argjson file_status "$file_status" \
  '{
    shows: $shows[0],
    people: $people[0],
    venues: $venues[0],
    todos: ($todos[0] | map(del(.history))),
    run_names: $run_names,
    adv_status: $adv_status,
    file_status: $file_status
  }')

echo "Generating HTML..."

# ── Write the HTML file ─────────────────────────────────────────────
cat > "$OUTPUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dirtclaw Dashboard</title>
<style>
  :root {
    --bg: #0d1117;
    --surface: #161b22;
    --border: #30363d;
    --text: #e6edf3;
    --text-muted: #8b949e;
    --accent: #58a6ff;
    --green: #3fb950;
    --yellow: #d29922;
    --red: #f85149;
    --blue: #58a6ff;
    --gray: #6e7681;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    font-size: 13px;
    line-height: 1.5;
  }
  .header {
    padding: 16px 24px;
    border-bottom: 1px solid var(--border);
    display: flex;
    align-items: center;
    gap: 24px;
  }
  .header h1 {
    font-size: 18px;
    font-weight: 600;
    color: var(--text);
  }
  .header .stats {
    color: var(--text-muted);
    font-size: 12px;
  }
  .tabs {
    display: flex;
    gap: 0;
    border-bottom: 1px solid var(--border);
    padding: 0 24px;
  }
  .tab {
    padding: 10px 16px;
    cursor: pointer;
    color: var(--text-muted);
    border-bottom: 2px solid transparent;
    font-size: 13px;
    user-select: none;
  }
  .tab:hover { color: var(--text); }
  .tab.active {
    color: var(--text);
    border-bottom-color: var(--accent);
  }
  .controls {
    padding: 12px 24px;
    display: flex;
    gap: 12px;
    align-items: center;
    flex-wrap: wrap;
  }
  .controls select, .controls input {
    background: var(--surface);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 5px 10px;
    font-size: 12px;
  }
  .controls input { width: 200px; }
  .controls label {
    color: var(--text-muted);
    font-size: 12px;
    margin-right: 4px;
  }
  .table-wrap {
    overflow-x: auto;
    padding: 0 24px 24px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    white-space: nowrap;
  }
  th {
    text-align: left;
    padding: 8px 12px;
    border-bottom: 1px solid var(--border);
    color: var(--text-muted);
    font-weight: 600;
    font-size: 12px;
    cursor: pointer;
    user-select: none;
    position: sticky;
    top: 0;
    background: var(--bg);
  }
  th:hover { color: var(--text); }
  th .sort-arrow { margin-left: 4px; font-size: 10px; }
  td {
    padding: 6px 12px;
    border-bottom: 1px solid var(--border);
    vertical-align: top;
  }
  tr:hover td { background: var(--surface); }
  .badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.3px;
  }
  .badge-confirmed { background: #23382e; color: var(--green); }
  .badge-offered { background: #3d2e00; color: var(--yellow); }
  .badge-potential { background: #272b33; color: var(--gray); }
  .badge-advanced { background: #1a2a3e; color: var(--blue); }
  .badge-cancelled { background: #3d1a1a; color: var(--red); }
  .adv-badge {
    cursor: pointer;
    transition: opacity 0.15s;
  }
  .adv-badge:hover { opacity: 0.8; }
  .badge-adv-not-yet { background: #272b33; color: var(--gray); }
  .badge-adv-started { background: #3d2e00; color: var(--yellow); }
  .badge-adv-confirmed { background: #23382e; color: var(--green); }
  .money { text-align: right; font-variant-numeric: tabular-nums; }
  .number { text-align: right; font-variant-numeric: tabular-nums; }

  /* Detail pane */
  .detail-overlay {
    display: none;
    position: fixed;
    top: 0; right: 0;
    width: 520px;
    height: 100vh;
    background: var(--surface);
    border-left: 1px solid var(--border);
    overflow-y: auto;
    z-index: 100;
    box-shadow: -4px 0 24px rgba(0,0,0,0.5);
  }
  .detail-overlay.open { display: block; }
  .detail-header {
    padding: 16px 20px;
    border-bottom: 1px solid var(--border);
    display: flex;
    justify-content: space-between;
    align-items: center;
    position: sticky;
    top: 0;
    background: var(--surface);
    z-index: 1;
  }
  .detail-header h2 { font-size: 15px; }
  .detail-close {
    cursor: pointer;
    color: var(--text-muted);
    font-size: 20px;
    border: none;
    background: none;
    padding: 4px 8px;
  }
  .detail-close:hover { color: var(--text); }
  .detail-body { padding: 20px; }
  .detail-section {
    margin-bottom: 20px;
  }
  .detail-section h3 {
    font-size: 12px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 8px;
    padding-bottom: 4px;
    border-bottom: 1px solid var(--border);
  }
  .detail-grid {
    display: grid;
    grid-template-columns: 120px 1fr;
    gap: 4px 12px;
    font-size: 12px;
  }
  .detail-grid dt { color: var(--text-muted); }
  .detail-grid dd { color: var(--text); }
  .file-check {
    font-size: 12px;
    list-style: none;
  }
  .file-check li {
    padding: 3px 0;
  }
  .file-check .exists { color: var(--green); }
  .file-check .missing { color: var(--gray); }
  .contact-row {
    display: flex;
    gap: 12px;
    padding: 4px 0;
    font-size: 12px;
    align-items: baseline;
  }
  .contact-pri {
    color: var(--text-muted);
    min-width: 20px;
  }
  .contact-name { color: var(--text); font-weight: 500; }
  .contact-email { color: var(--accent); }
  .contact-phone { color: var(--text-muted); }
  .todo-row {
    padding: 6px 0;
    border-bottom: 1px solid var(--border);
    font-size: 12px;
  }
  .todo-row:last-child { border-bottom: none; }
  .todo-id { color: var(--text-muted); margin-right: 8px; }

  /* Todo tab status badges */
  .badge-open { background: #1a2a3e; color: var(--blue); }
  .badge-in-progress { background: #3d2e00; color: var(--yellow); }
  .badge-blocked { background: #3d1a1a; color: var(--red); }
  .badge-done { background: #23382e; color: var(--green); }

  .tab-content { display: none; }
  .tab-content.active { display: block; }

  @media (max-width: 768px) {
    .detail-overlay { width: 100%; }
  }
</style>
</head>
<body>

<div class="header">
  <h1>Dirtclaw</h1>
  <span class="stats" id="stats"></span>
</div>

<div class="tabs">
  <div class="tab active" data-tab="shows">Shows</div>
  <div class="tab" data-tab="todos">Todos</div>
</div>

<!-- Shows tab -->
<div class="tab-content active" id="tab-shows">
  <div class="controls">
    <label>Status:</label>
    <select id="filter-status">
      <option value="">All</option>
      <option value="confirmed">Confirmed</option>
      <option value="offered">Offered</option>
      <option value="potential">Potential</option>
      <option value="advanced">Advanced</option>
      <option value="cancelled">Cancelled</option>
    </select>
    <label>Run:</label>
    <select id="filter-run"></select>
    <label>Search:</label>
    <input type="text" id="filter-search" placeholder="city, venue, promoter...">
  </div>
  <div class="table-wrap">
    <table id="shows-table">
      <thead>
        <tr>
          <th data-col="date">Date <span class="sort-arrow"></span></th>
          <th data-col="day">Day</th>
          <th data-col="city">City <span class="sort-arrow"></span></th>
          <th data-col="venue">Venue <span class="sort-arrow"></span></th>
          <th data-col="run">Run <span class="sort-arrow"></span></th>
          <th data-col="status">Status <span class="sort-arrow"></span></th>
          <th data-col="guarantee" class="money">Guarantee <span class="sort-arrow"></span></th>
          <th data-col="wp" class="money">WP <span class="sort-arrow"></span></th>
          <th data-col="sell_cap" class="number">Sell Cap <span class="sort-arrow"></span></th>
          <th data-col="scaling">Scaling</th>
          <th data-col="support">Support</th>
          <th data-col="ages">Ages</th>
          <th data-col="advancing">Advancing</th>
          <th data-col="promoter">Promoter <span class="sort-arrow"></span></th>
        </tr>
      </thead>
      <tbody id="shows-body"></tbody>
    </table>
  </div>
</div>

<!-- Todos tab -->
<div class="tab-content" id="tab-todos">
  <div class="controls">
    <label>Status:</label>
    <select id="filter-todo-status">
      <option value="">All</option>
      <option value="open">Open</option>
      <option value="in-progress">In Progress</option>
      <option value="blocked">Blocked</option>
      <option value="done">Done</option>
    </select>
    <label>Domain:</label>
    <select id="filter-todo-domain"></select>
    <label>Search:</label>
    <input type="text" id="filter-todo-search" placeholder="search tasks...">
  </div>
  <div class="table-wrap">
    <table id="todos-table">
      <thead>
        <tr>
          <th data-col="id">ID <span class="sort-arrow"></span></th>
          <th data-col="task">Task <span class="sort-arrow"></span></th>
          <th data-col="domain">Domain <span class="sort-arrow"></span></th>
          <th data-col="show">Show <span class="sort-arrow"></span></th>
          <th data-col="owners">Owners</th>
          <th data-col="status">Status <span class="sort-arrow"></span></th>
          <th data-col="due">Due <span class="sort-arrow"></span></th>
          <th data-col="updated">Updated <span class="sort-arrow"></span></th>
        </tr>
      </thead>
      <tbody id="todos-body"></tbody>
    </table>
  </div>
</div>

<!-- Detail pane -->
<div class="detail-overlay" id="detail-pane">
  <div class="detail-header">
    <h2 id="detail-title"></h2>
    <button class="detail-close" id="detail-close">&times;</button>
  </div>
  <div class="detail-body" id="detail-body"></div>
</div>

<script>
HTMLEOF

# Inject the data blob between the script tags
echo "const DATA = ${DATA};" >> "$OUTPUT"

cat >> "$OUTPUT" << 'JSEOF'

// ── Helpers ──────────────────────────────────────────────────────────
const DAYS = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

function dayOfWeek(dateStr) {
  const d = new Date(dateStr + 'T12:00:00');
  return DAYS[d.getUTCDay()];
}

function fmtMoney(v) {
  if (v == null) return '—';
  return '$' + Number(v).toLocaleString();
}

function personName(key) {
  const p = DATA.people[key];
  return p ? p.name : key || '—';
}

function venueName(key) {
  const v = DATA.venues[key];
  return v ? v.name : key || '—';
}

function venueCity(key) {
  const v = DATA.venues[key];
  return v ? v.city : '';
}

function advStatus(showId) {
  const a = DATA.adv_status[showId];
  if (!a) return 'NOT YET';
  if (a.has_confirmed) return 'CONFIRMED';
  if (a.has_thread) return 'STARTED';
  return 'NOT YET';
}

function advBadgeClass(status) {
  if (status === 'CONFIRMED') return 'badge-adv-confirmed';
  if (status === 'STARTED') return 'badge-adv-started';
  return 'badge-adv-not-yet';
}

function statusBadgeClass(status) {
  return 'badge-' + (status || 'potential');
}

function runName(key) {
  if (!key) return 'one-off';
  return DATA.run_names[key] || key;
}

function escHtml(s) {
  if (!s) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── Build show rows ─────────────────────────────────────────────────
const showEntries = Object.entries(DATA.shows)
  .map(([id, s]) => ({
    id,
    date: s.date,
    day: dayOfWeek(s.date),
    city: venueCity(s.venue?.id),
    venue: venueName(s.venue?.id),
    venueKey: s.venue?.id,
    run: s.run,
    runDisplay: runName(s.run),
    status: s.status,
    guarantee: s.deal?.guarantee,
    wp: s.deal?.wp,
    sell_cap: s.deal?.sell_cap,
    scaling: s.deal?.ticket_scaling || '',
    support: s.deal?.support || '',
    ages: s.deal?.ages || '',
    advancing: advStatus(id),
    promoter: personName(s.deal?.promoter),
    promoterKey: s.deal?.promoter,
    _raw: s
  }))
  .sort((a, b) => a.date.localeCompare(b.date));

// ── Stats ────────────────────────────────────────────────────────────
const confirmed = showEntries.filter(s => s.status === 'confirmed').length;
const totalGuarantee = showEntries.reduce((sum, s) => sum + (s.guarantee || 0), 0);
document.getElementById('stats').textContent =
  showEntries.length + ' shows | ' + confirmed + ' confirmed | $' + totalGuarantee.toLocaleString() + ' guaranteed';

// ── Sorting state ────────────────────────────────────────────────────
let showSort = { col: 'date', asc: true };
let todoSort = { col: 'id', asc: true };

function comparator(col, asc) {
  return (a, b) => {
    let va = a[col], vb = b[col];
    if (va == null) va = '';
    if (vb == null) vb = '';
    if (typeof va === 'number' && typeof vb === 'number') {
      return asc ? va - vb : vb - va;
    }
    va = String(va).toLowerCase();
    vb = String(vb).toLowerCase();
    if (va < vb) return asc ? -1 : 1;
    if (va > vb) return asc ? 1 : -1;
    return 0;
  };
}

// ── Render shows ─────────────────────────────────────────────────────
function renderShows() {
  const statusFilter = document.getElementById('filter-status').value;
  const runFilter = document.getElementById('filter-run').value;
  const search = document.getElementById('filter-search').value.toLowerCase();

  let rows = showEntries.filter(s => {
    if (statusFilter && s.status !== statusFilter) return false;
    if (runFilter && runName(s.run) !== runFilter) return false;
    if (search) {
      const hay = [s.city, s.venue, s.promoter, s.id, s.support, s.runDisplay].join(' ').toLowerCase();
      if (!hay.includes(search)) return false;
    }
    return true;
  });

  rows.sort(comparator(showSort.col === 'run' ? 'runDisplay' : showSort.col, showSort.asc));

  const tbody = document.getElementById('shows-body');
  tbody.innerHTML = rows.map(s => `<tr>
    <td>${escHtml(s.date)}</td>
    <td>${escHtml(s.day)}</td>
    <td>${escHtml(s.city)}</td>
    <td>${escHtml(s.venue)}</td>
    <td>${escHtml(s.runDisplay)}</td>
    <td><span class="badge ${statusBadgeClass(s.status)}">${escHtml(s.status)}</span></td>
    <td class="money">${s.guarantee ? fmtMoney(s.guarantee) : '% deal'}</td>
    <td class="money">${fmtMoney(s.wp)}</td>
    <td class="number">${s.sell_cap || '—'}</td>
    <td>${escHtml(s.scaling)}</td>
    <td>${escHtml(s.support)}</td>
    <td>${escHtml(s.ages)}</td>
    <td><span class="badge adv-badge ${advBadgeClass(s.advancing)}" data-show="${escHtml(s.id)}">${s.advancing}</span></td>
    <td>${escHtml(s.promoter)}</td>
  </tr>`).join('');

  // Update sort arrows
  document.querySelectorAll('#shows-table th').forEach(th => {
    const arrow = th.querySelector('.sort-arrow');
    if (!arrow) return;
    const col = th.dataset.col;
    arrow.textContent = col === showSort.col ? (showSort.asc ? '▲' : '▼') : '';
  });
}

// ── Render todos ─────────────────────────────────────────────────────
function renderTodos() {
  const statusFilter = document.getElementById('filter-todo-status').value;
  const domainFilter = document.getElementById('filter-todo-domain').value;
  const search = document.getElementById('filter-todo-search').value.toLowerCase();

  let rows = DATA.todos.filter(t => {
    if (statusFilter && t.status !== statusFilter) return false;
    if (domainFilter && t.domain !== domainFilter) return false;
    if (search) {
      const hay = [t.task, t.domain, t.show, t.id].join(' ').toLowerCase();
      if (!hay.includes(search)) return false;
    }
    return true;
  });

  rows.sort(comparator(todoSort.col, todoSort.asc));

  const tbody = document.getElementById('todos-body');
  const statusClass = (s) => 'badge-' + (s || 'open').replace(' ', '-');
  tbody.innerHTML = rows.map(t => `<tr>
    <td>${escHtml(t.id)}</td>
    <td style="white-space:normal;max-width:400px">${escHtml(t.task)}</td>
    <td>${escHtml(t.domain)}</td>
    <td>${escHtml(t.show || '')}</td>
    <td>${(t.owners || []).map(o => escHtml(personName(o))).join(', ') || '—'}</td>
    <td><span class="badge ${statusClass(t.status)}">${escHtml(t.status)}</span></td>
    <td>${escHtml(t.due || '—')}</td>
    <td>${escHtml(t.updated || '')}</td>
  </tr>`).join('');

  document.querySelectorAll('#todos-table th').forEach(th => {
    const arrow = th.querySelector('.sort-arrow');
    if (!arrow) return;
    const col = th.dataset.col;
    arrow.textContent = col === todoSort.col ? (todoSort.asc ? '▲' : '▼') : '';
  });
}

// ── Show detail pane ─────────────────────────────────────────────────
function openDetail(showId) {
  const s = DATA.shows[showId];
  if (!s) return;
  const v = DATA.venues[s.venue?.id] || {};
  const fs = DATA.file_status[showId] || {};
  const adv = advStatus(showId);

  // Advancing contacts: people linked to this venue with advancing role
  const venueOrg = 'venue:' + (s.venue?.id || '');
  const contacts = Object.entries(DATA.people)
    .filter(([_, p]) => p.role === 'advancing' && (p.org === venueOrg || p.org === null))
    .sort((a, b) => (a[1].advancing_priority || 99) - (b[1].advancing_priority || 99));

  // Related todos
  const todos = DATA.todos.filter(t => t.show === showId);

  let html = '';

  // Show metadata
  html += `<div class="detail-section">
    <h3>Show Info</h3>
    <dl class="detail-grid">
      <dt>Date</dt><dd>${s.date} (${dayOfWeek(s.date)})</dd>
      <dt>Venue</dt><dd>${venueName(s.venue?.id)}</dd>
      <dt>City</dt><dd>${venueCity(s.venue?.id)}${v.state ? ', ' + v.state : ''}</dd>
      <dt>Status</dt><dd><span class="badge ${statusBadgeClass(s.status)}">${s.status}</span></dd>
      <dt>Guarantee</dt><dd>${s.deal?.guarantee ? fmtMoney(s.deal.guarantee) : '% deal'}</dd>
      <dt>WP</dt><dd>${fmtMoney(s.deal?.wp)}</dd>
      <dt>Sell Cap</dt><dd>${s.deal?.sell_cap || '—'}</dd>
      <dt>Scaling</dt><dd>${s.deal?.ticket_scaling || '—'}</dd>
      <dt>Ages</dt><dd>${s.deal?.ages || '—'}</dd>
      <dt>Support</dt><dd>${s.deal?.support || '—'}</dd>
      <dt>Run</dt><dd>${runName(s.run)}</dd>
      <dt>Promoter</dt><dd>${personName(s.deal?.promoter)}</dd>
      <dt>Merch Cut</dt><dd>${s.venue?.merch_cut != null ? s.venue.merch_cut + '%' : '—'}</dd>
    </dl>
  </div>`;

  // Venue info
  if (v.name) {
    html += `<div class="detail-section">
      <h3>Venue</h3>
      <dl class="detail-grid">
        <dt>Name</dt><dd>${escHtml(v.name)}</dd>
        <dt>City</dt><dd>${escHtml(v.city)}${v.state ? ', ' + v.state : ''}</dd>
        <dt>Capacity</dt><dd>${v.capacity || '—'}</dd>
      </dl>
      ${v.notes ? '<p style="margin-top:8px;font-size:12px;color:var(--text-muted)">' + escHtml(v.notes) + '</p>' : ''}
    </div>`;
  }

  // Advancing status
  html += `<div class="detail-section">
    <h3>Advancing</h3>
    <p><span class="badge ${advBadgeClass(adv)}">${adv}</span></p>
  </div>`;

  // Advancing contacts
  if (contacts.length > 0) {
    html += `<div class="detail-section">
      <h3>Advancing Contacts</h3>`;
    contacts.forEach(([key, p]) => {
      html += `<div class="contact-row">
        <span class="contact-pri">${p.advancing_priority || '—'}</span>
        <span class="contact-name">${escHtml(p.name)}</span>
        <span class="contact-email">${escHtml(p.contact?.email || '')}</span>
        <span class="contact-phone">${escHtml(p.contact?.phone || '')}</span>
      </div>`;
    });
    html += `</div>`;
  }

  // Files checklist
  html += `<div class="detail-section">
    <h3>Files</h3>
    <ul class="file-check">
      <li class="${fs.contract_pdf ? 'exists' : 'missing'}">${fs.contract_pdf ? '✓' : '✗'} source/*.pdf</li>
      <li class="${fs.contract_summary ? 'exists' : 'missing'}">${fs.contract_summary ? '✓' : '✗'} source/summary.md</li>
      <li class="${fs.thread_md ? 'exists' : 'missing'}">${fs.thread_md ? '✓' : '✗'} advancing/thread.md</li>
      <li class="${fs.confirmed_md ? 'exists' : 'missing'}">${fs.confirmed_md ? '✓' : '✗'} advancing/confirmed.md</li>
      <li class="${fs.tech_pack ? 'exists' : 'missing'}">${fs.tech_pack ? '✓' : '✗'} tech-pack.md</li>
    </ul>
  </div>`;

  // Related todos
  if (todos.length > 0) {
    html += `<div class="detail-section">
      <h3>Related Todos</h3>`;
    todos.forEach(t => {
      html += `<div class="todo-row">
        <span class="todo-id">${escHtml(t.id)}</span>
        <span class="badge badge-${(t.status || 'open').replace(' ', '-')}">${escHtml(t.status)}</span>
        ${escHtml(t.task)}
      </div>`;
    });
    html += `</div>`;
  }

  document.getElementById('detail-title').textContent = showId;
  document.getElementById('detail-body').innerHTML = html;
  document.getElementById('detail-pane').classList.add('open');
}

// ── Populate filter dropdowns ────────────────────────────────────────
function populateFilters() {
  // Run filter
  const runs = [...new Set(showEntries.map(s => s.runDisplay))].sort();
  const runSelect = document.getElementById('filter-run');
  runSelect.innerHTML = '<option value="">All</option>' +
    runs.map(r => `<option value="${escHtml(r)}">${escHtml(r)}</option>`).join('');

  // Domain filter for todos
  const domains = [...new Set(DATA.todos.map(t => t.domain))].sort();
  const domainSelect = document.getElementById('filter-todo-domain');
  domainSelect.innerHTML = '<option value="">All</option>' +
    domains.map(d => `<option value="${escHtml(d)}">${escHtml(d)}</option>`).join('');
}

// ── Event listeners ──────────────────────────────────────────────────
// Tabs
document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(tc => tc.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById('tab-' + tab.dataset.tab).classList.add('active');
  });
});

// Show table sorting
document.querySelectorAll('#shows-table th[data-col]').forEach(th => {
  th.addEventListener('click', () => {
    const col = th.dataset.col;
    if (showSort.col === col) {
      showSort.asc = !showSort.asc;
    } else {
      showSort.col = col;
      showSort.asc = true;
    }
    renderShows();
  });
});

// Todo table sorting
document.querySelectorAll('#todos-table th[data-col]').forEach(th => {
  th.addEventListener('click', () => {
    const col = th.dataset.col;
    if (todoSort.col === col) {
      todoSort.asc = !todoSort.asc;
    } else {
      todoSort.col = col;
      todoSort.asc = true;
    }
    renderTodos();
  });
});

// Filters
document.getElementById('filter-status').addEventListener('change', renderShows);
document.getElementById('filter-run').addEventListener('change', renderShows);
document.getElementById('filter-search').addEventListener('input', renderShows);
document.getElementById('filter-todo-status').addEventListener('change', renderTodos);
document.getElementById('filter-todo-domain').addEventListener('change', renderTodos);
document.getElementById('filter-todo-search').addEventListener('input', renderTodos);

// Detail pane — click advancing badge
document.getElementById('shows-body').addEventListener('click', (e) => {
  const badge = e.target.closest('.adv-badge');
  if (badge) {
    openDetail(badge.dataset.show);
  }
});

// Close detail pane
document.getElementById('detail-close').addEventListener('click', () => {
  document.getElementById('detail-pane').classList.remove('open');
});

// Escape to close
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    document.getElementById('detail-pane').classList.remove('open');
  }
});

// ── Init ──────────────────────────────────────────────────────────────
populateFilters();
renderShows();
renderTodos();
</script>
</body>
</html>
JSEOF

echo "Dashboard written to: ${OUTPUT}"
echo "Open in browser: open ${OUTPUT}"
