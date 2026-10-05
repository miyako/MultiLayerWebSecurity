

const AUTH_REQUIRED = Symbol('AUTH_REQUIRED');

const SECTIONS = [
  { id: 'rateLimiting', title: 'Rate Limiting' },
  { id: 'validation',   title: 'Request Validation' },
  { id: 'monitoring',   title: 'CPU Monitoring' },
  { id: 'panic',        title: 'Panic Mode' },
  { id: 'honeypot',     title: 'Honeypot' },
  { id: 'alerts',       title: 'Alerting' },
  { id: 'logging',      title: 'Request Logging' },
  { id: 'waf',          title: 'WAF' },
  { id: 'security',     title: 'Security' },
  { id: 'defenses',     title: 'Defense Switches' },
  { id: 'server',       title: 'Server' },
  { id: 'ui',           title: 'Dashboard UI' },
];

const CONFIG_SCHEMA = [

  { path:'rateLimiting.maxRequests',          label:'Max Requests',         type:'posInt',  unit:'req',   tooltip:'Per-IP request budget within the rolling window.' },
  { path:'rateLimiting.windowSeconds',        label:'Window',               type:'posInt',  unit:'sec',   tooltip:'Length of the rolling rate-limit window.' },
  { path:'rateLimiting.blockDurationSeconds', label:'Block Duration',       type:'posInt',  unit:'sec',   tooltip:'How long a blocked IP stays on the blocklist.' },
  { path:'rateLimiting.burstThreshold',       label:'Burst Threshold',      type:'posInt',  unit:'req',   tooltip:'Max requests in burstWindowSeconds before instant block.' },
  { path:'rateLimiting.burstWindowSeconds',   label:'Burst Window',         type:'posInt',  unit:'sec',   tooltip:'Time window for burst detection.' },
  { path:'rateLimiting.permanentBlockStrikes',label:'Permanent Strikes',    type:'posInt',  unit:'',      tooltip:'Strike count that escalates to permanent block. Used as divisor — must be > 0.' },
  { path:'rateLimiting.globalMaxPerMinute',   label:'Global Cap / min',     type:'posInt',  unit:'req',   tooltip:'Aggregate request cap across all IPs (anti-distributed-flood).' },

  { path:'validation.maxBodySizeMB',          label:'Max Body Size',        type:'posInt',  unit:'MB',    tooltip:'Reject POST/PUT bodies larger than this.' },
  { path:'validation.maxURLLength',           label:'Max URL Length',       type:'posInt',  unit:'bytes', tooltip:'Reject URLs longer than this.' },
  { path:'validation.maxHeaderBytes',         label:'Max Header Bytes',     type:'posInt',  unit:'bytes', tooltip:'Reject requests with header section larger than this.' },
  { path:'validation.requireUserAgent',       label:'Require User-Agent',   type:'bool',                  tooltip:'Reject requests with empty/missing User-Agent header.' },

  { path:'monitoring.cpuSampleIntervalMs',    label:'CPU Sample Interval',  type:'posInt',  unit:'ms',    tooltip:'How often the CPU monitor worker samples process CPU.' },
  { path:'monitoring.cpuPanicEnabled',        label:'CPU Panic Enabled',    type:'bool',                  tooltip:'Auto-trigger panic mode when CPU stays above threshold.' },
  { path:'monitoring.cpuPanicTriggerAbove',   label:'CPU Trigger Above',    type:'percent', unit:'%',     tooltip:'Panic triggers when CPU stays above this for cpuPanicMinDurationSec.' },
  { path:'monitoring.cpuPanicLiftBelow',      label:'CPU Lift Below',       type:'percent', unit:'%',     tooltip:'Panic lifts when CPU drops below this. Must be < Trigger Above.' },
  { path:'monitoring.cpuPanicMinDurationSec', label:'CPU Trigger Hold',     type:'nonNegInt', unit:'sec', tooltip:'CPU must stay above trigger this long before panic starts (0 = immediate).' },

  { path:'panic.autoTriggerEnabled',          label:'Auto-Trigger Panic',   type:'bool',                  tooltip:'Allow traffic-based auto panic.' },
  { path:'panic.autoTriggerMultiplier',       label:'Trigger Multiplier',   type:'posInt',  unit:'×',     tooltip:'Auto-panic when current RPM exceeds (baseline × this).' },
  { path:'panic.durationSeconds',             label:'Panic Duration',       type:'posInt',  unit:'sec',   tooltip:'How long panic mode stays active before auto-lifting.' },
  { path:'panic.samplingMultiplier',          label:'Sampling Multiplier',  type:'posInt',  unit:'×',     tooltip:'During panic, accept 1/(samplingMultiplier) of requests.' },
  { path:'panic.samplingRate',                label:'Panic Sampling Rate',  type:'percent', unit:'%',     tooltip:'Percentage of requests admitted during panic (1–100).' },

  { path:'honeypot.enabled',                  label:'Honeypot Enabled',     type:'bool',                  tooltip:'Block IPs that hit honeypot paths.' },
  { path:'honeypot.banDurationSec',           label:'Honeypot Ban',         type:'posInt',  unit:'sec',   tooltip:'How long honeypot-tripping IPs stay banned (default 86400 = 24h).' },

  { path:'alerts.enabled',                    label:'Alerts Enabled',       type:'bool',                  tooltip:'Master switch for AlertManager.' },
  { path:'alerts.rateLimitThreshold',         label:'RL Alert @',           type:'posInt',  unit:'hits',  tooltip:'Fire alert after N rate-limit rejections in a window.' },
  { path:'alerts.blocklistThreshold',         label:'Blocklist Alert @',    type:'posInt',  unit:'IPs',   tooltip:'Fire alert when blocklist grows by this.' },
  { path:'alerts.trafficSpikeMultiplier',     label:'Spike Multiplier',     type:'posInt',  unit:'×',     tooltip:'Traffic-spike alert when RPM exceeds (baseline × this).' },
  { path:'alerts.wafRejectionThreshold',      label:'WAF Alert @',          type:'posInt',  unit:'hits',  tooltip:'Alert after N WAF rejections.' },
  { path:'alerts.globalRateHitThreshold',     label:'Global Rate Alert @',  type:'posInt',  unit:'hits',  tooltip:'Alert after N global-cap rejections.' },

  { path:'logging.enabled',                   label:'Logging Enabled',      type:'bool',                  tooltip:'Master switch for RequestLogger.' },
  { path:'logging.maxMemoryEntries',          label:'In-Memory Buffer',     type:'posInt',  unit:'rows',  tooltip:'Ring-buffer size before sampling kicks in.' },
  { path:'logging.flushIntervalSeconds',      label:'Flush Interval',       type:'posInt',  unit:'sec',   tooltip:'How often to flush logs to disk.' },
  { path:'logging.sampledLoggingThreshold',   label:'Sample @ RPM',         type:'posInt',  unit:'rpm',   tooltip:'Above this rate, only log a sampled percentage.' },
  { path:'logging.samplingRate',              label:'Sampling Rate',        type:'percent', unit:'%',     tooltip:'Percentage of requests logged when sampling (1–100).' },

  { path:'waf.maxDecodePasses',               label:'Max Decode Passes',    type:'posInt',  unit:'',      tooltip:'URL-decode this many times to defeat nested encoding.' },
  { path:'waf.maxPathDepth',                  label:'Max Path Depth',       type:'posInt',  unit:'',      tooltip:'Reject paths with more than N segments.' },
  { path:'waf.strictASCII',                   label:'Strict ASCII',         type:'bool',                  tooltip:'Reject non-ASCII URL bytes.' },

  { path:'security.rejectUnknownURLs',        label:'Reject Unknown URLs',  type:'bool',                  tooltip:'404 anything not in the route table.' },
  { path:'security.unknownURLStrikes',        label:'Strike Unknown URLs',  type:'bool',                  tooltip:'Count unknown-URL hits as strikes (escalates to block).' },

  { path:'defenses.master',                   label:'Master Switch',        type:'bool',                  tooltip:'Global kill-switch — when OFF, every defense layer is bypassed.' },
  { path:'defenses.shield',                   label:'IP Interceptor',       type:'bool',                  tooltip:'Threat detection & IP blocklist enforcement.' },
  { path:'defenses.rateLimit',                label:'Rate Limit',           type:'bool',                  tooltip:'Token-bucket rate limiting per IP.' },
  { path:'defenses.handler',                  label:'Handler Defense',      type:'bool',                  tooltip:'HTTP request outer-perimeter filtering.' },
  { path:'defenses.waf',                      label:'WAF',                  type:'bool',                  tooltip:'Recon/traversal request inspection.' },
  { path:'defenses.honeypot',                 label:'Honeypot',             type:'bool',                  tooltip:'Honeypot path detection layer.' },

  { path:'server.port',                       label:'HTTP Port',            type:'posInt',  unit:'',      tooltip:'TCP port — restart required to change.', restart:true, readonly:true },
  { path:'server.maxConcurrentRequests',      label:'Max Concurrent',       type:'posInt',  unit:'req',   tooltip:'Cap on in-flight requests.' },
  { path:'server.sessionTimeoutMinutes',      label:'Session Timeout',      type:'posInt',  unit:'min',   tooltip:'Idle session expiration.' },

  { path:'ui.refreshIntervalSeconds',         label:'Dashboard Refresh',    type:'posInt',  unit:'sec',   tooltip:'Polling cadence of the main dashboard.' },
];

