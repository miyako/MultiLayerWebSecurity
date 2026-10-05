

const AUTH_REQUIRED = Symbol('AUTH_REQUIRED');

const SECTIONS = [
  { id: 'rateLimiting', title: t('config.section.rateLimiting') },
  { id: 'validation',   title: t('config.section.validation') },
  { id: 'monitoring',   title: t('config.section.monitoring') },
  { id: 'panic',        title: t('config.section.panic') },
  { id: 'honeypot',     title: t('config.section.honeypot') },
  { id: 'alerts',       title: t('config.section.alerts') },
  { id: 'logging',      title: t('config.section.logging') },
  { id: 'waf',          title: t('config.section.waf') },
  { id: 'security',     title: t('config.section.security') },
  { id: 'defenses',     title: t('config.section.defenses') },
  { id: 'server',       title: t('config.section.server') },
  { id: 'ui',           title: t('config.section.ui') },
];

const CONFIG_SCHEMA = [

  { path:'rateLimiting.maxRequests',          label:t('config.label.rateLimiting.maxRequests'),           type:'posInt',  unit:t('config.unit.req'),   tooltip:t('config.tip.rateLimiting.maxRequests') },
  { path:'rateLimiting.windowSeconds',        label:t('config.label.rateLimiting.windowSeconds'),         type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.rateLimiting.windowSeconds') },
  { path:'rateLimiting.blockDurationSeconds', label:t('config.label.rateLimiting.blockDurationSeconds'),  type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.rateLimiting.blockDurationSeconds') },
  { path:'rateLimiting.burstThreshold',       label:t('config.label.rateLimiting.burstThreshold'),        type:'posInt',  unit:t('config.unit.req'),   tooltip:t('config.tip.rateLimiting.burstThreshold') },
  { path:'rateLimiting.burstWindowSeconds',   label:t('config.label.rateLimiting.burstWindowSeconds'),    type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.rateLimiting.burstWindowSeconds') },
  { path:'rateLimiting.permanentBlockStrikes',label:t('config.label.rateLimiting.permanentBlockStrikes'), type:'posInt',  unit:'',      tooltip:t('config.tip.rateLimiting.permanentBlockStrikes') },
  { path:'rateLimiting.globalMaxPerMinute',   label:t('config.label.rateLimiting.globalMaxPerMinute'),    type:'posInt',  unit:t('config.unit.req'),   tooltip:t('config.tip.rateLimiting.globalMaxPerMinute') },

  { path:'validation.maxBodySizeMB',          label:t('config.label.validation.maxBodySizeMB'),           type:'posInt',  unit:'MB',    tooltip:t('config.tip.validation.maxBodySizeMB') },
  { path:'validation.maxURLLength',           label:t('config.label.validation.maxURLLength'),            type:'posInt',  unit:t('config.unit.bytes'), tooltip:t('config.tip.validation.maxURLLength') },
  { path:'validation.maxHeaderBytes',         label:t('config.label.validation.maxHeaderBytes'),          type:'posInt',  unit:t('config.unit.bytes'), tooltip:t('config.tip.validation.maxHeaderBytes') },
  { path:'validation.requireUserAgent',       label:t('config.label.validation.requireUserAgent'),        type:'bool',                  tooltip:t('config.tip.validation.requireUserAgent') },

  { path:'monitoring.cpuSampleIntervalMs',    label:t('config.label.monitoring.cpuSampleIntervalMs'),     type:'posInt',  unit:t('config.unit.ms'),    tooltip:t('config.tip.monitoring.cpuSampleIntervalMs') },
  { path:'monitoring.cpuPanicEnabled',        label:t('config.label.monitoring.cpuPanicEnabled'),         type:'bool',                  tooltip:t('config.tip.monitoring.cpuPanicEnabled') },
  { path:'monitoring.cpuPanicTriggerAbove',   label:t('config.label.monitoring.cpuPanicTriggerAbove'),    type:'percent', unit:'%',     tooltip:t('config.tip.monitoring.cpuPanicTriggerAbove') },
  { path:'monitoring.cpuPanicLiftBelow',      label:t('config.label.monitoring.cpuPanicLiftBelow'),       type:'percent', unit:'%',     tooltip:t('config.tip.monitoring.cpuPanicLiftBelow') },
  { path:'monitoring.cpuPanicMinDurationSec', label:t('config.label.monitoring.cpuPanicMinDurationSec'),  type:'nonNegInt', unit:t('config.unit.sec'), tooltip:t('config.tip.monitoring.cpuPanicMinDurationSec') },

  { path:'panic.autoTriggerEnabled',          label:t('config.label.panic.autoTriggerEnabled'),           type:'bool',                  tooltip:t('config.tip.panic.autoTriggerEnabled') },
  { path:'panic.autoTriggerMultiplier',       label:t('config.label.panic.autoTriggerMultiplier'),        type:'posInt',  unit:'×',     tooltip:t('config.tip.panic.autoTriggerMultiplier') },
  { path:'panic.durationSeconds',             label:t('config.label.panic.durationSeconds'),              type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.panic.durationSeconds') },
  { path:'panic.samplingMultiplier',          label:t('config.label.panic.samplingMultiplier'),           type:'posInt',  unit:'×',     tooltip:t('config.tip.panic.samplingMultiplier') },
  { path:'panic.samplingRate',                label:t('config.label.panic.samplingRate'),                 type:'percent', unit:'%',     tooltip:t('config.tip.panic.samplingRate') },

  { path:'honeypot.enabled',                  label:t('config.label.honeypot.enabled'),                   type:'bool',                  tooltip:t('config.tip.honeypot.enabled') },
  { path:'honeypot.banDurationSec',           label:t('config.label.honeypot.banDurationSec'),            type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.honeypot.banDurationSec') },

  { path:'alerts.enabled',                    label:t('config.label.alerts.enabled'),                     type:'bool',                  tooltip:t('config.tip.alerts.enabled') },
  { path:'alerts.rateLimitThreshold',         label:t('config.label.alerts.rateLimitThreshold'),          type:'posInt',  unit:t('config.unit.hits'),  tooltip:t('config.tip.alerts.rateLimitThreshold') },
  { path:'alerts.blocklistThreshold',         label:t('config.label.alerts.blocklistThreshold'),          type:'posInt',  unit:t('config.unit.ips'),   tooltip:t('config.tip.alerts.blocklistThreshold') },
  { path:'alerts.trafficSpikeMultiplier',     label:t('config.label.alerts.trafficSpikeMultiplier'),      type:'posInt',  unit:'×',     tooltip:t('config.tip.alerts.trafficSpikeMultiplier') },
  { path:'alerts.wafRejectionThreshold',      label:t('config.label.alerts.wafRejectionThreshold'),       type:'posInt',  unit:t('config.unit.hits'),  tooltip:t('config.tip.alerts.wafRejectionThreshold') },
  { path:'alerts.globalRateHitThreshold',     label:t('config.label.alerts.globalRateHitThreshold'),      type:'posInt',  unit:t('config.unit.hits'),  tooltip:t('config.tip.alerts.globalRateHitThreshold') },

  { path:'logging.enabled',                   label:t('config.label.logging.enabled'),                    type:'bool',                  tooltip:t('config.tip.logging.enabled') },
  { path:'logging.maxMemoryEntries',          label:t('config.label.logging.maxMemoryEntries'),           type:'posInt',  unit:t('config.unit.rows'),  tooltip:t('config.tip.logging.maxMemoryEntries') },
  { path:'logging.flushIntervalSeconds',      label:t('config.label.logging.flushIntervalSeconds'),       type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.logging.flushIntervalSeconds') },
  { path:'logging.sampledLoggingThreshold',   label:t('config.label.logging.sampledLoggingThreshold'),    type:'posInt',  unit:'rpm',   tooltip:t('config.tip.logging.sampledLoggingThreshold') },
  { path:'logging.samplingRate',              label:t('config.label.logging.samplingRate'),               type:'percent', unit:'%',     tooltip:t('config.tip.logging.samplingRate') },

  { path:'waf.maxDecodePasses',               label:t('config.label.waf.maxDecodePasses'),                type:'posInt',  unit:'',      tooltip:t('config.tip.waf.maxDecodePasses') },
  { path:'waf.maxPathDepth',                  label:t('config.label.waf.maxPathDepth'),                   type:'posInt',  unit:'',      tooltip:t('config.tip.waf.maxPathDepth') },
  { path:'waf.strictASCII',                   label:t('config.label.waf.strictASCII'),                    type:'bool',                  tooltip:t('config.tip.waf.strictASCII') },

  { path:'security.rejectUnknownURLs',        label:t('config.label.security.rejectUnknownURLs'),         type:'bool',                  tooltip:t('config.tip.security.rejectUnknownURLs') },
  { path:'security.unknownURLStrikes',        label:t('config.label.security.unknownURLStrikes'),         type:'bool',                  tooltip:t('config.tip.security.unknownURLStrikes') },

  { path:'defenses.master',                   label:t('config.label.defenses.master'),                    type:'bool',                  tooltip:t('config.tip.defenses.master') },
  { path:'defenses.shield',                   label:t('config.label.defenses.shield'),                    type:'bool',                  tooltip:t('config.tip.defenses.shield') },
  { path:'defenses.rateLimit',                label:t('config.label.defenses.rateLimit'),                 type:'bool',                  tooltip:t('config.tip.defenses.rateLimit') },
  { path:'defenses.handler',                  label:t('config.label.defenses.handler'),                   type:'bool',                  tooltip:t('config.tip.defenses.handler') },
  { path:'defenses.waf',                      label:t('config.label.defenses.waf'),                       type:'bool',                  tooltip:t('config.tip.defenses.waf') },
  { path:'defenses.honeypot',                 label:t('config.label.defenses.honeypot'),                  type:'bool',                  tooltip:t('config.tip.defenses.honeypot') },

  { path:'server.port',                       label:t('config.label.server.port'),                        type:'posInt',  unit:'',      tooltip:t('config.tip.server.port'), restart:true, readonly:true },
  { path:'server.maxConcurrentRequests',      label:t('config.label.server.maxConcurrentRequests'),       type:'posInt',  unit:t('config.unit.req'),   tooltip:t('config.tip.server.maxConcurrentRequests') },
  { path:'server.sessionTimeoutMinutes',      label:t('config.label.server.sessionTimeoutMinutes'),       type:'posInt',  unit:t('config.unit.min'),   tooltip:t('config.tip.server.sessionTimeoutMinutes') },

  { path:'ui.refreshIntervalSeconds',         label:t('config.label.ui.refreshIntervalSeconds'),          type:'posInt',  unit:t('config.unit.sec'),   tooltip:t('config.tip.ui.refreshIntervalSeconds') },
];

const TYPE_VALIDATORS = {
  posInt:    v => (Number.isInteger(+v) && +v > 0)                ? null : t('config.err.posInt'),
  nonNegInt: v => (Number.isInteger(+v) && +v >= 0)               ? null : t('config.err.nonNegInt'),
  percent:   v => (Number.isInteger(+v) && +v >= 1 && +v <= 100)  ? null : t('config.err.percent'),
  bool:      v => (typeof v === 'boolean')                         ? null : t('config.err.bool'),
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
    (field.restart ? ' <span class="eq-restart-pill">' + escapeHTML(t('config.restartPill')) + '</span>' : '');
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
    paintFieldError('monitoring.cpuPanicLiftBelow', t('config.err.liftBelowTrigger'));
  } else {

    const liftErr = fieldErrors.get('monitoring.cpuPanicLiftBelow');
    if (liftErr === t('config.err.liftBelowTrigger')) {
      paintFieldError('monitoring.cpuPanicLiftBelow', null);
    }

    if (liftValid) {

      const stale = fieldErrors.get('monitoring.cpuPanicLiftBelow');
      if (stale === t('config.err.liftBelowTrigger')) {
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
    showBanner(t('config.msg.fixFields'), 'error');
    updateDirtyState();
    return;
  }
  const res = await api('/api/dashboard/config', 'POST', currentConfig);
  if (res === AUTH_REQUIRED) { window.location.href = '/sentinel.html'; return; }
  if (res === null) { showBanner(t('config.msg.networkError'), 'error'); return; }
  if (!res.ok) {
    const fields = (res.body && res.body.fields) || [];
    paintServerErrors(fields);
    showBanner(t('config.msg.serverRejected'), 'error');
    return;
  }
  originalConfig = deepClone(currentConfig);
  document.getElementById('last-saved').textContent = t('config.savedAt', { time: new Date().toLocaleTimeString(I18N.locale()) });
  document.getElementById('dirty-badge').classList.add('hidden');
  document.getElementById('btn-save').disabled = true;
  showBanner(t('config.msg.saved'), 'success');
}

async function onResetDefaults() {
  if (!confirm(t('config.confirmReset'))) return;
  const res = await api('/api/dashboard/config/reset', 'POST');
  if (res === AUTH_REQUIRED) { window.location.href = '/sentinel.html'; return; }
  if (res === null) { showBanner(t('config.msg.networkError'), 'error'); return; }
  if (!res.ok) { showBanner(t('config.msg.resetFailed'), 'error'); return; }
  originalConfig = (res.body && res.body.config) ? res.body.config : res.body;
  currentConfig  = deepClone(originalConfig);
  renderForm();
  updateDirtyState();
  showBanner(t('config.msg.resetDone'), 'success');
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
      t('config.loadFailed');
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