const TYPE_VALIDATORS = {
  posInt:    v => (Number.isInteger(+v) && +v > 0)                ? null : 'Must be a whole number greater than 0',
  nonNegInt: v => (Number.isInteger(+v) && +v >= 0)               ? null : 'Must be a whole number ≥ 0',
  percent:   v => (Number.isInteger(+v) && +v >= 1 && +v <= 100)  ? null : 'Must be a whole number between 1 and 100',
  bool:      v => (typeof v === 'boolean')                         ? null : 'Must be true or false',
};


let originalConfig = null;
let currentConfig  = null;
const fieldErrors  = new Map();


function getByPath(obj, path) {
  return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
}

function setByPath(obj, path, value) {
  const keys = path.split('.');
  let o = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    if (o[keys[i]] == null) o[keys[i]] = {};
    o = o[keys[i]];
  }
  o[keys[keys.length - 1]] = value;
}

function deepClone(v) { return JSON.parse(JSON.stringify(v)); }

function isDirty() { return JSON.stringify(originalConfig) !== JSON.stringify(currentConfig); }

function fieldId(path) { return 'f-' + path.replace(/\./g, '-'); }

function escapeHTML(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}


async function api(url, method = 'GET', body = null) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
    credentials: 'same-origin',
  };
  if (body !== null) opts.body = JSON.stringify(body);
  try {
    const r = await fetch(url, opts);
    if (r.status === 401 || r.status === 403) return AUTH_REQUIRED;
    const json = await r.json().catch(() => null);
    return { ok: r.ok, status: r.status, body: json };
  } catch (e) {
    return null;
  }
}


function renderForm() {
  const root = document.getElementById('eq-form-root');
  root.innerHTML = '';
  fieldErrors.clear();

  SECTIONS.forEach(section => {
    const fields = CONFIG_SCHEMA.filter(f => f.path.startsWith(section.id + '.'));
    if (fields.length === 0) return;

    const card = document.createElement('details');
    card.className = 'eq-section-card';
    card.open = true;

    const summary = document.createElement('summary');
    summary.textContent = section.title;
    card.appendChild(summary);

    fields.forEach(field => {
      card.appendChild(renderRow(field));
    });

    root.appendChild(card);
  });
}

function renderRow(field) {
  const row = document.createElement('div');
  row.className = 'eq-row';
  row.dataset.path = field.path;

  const id = fieldId(field.path);
  const value = getByPath(currentConfig, field.path);


  const labelEl = document.createElement('label');
  labelEl.className = 'eq-label';
  labelEl.setAttribute('for', id);
  labelEl.innerHTML =
    escapeHTML(field.label) +
    ' <span class="eq-tip" title="' + escapeHTML(field.tooltip || '') + '">ⓘ</span>' +
    (field.restart ? ' <span class="eq-restart-pill">RESTART</span>' : '');
  row.appendChild(labelEl);


  if (field.type === 'bool') {
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.id = id;
    input.className = 'eq-checkbox';
    input.dataset.path = field.path;
    input.dataset.type = field.type;
    input.checked = !!value;
    if (field.readonly) {
      input.readOnly = true;
      input.disabled = true;
      input.classList.add('readonly');
    }
    input.addEventListener('change', onFieldChange);
    row.appendChild(input);


    const unitSpacer = document.createElement('span');
    unitSpacer.className = 'eq-unit';
    unitSpacer.textContent = '';
    row.appendChild(unitSpacer);
  } else {
    const input = document.createElement('input');
    input.type = 'number';
    input.id = id;
    input.className = 'eq-input';
    input.dataset.path = field.path;
    input.dataset.type = field.type;
    input.step = '1';
    if (field.type === 'posInt')     input.min = '1';
    if (field.type === 'nonNegInt')  input.min = '0';
    if (field.type === 'percent')  { input.min = '1'; input.max = '100'; }
    input.value = (value == null) ? '' : String(value);

    if (field.readonly) {
      input.readOnly = true;
      input.disabled = true;
      input.classList.add('readonly');
    }
    input.addEventListener('input', onFieldChange);
    row.appendChild(input);

    const unitEl = document.createElement('span');
    unitEl.className = 'eq-unit';
    unitEl.textContent = field.unit || '';
    row.appendChild(unitEl);
  }


  const errEl = document.createElement('span');
  errEl.className = 'eq-error hidden';
  row.appendChild(errEl);

  return row;
}


function onFieldChange(e) {
  const input = e.currentTarget;
  const path  = input.dataset.path;
  const type  = input.dataset.type;

  let value;
  if (type === 'bool') {
    value = !!input.checked;
  } else {

    value = input.value === '' ? NaN : +input.value;
  }

  setByPath(currentConfig, path, value);


  const err = TYPE_VALIDATORS[type] ? TYPE_VALIDATORS[type](value) : null;
  paintFieldError(path, err);


  applyCrossFieldChecks();


  updateDirtyState();
}

function paintFieldError(path, message) {
  const row = document.querySelector(`.eq-row[data-path="${cssEscape(path)}"]`);
  if (!row) return;
  const input = row.querySelector('input');
  const errEl = row.querySelector('.eq-error');

  if (message) {
    fieldErrors.set(path, message);
    if (input) input.classList.add('invalid');
    if (errEl) {
      errEl.textContent = message;
      errEl.classList.remove('hidden');
    }
  } else {
    fieldErrors.delete(path);
    if (input) input.classList.remove('invalid');
    if (errEl) {
      errEl.textContent = '';
      errEl.classList.add('hidden');
    }
  }
}

function cssEscape(s) {

  return s.replace(/\./g, '\\.');
}

function applyCrossFieldChecks() {
  const trigger = +getByPath(currentConfig, 'monitoring.cpuPanicTriggerAbove');
  const lift    = +getByPath(currentConfig, 'monitoring.cpuPanicLiftBelow');


  const triggerValid = Number.isInteger(trigger) && trigger >= 1 && trigger <= 100;
  const liftValid    = Number.isInteger(lift)    && lift    >= 1 && lift    <= 100;

  if (triggerValid && liftValid && lift >= trigger) {
    paintFieldError('monitoring.cpuPanicLiftBelow', 'Must be less than CPU Trigger Above');
  } else {

    const liftErr = fieldErrors.get('monitoring.cpuPanicLiftBelow');
    if (liftErr === 'Must be less than CPU Trigger Above') {
      paintFieldError('monitoring.cpuPanicLiftBelow', null);
    }

    if (liftValid) {

      const stale = fieldErrors.get('monitoring.cpuPanicLiftBelow');
      if (stale === 'Must be less than CPU Trigger Above') {
        paintFieldError('monitoring.cpuPanicLiftBelow', null);
      }
    }
  }
}

function updateDirtyState() {
  const dirty   = isDirty();
  const hasErrs = fieldErrors.size > 0;
  const badge   = document.getElementById('dirty-badge');
  const saveBtn = document.getElementById('btn-save');

  badge.classList.toggle('hidden', !dirty);
  saveBtn.disabled = !dirty || hasErrs;
}

function revalidateAll() {

  fieldErrors.clear();
  document.querySelectorAll('.eq-row').forEach(row => {
    row.querySelector('input')?.classList.remove('invalid');
    const err = row.querySelector('.eq-error');
    if (err) { err.textContent = ''; err.classList.add('hidden'); }
  });

  CONFIG_SCHEMA.forEach(field => {
    if (field.readonly) return;
    const value = getByPath(currentConfig, field.path);
    const validator = TYPE_VALIDATORS[field.type];
    if (!validator) return;
    const err = validator(value);
    if (err) paintFieldError(field.path, err);
  });

  applyCrossFieldChecks();
  return fieldErrors.size === 0;
}

function paintServerErrors(fields) {
  if (!Array.isArray(fields)) return;
  fields.forEach(f => {
    if (f && f.path && f.message) {
      paintFieldError(f.path, f.message);
    }
  });
  updateDirtyState();
}


let bannerTimer = null;
function showBanner(msg, kind) {
  const el = document.getElementById('eq-error-banner');
  el.textContent = msg;
  el.classList.remove('hidden');
  if (kind === 'success') el.classList.add('success');
  else el.classList.remove('success');

  if (bannerTimer) clearTimeout(bannerTimer);
  if (kind === 'success') {
    bannerTimer = setTimeout(() => {
      el.classList.add('hidden');
    }, 4000);
  }
}


function bindActions() {
  document.getElementById('btn-save').addEventListener('click', onSave);
  document.getElementById('btn-reset-defaults').addEventListener('click', onResetDefaults);
}

async function onSave() {
  if (!revalidateAll()) {
    showBanner('Fix highlighted fields before saving.', 'error');
    updateDirtyState();
    return;
  }
  const res = await api('/api/dashboard/config', 'POST', currentConfig);
  if (res === AUTH_REQUIRED) { window.location.href = '/sentinel.html'; return; }
  if (res === null) { showBanner('Network error — try again.', 'error'); return; }
  if (!res.ok) {
    const fields = (res.body && res.body.fields) || [];
    paintServerErrors(fields);
    showBanner('Server rejected configuration. See highlighted fields.', 'error');
    return;
  }
  originalConfig = deepClone(currentConfig);
  document.getElementById('last-saved').textContent = 'Saved ' + new Date().toLocaleTimeString();
  document.getElementById('dirty-badge').classList.add('hidden');
  document.getElementById('btn-save').disabled = true;
  showBanner('Configuration saved. Changes are live — no restart needed.', 'success');
}

async function onResetDefaults() {
  if (!confirm('Reset ALL settings to factory defaults? Auth secrets and HTTP port are preserved.')) return;
  const res = await api('/api/dashboard/config/reset', 'POST');
  if (res === AUTH_REQUIRED) { window.location.href = '/sentinel.html'; return; }
  if (res === null) { showBanner('Network error — try again.', 'error'); return; }
  if (!res.ok) { showBanner('Reset failed.', 'error'); return; }
  originalConfig = (res.body && res.body.config) ? res.body.config : res.body;
  currentConfig  = deepClone(originalConfig);
  renderForm();
  updateDirtyState();
  showBanner('Reset to defaults.', 'success');
}


async function boot() {
  const res = await api('/api/dashboard/config');
  if (res === AUTH_REQUIRED || res === null) {
    document.getElementById('eq-redirect-overlay').classList.remove('hidden');
    setTimeout(() => { window.location.href = '/sentinel.html'; }, 1200);
    return;
  }
  if (!res.ok || !res.body) {
    document.getElementById('eq-redirect-overlay').textContent =
      'Failed to load configuration. Redirecting to dashboard...';
    document.getElementById('eq-redirect-overlay').classList.remove('hidden');
    setTimeout(() => { window.location.href = '/sentinel.html'; }, 1500);
    return;
  }
  originalConfig = res.body;
  currentConfig  = deepClone(originalConfig);
  renderForm();
  bindActions();
  document.getElementById('eq-shell').classList.remove('hidden');
}

document.addEventListener('DOMContentLoaded', boot);
