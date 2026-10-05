

'use strict';


const API = {
    authStatus:      '/admin/auth/status',
    login:           '/admin/auth/login',
    logout:          '/admin/auth/logout',
    generatePassphrase: '/admin/auth/generate-passphrase',
    clearDynamic:       '/admin/auth/clear-dynamic',
    status:          '/admin/status',
    logs:            '/admin/logs',
    snapshot:        '/api/dashboard/snapshot',
    block:           '/api/dashboard/block',
    unblock:         '/api/dashboard/unblock',
    allow:           '/api/dashboard/allow',
    removeAllow:     '/api/dashboard/removeallow',
    ackAlert:        '/api/dashboard/alerts/ack',
    clearAlerts:     '/api/dashboard/alerts/clear',
    alerts:          '/api/dashboard/alerts',
    exportLogs:      '/api/dashboard/logs/export',
    resetGuard:      '/api/dashboard/guard/reset',
    clearIPLists:    '/api/dashboard/iplists/clear',
    toggleBlitz:     '/admin/toggle/blitz',
    toggleRateLimit: '/admin/toggle/ratelimit',
    toggleHandler:   '/admin/toggle/handler',
    toggleWAF:       '/admin/toggle/waf',
    toggleMaster:    '/admin/toggle/master',
    attackDos:       '/admin/attack/dos',
    attackBandwidth: '/admin/attack/bandwidth',
    attackHeader:    '/admin/attack/headeroverflow',
    attackGhost:     '/admin/attack/ghostflood',
    panicTrigger:    '/admin/panic/trigger',
    panicLift:       '/admin/panic/lift',
    honeypotHits:    '/admin/honeypot/hits',
    workers:         '/admin/workers',
    explain:         '/api/dashboard/explain',
};

const POLL_INTERVAL_MS = 1000;
const LOG_LINES        = 120;
const GRAPH_SAMPLES    = 60;


const state = {
    authenticated:  false,
    autoScroll:     true,
    pollTimer:      null,
    logTimer:       null,
    workerTimer:    null,
    honeypotTimer:  null,
    alertTimer:     null,
    logLines:       [],
    cpuHistory:     [],
    rateHistory:    [],

    highestSeenAlertId: 0,
    dpg: { code: null, expiresAt: 0, ttlTimer: null },

    explain: {
        open: false,
        ip: null,
        lastFocusedIP: null,
        abortController: null,
        busy: false,
    },

    spotlight: {
        open: false,
        query: '',
        results: [],
        selectedIndex: 0,
        busy: false,
    },
};


const HIDDEN_POLL_MULTIPLIER = 5;


function $(id) { return document.getElementById(id); }

function setText(id, value) {
    const el = $(id);
    if (el && el.textContent !== String(value)) el.textContent = String(value);
}

function setClass(el, cls) {
    if (el && el.className !== cls) el.className = cls;
}

function fmtUptime(seconds) {
    const s = Math.floor(seconds);
    if (s >= 86400) return t('dash.uptime.days', { d: Math.floor(s/86400), h: Math.floor((s%86400)/3600) });
    if (s >= 3600)  return t('dash.uptime.hours', { h: Math.floor(s/3600), m: Math.floor((s%3600)/60) });
    if (s >= 60)    return t('dash.uptime.minutes', { m: Math.floor(s/60), s: s%60 });
    return t('dash.unit.sec', { n: s });
}

function fmtTs(ts) {
    if (!ts) return '—';
    return ts.replace('T', ' ').substring(0, 19);
}

function numFmt(n) {
    return typeof n === 'number' ? n.toLocaleString(I18N.locale()) : (n ?? '—');
}


function normalizeIP(raw) {
    if (raw == null) return '—';
    let s = String(raw).trim();
    if (s === '') return '—';
    if (s.startsWith('anon:')) return s;
    if (s.startsWith('[')) {
        const close = s.indexOf(']');
        if (close > 1) s = s.slice(1, close);
    }
    const pct = s.indexOf('%');
    if (pct > 0) s = s.slice(0, pct);
    if (s === '::1' || s === '0:0:0:0:0:0:0:1') return '127.0.0.1';
    if (s === '::' || s === '0:0:0:0:0:0:0:0') return '0.0.0.0';
    const lower = s.toLowerCase();
    if (lower.startsWith('::ffff:')) {
        const tail = s.slice(7);
        if (/^(\d{1,3}\.){3}\d{1,3}$/.test(tail)) return tail;
    }
    if (lower.startsWith('0:0:0:0:0:ffff:')) {
        const tail = s.slice(15);
        if (/^(\d{1,3}\.){3}\d{1,3}$/.test(tail)) return tail;
    }
    if (/^(\d{1,3}\.){3}\d{1,3}$/.test(s)) return s;
    const cIdx = s.indexOf(':');
    if (cIdx > 0 && s.indexOf(':', cIdx + 1) === -1) {
        const left = s.slice(0, cIdx);
        if (/^(\d{1,3}\.){3}\d{1,3}$/.test(left)) return left;
    }
    return s;
}


const AUTH_REQUIRED = Symbol('AUTH_REQUIRED');

async function api(url, method = 'GET', body = null, signal = null) {
    const opts = {
        method,
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
    };
    if (body !== null) opts.body = JSON.stringify(body);
    if (signal) opts.signal = signal;
    try {
        const r = await fetch(url, opts);
        if (r.status === 401 || r.status === 403) return AUTH_REQUIRED;
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return await r.json();
    } catch (e) {

        if (e && e.name === 'AbortError') throw e;
        console.warn(`[Sentinel] API error ${url}:`, e.message);
        return null;
    }
}


function handleSessionExpired() {
    if (!state.authenticated) return;
    console.warn('[Sentinel] Session expired or privilege revoked — redirecting to login');
    stopPolling();
    state.authenticated = false;
    window.location.replace('/sentinel.html?reason=expired');
}


function checkAuth(result) {
    if (result === AUTH_REQUIRED) {
        handleSessionExpired();
        return true;
    }
    return false;
}


function showLogin(errorMsg = '') {
    const loginScreen = $('login-screen');
    const dashboard   = $('dashboard');
    if (loginScreen) loginScreen.classList.remove('hidden');
    if (dashboard)   dashboard.classList.add('hidden');

    const errorEl = $('login-error');
    if (errorEl) {
        if (errorMsg) {
            errorEl.textContent = errorMsg;
            errorEl.classList.remove('hidden');
        } else {
            errorEl.classList.add('hidden');
        }
    }

    const input = $('login-passphrase');
    if (input) {
        input.value = '';
        input.focus();
    }
    clearDpgDisplay();
}

function showDashboard() {
    const loginScreen = $('login-screen');
    const dashboard   = $('dashboard');
    if (loginScreen) loginScreen.classList.add('hidden');
    if (dashboard)   dashboard.classList.remove('hidden');
}

async function doLogin() {
    const input  = $('login-passphrase');
    const btn    = $('login-btn');
    const phrase = input ? input.value : '';

    if (!phrase) return;

    if (btn) btn.disabled = true;

    const setAsDefault = $('dpg-set-default')?.checked ?? false;
    const result = await api(API.login, 'POST', { passphrase: phrase, setAsDefault });

    if (btn) btn.disabled = false;

    if (result === AUTH_REQUIRED || (result && result.success === false)) {
        showLogin(t('dash.login.failed'));
        return;
    }

    if (!result || result.success !== true) {
        showLogin(t('dash.login.error'));
        return;
    }


    clearDpgDisplay();
    state.authenticated = true;
    showDashboard();
    await loadSnapshot();
    startPolling();
}

async function doLogout() {
    stopPolling();
    await api(API.logout, 'POST', {});
    state.authenticated = false;

    window.location.reload();
}


function clearDpgDisplay() {
    state.dpg.code = null;
    state.dpg.expiresAt = 0;
    if (state.dpg.ttlTimer) {
        clearInterval(state.dpg.ttlTimer);
        state.dpg.ttlTimer = null;
    }
    const display = $('dpg-display');
    if (display) display.classList.add('hidden');
    const codeEl = $('dpg-code');
    if (codeEl) codeEl.textContent = '—';
    const ttlEl = $('dpg-ttl');
    if (ttlEl) ttlEl.textContent = t('dash.login.expiresIn', { time: '5:00' });
    const cb = $('dpg-set-default');
    if (cb) cb.checked = false;
}

async function handleGeneratePassphrase() {
    const btn = $('btn-generate-passphrase');
    if (btn) btn.disabled = true;
    try {
        const r = await api(API.generatePassphrase, 'POST', {});
        if (r === null) {
            showAlertToast({
                id: -Date.now(),
                severity: 'CRITICAL',
                title: t('dash.login.generateFailed'),
                message: t('dash.login.generateFailedMsg'),
            });
            return;
        }
        if (r.success === false) {
            const msg = r.retryAfterSec
                ? t('dash.login.tooMany', { n: r.retryAfterSec })
                : (r.message || t('dash.login.refusedMsg'));
            showAlertToast({
                id: -Date.now(),
                severity: 'WARNING',
                title: t('dash.login.generateRefused'),
                message: msg,
            });
            return;
        }

        state.dpg.code      = r.passphrase;
        state.dpg.expiresAt = Date.now() + (r.expiresInSec * 1000);
        const codeEl    = $('dpg-code');
        const display   = $('dpg-display');
        const input     = $('login-passphrase');
        if (codeEl)  codeEl.textContent = r.passphrase;
        if (display) display.classList.remove('hidden');
        if (input)   input.value = r.passphrase;

        if (state.dpg.ttlTimer) clearInterval(state.dpg.ttlTimer);
        renderDpgTtl();
        state.dpg.ttlTimer = setInterval(renderDpgTtl, 1000);
    } finally {
        if (btn) btn.disabled = false;
    }
}

function renderDpgTtl() {
    const ttlEl = $('dpg-ttl');
    if (!ttlEl) return;
    const remainingMs = state.dpg.expiresAt - Date.now();
    if (remainingMs <= 0) {
        ttlEl.textContent = t('dash.login.expired');
        ttlEl.classList.add('expired');
        clearDpgDisplay();
        return;
    }
    const sec = Math.floor(remainingMs / 1000);
    const m   = Math.floor(sec / 60);
    const s   = sec % 60;
    ttlEl.textContent = t('dash.login.expiresIn', { time: `${m}:${String(s).padStart(2, '0')}` });
}

async function handleCopyPassphrase() {
    if (!state.dpg.code) return;
    const btn = $('btn-copy-passphrase');
    try {
        await navigator.clipboard.writeText(state.dpg.code);
        if (btn) {
            const original = btn.textContent;
            btn.textContent = '✓';
            setTimeout(() => { btn.textContent = original; }, 1200);
        }
    } catch (e) {
        showAlertToast({
            id: -Date.now(),
            severity: 'WARNING',
            title: t('dash.toast.copyFailed'),
            message: t('dash.login.copyFailedMsg'),
        });
    }
}


function drawGraph(canvasId, samples, maxValue, color, fillColor) {
    const canvas = $(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const W = canvas.width, H = canvas.height;
    const pad = { top: 4, bottom: 4, left: 2, right: 2 };
    const iW = W - pad.left - pad.right;
    const iH = H - pad.top  - pad.bottom;

    ctx.clearRect(0, 0, W, H);
    if (!samples || samples.length < 2) return;

    const dataMax = Math.max(...samples, maxValue || 1);
    const scaleY  = v => pad.top + iH - (v / dataMax) * iH;
    const scaleX  = i => pad.left + (i / (GRAPH_SAMPLES - 1)) * iW;
    const padded  = Array(Math.max(0, GRAPH_SAMPLES - samples.length)).fill(0).concat(samples);

    ctx.beginPath();
    ctx.moveTo(scaleX(0), scaleY(padded[0]));
    for (let i = 1; i < padded.length; i++) ctx.lineTo(scaleX(i), scaleY(padded[i]));
    ctx.lineTo(scaleX(padded.length - 1), H);
    ctx.lineTo(scaleX(0), H);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(scaleX(0), scaleY(padded[0]));
    for (let i = 1; i < padded.length; i++) ctx.lineTo(scaleX(i), scaleY(padded[i]));
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.stroke();
}


function updatePanicBanner(panicState, opts = {}) {
    if (!panicState) return;
    const banner    = $('panic-banner');
    const cpuActive = panicState.cpuPanicActive;
    const active    = panicState.active || cpuActive;
    if (!banner) return;
    if (active) {
        banner.classList.remove('hidden');
        if (cpuActive && !panicState.active) {
            $('panic-label').textContent  = t('dash.panic.cpuActive');
            $('panic-reason').textContent = t('dash.panic.cpuReason');
            $('panic-timer').textContent  = t('dash.unit.sec', { n: panicState.cpuPanicSecondsRemaining });
        } else {
            $('panic-label').textContent  = t('dash.panic.modeActive');
            $('panic-reason').textContent = panicState.reason || '';
            $('panic-timer').textContent  = t('dash.unit.sec', { n: panicState.secondsRemaining });
        }
    } else {
        banner.classList.add('hidden');
    }
}

function updateThreatBadge(d, opts = {}) {
    const badge = $('threat-badge');
    if (!badge) return;
    let level = t('dash.threat.normal'), cls = 'threat-normal';
    if (d.panicState && (d.panicState.active || d.panicState.cpuPanicActive)) {
        level = t('dash.threat.panic'); cls = 'threat-critical';
    } else if (d.alertSummary && d.alertSummary.critical > 0) {
        level = t('dash.threat.critical'); cls = 'threat-critical';
    } else if (d.alertSummary && d.alertSummary.warning > 0) {
        level = t('dash.threat.elevated'); cls = 'threat-elevated';
    }
    badge.textContent = level;
    setClass(badge, cls);
}

function updateStats(d, opts = {}) {
    setText('s-total',   numFmt(d.totalRequests));
    setText('s-allowed', numFmt(d.allowedRequests));
    setText('s-blocked', numFmt(d.blockedRequests));
    setText('s-rl',      numFmt(d.rateLimitedRequests));
    setText('s-waf',     numFmt(d.wafRejections));
    setText('s-honeypot',numFmt(d.honeypotHits));
    setText('s-panic',   numFmt(d.panicRejections));
    setText('s-rate',    numFmt(d.currentRate));
    setText('uptime-val', fmtUptime(d.uptime));
    setText('timestamp-val', fmtTs(d.timestamp));
}


function updateDefenseStats(d) {

    const bp = d.blitzPolicy;
    if (bp) {
        const cap    = Number(bp.rateCap)    || 0;
        const winSec = Number(bp.windowSec)  || 60;
        setText('stat-rate-cap',   t('dash.unit.rateCap', { cap: numFmt(cap), sec: winSec }));
        setText('stat-window',     t('dash.unit.sec', { n: winSec }));
        setText('stat-strike-cap', `${Number(bp.strikeCap) || 0}`);
        setText('stat-block-ttl',  t('dash.unit.sec', { n: Number(bp.blockTTL)  || 0 }));
    }

    const rl = d.rlPolicy;
    if (rl) {
        const burstSize    = Number(rl.burstSize)       || 0;
        const burstWindow  = Number(rl.burstWindowSec)  || 0;
        const sustained    = Number(rl.sustainedRate)   || 0;
        const cpuPanic     = Number(rl.cpuPanicTrigger) || 0;
        setText('stat-burst-size',   t('dash.unit.req', { n: burstSize }));
        setText('stat-burst-window', t('dash.unit.sec', { n: burstWindow }));
        setText('stat-sustained',    t('dash.unit.reqPerSec', { n: sustained.toFixed(1) }));
        setText('stat-cpu-panic',    `${cpuPanic}%`);
    }
}

function updateCPU(d) {
    const cpu = typeof d.cpu === 'number' ? d.cpu : parseFloat(d.cpu) || 0;
    state.cpuHistory.push(cpu);
    if (state.cpuHistory.length > GRAPH_SAMPLES) state.cpuHistory.shift();
    setText('cpu-val', cpu.toFixed(1) + '%');
    const sample = d.cpuSample;
    if (sample) {
        setText('cpu-avg',      (sample.averageCPU || 0).toFixed(1) + '%');
        setText('cpu-heaviest', sample.heaviestName || '—');
        setText('cpu-procs',    sample.processCount || '—');
    }
    const badge = $('cpu-val');
    if (badge) {
        badge.style.color = cpu >= 75 ? 'var(--red)' : cpu >= 50 ? 'var(--amber)' : 'var(--green)';
    }
    drawGraph('cpu-canvas', state.cpuHistory, 100,
        'rgba(29,111,235,0.9)', 'rgba(29,111,235,0.15)');
}

function updateRate(d) {
    const rate = typeof d.currentRate === 'number' ? d.currentRate : 0;
    state.rateHistory.push(rate);
    if (state.rateHistory.length > GRAPH_SAMPLES) state.rateHistory.shift();
    setText('rate-val', t('dash.unit.reqPerMin', { n: numFmt(rate) }));
    drawGraph('rate-canvas', state.rateHistory, null,
        'rgba(46,160,67,0.9)', 'rgba(46,160,67,0.15)');
}

function updateToggles(d, opts = {}) {


    const masterOn = d.master !== false;


    const masterBtn = $('tog-master');
    if (masterBtn) {
        masterBtn.dataset.state = masterOn ? 'true' : 'false';
        masterBtn.textContent   = masterOn ? t('dash.toggle.engaged') : t('dash.toggle.disengaged');
        masterBtn.disabled      = false;
        masterBtn.removeAttribute('aria-disabled');
        masterBtn.title         = '';
    }

    const subMap = {
        'tog-blitz':     d.blitz,
        'tog-ratelimit': d.rateLimit,
        'tog-handler':   d.handler,
        'tog-waf':       d.waf,
    };
    for (const [id, val] of Object.entries(subMap)) {
        const btn = $(id);
        if (!btn) continue;
        if (masterOn) {
            const on = Boolean(val);
            btn.dataset.state = on ? 'true' : 'false';
            btn.textContent   = on ? t('dash.toggle.engaged') : t('dash.toggle.disengaged');
            btn.disabled      = false;
            btn.removeAttribute('aria-disabled');
            btn.title         = '';
        } else {

            btn.dataset.state = 'false';
            btn.textContent   = t('dash.toggle.disengaged');
            btn.disabled      = true;
            btn.setAttribute('aria-disabled', 'true');
            btn.title         = t('dash.master.layerLocked');
        }
    }


    const masterCard = $('dcard-master');
    const masterLine = $('master-status-line');
    if (masterCard && masterLine) {
        if (masterOn) {
            masterCard.style.borderColor = '';
            masterCard.style.boxShadow   = '';
            masterLine.style.color       = 'var(--text-secondary)';
            masterLine.textContent       = t('dash.master.statusOn');
        } else {
            masterCard.style.borderColor = 'var(--red, #ff3b30)';
            masterCard.style.boxShadow   = '0 0 0 1px rgba(255,59,48,0.35), 0 0 18px rgba(255,59,48,0.2)';
            masterLine.style.color       = 'var(--red, #ff3b30)';
            masterLine.textContent       = t('dash.master.statusOff');
        }
    }
}

function updateAlerts(alertSummary, opts = {}) {
    if (!alertSummary) return;
    const badge = $('alert-badge');
    if (!badge) return;
    const unack = alertSummary.unacknowledged || 0;
    badge.textContent = unack;
    if (unack > 0) {
        badge.classList.remove('hidden');
        badge.className = `count-badge ${alertSummary.critical > 0 ? 'red' : 'amber'}`;
    } else {
        badge.classList.add('hidden');
    }
}

function updateBlocklist(blocklist, count, opts = {}) {
    const badge = $('blocklist-badge');
    if (badge) badge.textContent = count ?? (blocklist ? blocklist.length : 0);
    const body = $('blocklist-body');
    if (!body || !blocklist) return;
    body.innerHTML = '';
    if (blocklist.length === 0) { body.textContent = t('dash.ip.empty'); return; }
    blocklist.slice(0, 50).forEach(entry => {
        const row    = document.createElement('div');
        row.className = 'bl-row';
        const ip     = document.createElement('span');
        ip.className   = 'bl-ip clickable';
        ip.textContent = normalizeIP(entry.ip);


        ip.addEventListener('click', () => openExplainPanel(entry.ip));
        const reason = document.createElement('span');
        reason.className   = 'bl-reason';
        reason.textContent = entry.reason || '—';
        reason.title       = entry.reason || '';
        const ttl    = document.createElement('span');
        ttl.className   = 'bl-ttl';
        ttl.textContent = entry.timeRemaining || '—';
        if (entry.status === 'permanent') ttl.classList.add('bl-perm');
        row.append(ip, reason, ttl);
        body.appendChild(row);
    });
}

async function loadAlerts() {
    const data = await api(API.alerts);
    if (checkAuth(data)) return;
    const list = $('alerts-list');
    if (!list) return;
    if (!data) {
        list.textContent = t('dash.alerts.unavailable');
        return;
    }
    const recent = Array.isArray(data.recentAlerts) ? data.recentAlerts : [];
    lastAlerts = recent;
    list.innerHTML = '';
    const alerts = [...recent].reverse().slice(0, 30);
    if (alerts.length === 0) { list.textContent = t('dash.alerts.empty'); return; }
    alerts.forEach(a => {
        const row   = document.createElement('div');
        row.className = `alert-row ${(a.severity||'').toLowerCase()}${a.acknowledged?' acked':''}`;

        if (typeof a.id !== 'undefined') row.dataset.alertId = String(a.id);
        const title = document.createElement('div');
        title.className   = 'alert-title';
        title.textContent = `[${a.severity}] ${a.title}`;
        const msg   = document.createElement('div');
        msg.className   = 'alert-msg';
        msg.textContent = a.message || '';
        const meta  = document.createElement('div');
        meta.className   = 'alert-meta';
        meta.textContent = fmtTs(a.timestamp) + (a.acknowledged ? t('dash.alerts.ackedSuffix') : '');
        row.append(title, msg, meta);
        row.addEventListener('click', () => ackAlert(a.id));
        list.appendChild(row);
    });


    const fresh = [...recent].filter(a =>
        typeof a.id === 'number'
        && a.id > state.highestSeenAlertId
        && !a.acknowledged
        && (a.severity === 'WARNING' || a.severity === 'CRITICAL')
    );
    if (fresh.length > 0) {

        fresh.slice(-4).forEach(showAlertToast);
    }


    const maxId = recent.reduce((m, a) => Math.max(m, a.id || 0), 0);
    if (maxId > state.highestSeenAlertId) state.highestSeenAlertId = maxId;
}


function showAlertToast(alert) {
    const stack = $('alert-toast-stack');
    if (!stack) return;
    const sev = (alert.severity || 'info').toLowerCase();
    const toast = document.createElement('div');
    toast.className = `alert-toast ${sev}`;
    toast.dataset.alertId = String(alert.id);

    const title = document.createElement('div');
    title.className = 'at-title';
    title.textContent = `[${alert.severity}] ${alert.title || ''}`;

    const msg = document.createElement('div');
    msg.className = 'at-msg';
    msg.textContent = alert.message || '';

    const hint = document.createElement('div');
    hint.className = 'at-hint';
    hint.textContent = sev === 'critical' ? t('dash.alerts.hintCritical') : t('dash.alerts.hintAuto');

    toast.append(title, msg, hint);

    const dismiss = (ack) => {
        if (toast.classList.contains('dismissing')) return;
        toast.classList.add('dismissing');
        if (ack) ackAlert(alert.id);
        setTimeout(() => toast.remove(), 220);
    };

    toast.addEventListener('click', () => dismiss(true));
    stack.appendChild(toast);

    if (sev === 'warning' || sev === 'info') {
        setTimeout(() => dismiss(false), 5000);
    }
}

async function ackAlert(id) {
    const r = await api(API.ackAlert, 'POST', { id });
    if (checkAuth(r)) return;
    await loadAlerts();
}

async function refreshWorkers() {
    const data = await api(API.workers);
    if (checkAuth(data)) return;
    if (!data || !data.workers) return;
    const list = $('worker-list');
    if (!list) return;
    list.innerHTML = '';
    data.workers.forEach(w => {
        const row   = document.createElement('div');
        row.className = 'worker-row';
        const dot   = document.createElement('div');
        dot.className = `worker-dot ${w.status}`;
        const name  = document.createElement('span');
        name.className   = 'worker-name';
        name.textContent = w.name;
        const beats = document.createElement('span');
        beats.className   = 'worker-beats';
        beats.textContent = t('dash.workers.beats', { n: w.beatCount });
        const ago   = document.createElement('span');
        ago.className   = 'worker-ago';
        ago.textContent = t('dash.workers.ago', { n: w.lastBeatAgoSec });
        row.append(dot, name, beats, ago);
        list.appendChild(row);
    });
}

async function loadHoneypotHits() {
    const data = await api(API.honeypotHits + '?count=30');
    if (checkAuth(data)) return;
    if (!data) return;

    if (Array.isArray(data.hits)) lastHoneypotHits = data.hits;
    const badge = $('honeypot-badge');
    if (badge && data.stats) badge.textContent = data.stats.totalHits ?? 0;
    const list = $('honeypot-list');
    if (!list || !data.hits) return;
    if (data.hits.length === 0) { list.textContent = t('dash.honeypot.empty'); return; }
    list.innerHTML = '';
    [...data.hits].reverse().forEach(h => {
        const row = document.createElement('div');
        row.className = 'hp-row';
        const ip  = document.createElement('span');
        ip.className   = 'hp-ip clickable';
        ip.textContent = normalizeIP(h.ip);

        ip.addEventListener('click', () => openExplainPanel(h.ip));
        const url = document.createElement('span');
        url.className   = 'hp-url';
        url.textContent = h.url || '—';
        url.title       = h.url || '';
        const ts  = document.createElement('span');
        ts.className   = 'hp-ts';
        ts.textContent = (h.timestamp || '').substring(11, 19);
        row.append(ip, url, ts);
        list.appendChild(row);
    });
}

function classifyLogLine(text) {
    const t = text.toUpperCase();
    if (t.includes('SHIELD INTERCEPTED') || t.includes('BLOCKED'))  return 'blocked';
    if (t.includes('RATE-LIMIT') || t.includes('RATE_LIMITED'))      return 'rate';
    if (t.includes('WAF RECON') || t.includes('RECON'))              return 'recon';
    if (t.includes('WAF REJECTED') || t.includes('TRAVERSAL'))       return 'waf';
    if (t.includes('[ADMIN]') || t.includes('[ATTACK]'))             return 'admin';
    if (t.includes('UPLOAD'))                                         return 'upload';
    return '';
}


const LOG_IP_REGEX = /\b(?:\d{1,3}\.){3}\d{1,3}\b|\banon:[0-9a-f]+\b|\[?(?:[0-9a-fA-F:]+::?[0-9a-fA-F:]*)\]?/g;

function escapeHTML(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}


const CLIENT_BADGE_REGEX = /\[(BROWSER|CURL|POSTMAN|WGET|PYTHON|GO_HTTP|POWERSHELL|BOT|SPOOFED_BROWSER|UNKNOWN|SCRIPTED)\]/;


function isCompactDensity() {
    return document.documentElement.getAttribute('data-density') === 'compact';
}

function compactTimestamp(text) {
    if (!isCompactDensity()) return text;


    return text.replace(/^\[\d{4}-\d{2}-\d{2}[T ]?(\d{2}:\d{2}:\d{2})\]/, '[$1]');
}

function compactIPv4(m) {


    const match = m.match(/^(\d+\.\d+\.\d+\.)(\d+)$/);
    if (match) return '…' + match[2];
    return m;
}

function wrapIPsInLogLine(text) {
    const compact = isCompactDensity();
    let escaped = escapeHTML(text);


    escaped = escaped.replace(CLIENT_BADGE_REGEX, (_, type) => {
        const cls = 'ct-' + type.toLowerCase();
        return `<span class="client-badge ${cls}">${type}</span>`;
    });
    escaped = escaped.replace(LOG_IP_REGEX, m => {


        const display = compact ? compactIPv4(m) : m;
        return `<span class="log-ip clickable" data-ip="${m}" title="${m}">${display}</span>`;
    });
    return escaped;
}


function rerenderLogFeed() {
    const body = $('log-body');
    if (!body) return;
    body.innerHTML = '';
    state.logLines.forEach(({ text, cls }) => {
        const el = document.createElement('div');
        el.className = `log-line ${cls}`.trim();
        el.innerHTML = wrapIPsInLogLine(compactTimestamp(text));
        body.appendChild(el);
    });
    if (state.autoScroll) body.scrollTop = body.scrollHeight;
}

async function pollLogs() {
    const data = await api(API.logs);
    if (checkAuth(data)) return;
    if (!data || !Array.isArray(data.lines)) return;
    const body = $('log-body');
    if (!body) return;
    const existing = new Set(state.logLines.map(l => l.text));
    let added = false;
    data.lines.forEach(line => {
        if (!existing.has(line)) {
            state.logLines.push({ text: line, cls: classifyLogLine(line) });
            added = true;
        }
    });
    if (!added) return;
    if (state.logLines.length > LOG_LINES) state.logLines = state.logLines.slice(-LOG_LINES);
    body.innerHTML = '';
    state.logLines.forEach(({ text, cls }) => {
        const el = document.createElement('div');
        el.className = `log-line ${cls}`.trim();


        el.innerHTML = wrapIPsInLogLine(compactTimestamp(text));
        body.appendChild(el);
    });
    if (state.autoScroll) body.scrollTop = body.scrollHeight;
}


function stopPolling() {
    if (state.pollTimer)     { clearTimeout(state.pollTimer);  state.pollTimer = null; }


    if (state.workerTimer)   { clearInterval(state.workerTimer);   state.workerTimer = null; }
    if (state.honeypotTimer) { clearInterval(state.honeypotTimer); state.honeypotTimer = null; }
    if (state.alertTimer)    { clearInterval(state.alertTimer);    state.alertTimer = null; }
}


function pollIntervalFor(baseMs) {
    return document.hidden ? baseMs * HIDDEN_POLL_MULTIPLIER : baseMs;
}

function startPolling() {
    stopPolling();
    async function tick() {
        if (!state.authenticated) return;
        const d = await api(API.status);
        if (checkAuth(d)) return;
        if (d) {
            updateStats(d);
            updateCPU(d);
            updateRate(d);
            updateToggles(d);
            updateDefenseStats(d);
            updatePanicBanner(d.panicState);
            updateThreatBadge(d);
            updateAlerts(d.alertSummary);
            if (Array.isArray(d.blacklist)) updateBlocklist(d.blacklist, d.blacklistCount);
            if (d.honeypotStats) {
                const b = $('honeypot-badge');
                if (b) b.textContent = d.honeypotStats.totalHits ?? 0;
            }
        }
        await pollLogs();
        state.pollTimer = setTimeout(tick, pollIntervalFor(POLL_INTERVAL_MS));
    }
    tick();
    state.workerTimer   = setInterval(() => {
        if (state.authenticated && !document.hidden) refreshWorkers();
    }, 5000);
    state.honeypotTimer = setInterval(() => {
        if (state.authenticated && !document.hidden) loadHoneypotHits();
    }, 10000);
    state.alertTimer    = setInterval(() => {
        if (state.authenticated) loadAlerts();
    }, 5000);
}


document.addEventListener('visibilitychange', () => {
    if (!document.hidden && state.authenticated) {
        loadAlerts();
        if (state.pollTimer) {
            clearTimeout(state.pollTimer);
            state.pollTimer = setTimeout(() => startPolling(), 0);
        }
    }
});

async function loadSnapshot() {
    const data = await api(API.snapshot);
    if (checkAuth(data)) return;
    if (!data) return;


    lastDashboardData = data;
    if (data.blocklist)  updateBlocklist(data.blocklist, data.blocklist.length);
    if (data.alertSummary) updateAlerts(data.alertSummary);
    await loadAlerts();
    if (Array.isArray(data.rateHistory)) {
        state.rateHistory = data.rateHistory.map(r => r.rate || 0).slice(-GRAPH_SAMPLES);
    }
    await loadHoneypotHits();
    await refreshWorkers();
}


let lastDashboardData = null;
let lastHoneypotHits = [];
let lastAlerts = [];


const TOGGLE_URLS = {
    blitz:     API.toggleBlitz,
    ratelimit: API.toggleRateLimit,
    handler:   API.toggleHandler,
    waf:       API.toggleWAF,
    master:    API.toggleMaster,
};

async function handleToggle(layer) {


    if (layer !== 'master') {
        const masterBtn = $('tog-master');
        if (masterBtn && masterBtn.dataset.state === 'false') {
            showAlertToast({
                id: -Date.now(),
                severity: 'WARNING',
                title: t('dash.toast.masterOff'),
                message: t('dash.toast.masterOffMsg'),
            });
            return;
        }
    }

    const btn = document.querySelector(`[data-layer="${layer}"]`);
    if (!btn) return;
    const next = btn.dataset.state !== 'true';
    const url  = TOGGLE_URLS[layer];
    if (!url) return;


    if (layer === 'master' && next === false) {
        const ok = confirm(t('dash.master.confirmOff'));
        if (!ok) return;
    }

    const r = await api(url + `?enabled=${next}`, 'POST');
    if (checkAuth(r)) return;
    btn.dataset.state = next ? 'true' : 'false';
    btn.textContent   = next ? t('dash.toggle.engaged') : t('dash.toggle.disengaged');


    if (layer === 'master') {
        const fresh = await api(API.status);
        if (!checkAuth(fresh) && fresh) updateToggles(fresh);
    }
}

async function handleBlockIP() {
    const ip = $('ip-input').value.trim();
    if (!ip) return;
    const r = await api(API.block, 'POST', { ip, duration: 300, reason: 'Manual block via dashboard' });
    if (checkAuth(r)) return;
    $('ip-input').value = '';
    await loadSnapshot();
}

async function handleUnblockIP() {
    const ip = $('ip-input').value.trim();
    if (!ip) return;
    const r = await api(API.unblock, 'POST', { ip });
    if (checkAuth(r)) return;
    $('ip-input').value = '';
    await loadSnapshot();
}

async function handleAllowIP() {
    const ip = $('ip-input').value.trim();
    if (!ip) return;
    const r = await api(API.allow, 'POST', { ip, reason: 'Manual allowlist via dashboard' });
    if (checkAuth(r)) return;
    $('ip-input').value = '';
    await loadSnapshot();
}

async function handleTriggerPanic() {
    const duration = parseInt($('panic-duration').value, 10) || 60;
    const r = await api(API.panicTrigger, 'POST', { duration, reason: 'Manual trigger via dashboard' });
    checkAuth(r);
}

async function handleLiftPanic() {
    const r = await api(API.panicLift, 'POST', {});
    checkAuth(r);
}

const ATTACK_URLS = {
    dos:            API.attackDos,
    bandwidth:      API.attackBandwidth,
    headeroverflow: API.attackHeader,
    ghostflood:     API.attackGhost,
};

async function handleLaunchAttack() {
    const vector  = $('attack-vector').value;
    const url     = ATTACK_URLS[vector];
    if (!url) return;
    const statusEl = $('attack-status');
    if (statusEl) { statusEl.classList.remove('hidden'); statusEl.textContent = t('dash.attack.launching', { vector }); }
    const data = await api(url, 'POST', {});
    if (checkAuth(data)) return;
    if (statusEl) {
        statusEl.textContent = data
            ? `✓ ${data.message || t('dash.attack.launched')}`
            : t('dash.attack.failed');
        setTimeout(() => statusEl.classList.add('hidden'), 5000);
    }
}

async function handleAckAll() {
    const r = await api(API.ackAlert, 'POST', { all: true });
    if (checkAuth(r)) return;
    await loadAlerts();
}

async function handleClearAlerts() {
    const r = await api(API.clearAlerts, 'POST', {});
    if (checkAuth(r)) return;
    await loadAlerts();
}

function handleExportLogs() { window.open(API.exportLogs, '_blank', 'noreferrer'); }

async function handleResetGuard() {
    if (!confirm(t('dash.feed.confirmReset'))) return;
    const r = await api(API.resetGuard, 'POST', {});
    if (checkAuth(r)) return;
    state.logLines = []; state.cpuHistory = []; state.rateHistory = [];
    await loadSnapshot();
}

async function handleClearIPLists() {
    const ok = confirm(t('dash.ip.confirmClear'));
    if (!ok) return;
    const btn = $('btn-clear-iplists');
    if (btn) btn.disabled = true;
    try {
        const r = await api(API.clearIPLists, 'POST', {});
        if (checkAuth(r)) return;
        if (r === null) {
            showAlertToast({
                id: -Date.now(),
                severity: 'CRITICAL',
                title: t('dash.ip.clearFailed'),
                message: t('dash.ip.clearNoResponse'),
            });
            return;
        }
        if (r.success === false) {
            showAlertToast({
                id: -Date.now(),
                severity: 'CRITICAL',
                title: t('dash.ip.clearFailed'),
                message: r.message || t('dash.ip.clearDiskFailed'),
            });
            return;
        }
        await loadSnapshot();
    } finally {
        if (btn) btn.disabled = false;
    }
}

function handleAutoScroll() {
    state.autoScroll = !state.autoScroll;
    const btn = $('btn-autoscroll');
    if (btn) btn.textContent = t('dash.feed.autoScroll', { state: state.autoScroll ? t('dash.feed.on') : t('dash.feed.off') });
}


function showToast(message, severity = 'INFO') {
    showAlertToast({
        id: -Date.now() - Math.floor(Math.random() * 1000),
        severity,
        title: message,
        message: '',
        acknowledged: true,
    });
}

function openExplainPanel(rawIP) {
    if (!rawIP) return;
    const ip = String(rawIP);
    state.explain.lastFocusedIP = ip;


    if (state.explain.abortController) {
        try { state.explain.abortController.abort(); } catch (_) {}
        state.explain.abortController = null;
    }

    state.explain.ip = ip;
    state.explain.open = true;

    const panel = $('explain-panel');
    const backdrop = $('explain-backdrop');
    if (panel) {
        panel.classList.remove('hidden');
        panel.classList.add('open');
        panel.setAttribute('aria-hidden', 'false');
    }
    if (backdrop) {
        backdrop.classList.remove('hidden');
        backdrop.classList.add('open');
        backdrop.setAttribute('aria-hidden', 'false');
    }


    setText('explain-ip', ip);
    setText('explain-geo', ip.startsWith('anon:') ? t('dash.explain.anon') : t('dash.explain.geoUnknown'));
    const statusEl = $('explain-status');
    if (statusEl) statusEl.textContent = t('dash.explain.loading');
    const sumEl = $('explain-summary');
    if (sumEl) sumEl.textContent = '—';
    const tlEl = $('explain-timeline');
    if (tlEl) tlEl.textContent = '—';
    const rawEl = $('explain-raw');
    if (rawEl) rawEl.textContent = '—';

    loadExplainData(ip);
}

function closeExplainPanel() {
    if (state.explain.abortController) {
        try { state.explain.abortController.abort(); } catch (_) {}
        state.explain.abortController = null;
    }
    state.explain.open = false;
    const panel = $('explain-panel');
    const backdrop = $('explain-backdrop');
    if (panel) {
        panel.classList.remove('open');
        panel.setAttribute('aria-hidden', 'true');
    }
    if (backdrop) {
        backdrop.classList.remove('open');
        backdrop.setAttribute('aria-hidden', 'true');

        setTimeout(() => {
            if (!state.explain.open) backdrop.classList.add('hidden');
        }, 240);
    }
}

async function loadExplainData(ip) {
    const ctrl = new AbortController();
    state.explain.abortController = ctrl;
    let data;
    try {
        data = await api(`${API.explain}?ip=${encodeURIComponent(ip)}&limit=500`, 'GET', null, ctrl.signal);
    } catch (e) {
        if (e && e.name === 'AbortError') return;
        const statusEl = $('explain-status');
        if (statusEl) statusEl.textContent = t('dash.explain.loadFailed');
        return;
    }
    if (state.explain.ip !== ip) return;
    if (checkAuth(data)) return;
    if (data === null) {
        const statusEl = $('explain-status');
        if (statusEl) statusEl.textContent = t('dash.explain.noResponse');
        return;
    }
    renderExplainHeader(data);
    renderExplainStatus(data);
    renderExplainSummary(data);
    renderExplainTimeline(data);
    renderExplainRaw(data);
}

function renderExplainHeader(data) {
    setText('explain-ip', data.ip || '—');
    const isAnon = String(data.ip || '').startsWith('anon:');
    setText('explain-geo', isAnon ? t('dash.explain.anon') : t('dash.explain.geoUnknown'));


    const s = data.status || {};
    const setBtn = (action, enabled) => {
        const btn = document.querySelector(`[data-explain-action="${action}"]`);
        if (!btn) return;
        btn.disabled = !enabled;
        btn.classList.toggle('disabled', !enabled);
    };
    setBtn('block-1h',  !s.allowlisted);
    setBtn('block-24h', !s.allowlisted);
    setBtn('block-perm', !s.allowlisted);
    setBtn('unblock',   !!s.blocked);
    setBtn('allowlist', !s.allowlisted);
}

function renderExplainStatus(data) {
    const el = $('explain-status');
    if (!el) return;
    const s = data.status || {};
    if (s.allowlisted) {
        el.textContent = t('dash.explain.statusAllowlisted');
        return;
    }
    if (s.blocked) {
        if (s.permanent) {
            el.textContent = t('dash.explain.statusPermanent', { strikes: s.strikes, threshold: s.permanentThreshold });
        } else {
            const rem = Number(s.expirySec || 0);
            const mins = Math.floor(rem / 60);
            const secs = rem % 60;
            el.textContent = t('dash.explain.statusBlocked', { m: mins, s: secs, strikes: s.strikes, threshold: s.permanentThreshold });
        }
        return;
    }
    if ((s.strikes || 0) > 0) {
        el.textContent = t('dash.explain.statusStrikes', { strikes: s.strikes, threshold: s.permanentThreshold });
    } else {
        el.textContent = t('dash.explain.statusClean');
    }
}

function renderExplainSummary(data) {
    const el = $('explain-summary');
    if (!el) return;
    el.innerHTML = '';
    const sum = data.summary || {};
    if (!sum.totalRequests) {
        const empty = document.createElement('div');
        empty.className = 'explain-empty';
        empty.textContent = t('dash.explain.noRequests');
        el.appendChild(empty);
        return;
    }

    const totals = document.createElement('div');
    totals.className = 'summary-row';
    totals.innerHTML = `<span>${t('dash.explain.requests')}</span><strong>${sum.totalRequests}</strong>`;
    el.appendChild(totals);

    const verbWrap = document.createElement('div');
    verbWrap.className = 'verb-mix';
    Object.entries(sum.verbMix || {}).forEach(([verb, count]) => {
        const chip = document.createElement('span');
        chip.textContent = `${verb} ${count}`;
        verbWrap.appendChild(chip);
    });
    el.appendChild(verbWrap);

    if (sum.firstSeen) {
        const fs = document.createElement('div');
        fs.className = 'summary-row';
        fs.innerHTML = `<span>${t('dash.explain.firstSeen')}</span><strong>${escapeHTML(fmtTs(sum.firstSeen))}</strong>`;
        el.appendChild(fs);
    }
    if (sum.lastSeen) {
        const ls = document.createElement('div');
        ls.className = 'summary-row';
        ls.innerHTML = `<span>${t('dash.explain.lastSeen')}</span><strong>${escapeHTML(fmtTs(sum.lastSeen))}</strong>`;
        el.appendChild(ls);
    }
    if (sum.topUserAgent) {
        const ua = document.createElement('div');
        ua.className = 'summary-row';
        ua.innerHTML = `<span>UA</span><strong>${escapeHTML(sum.topUserAgent)}</strong>`;
        el.appendChild(ua);
    }

    (sum.topUrls || []).forEach(u => {
        const row = document.createElement('div');
        row.className = 'top-url';
        const url = document.createElement('span');
        url.textContent = u.url;
        url.title = u.url;
        const count = document.createElement('span');
        count.className = 'u-count';
        count.textContent = u.count;
        row.append(url, count);
        el.appendChild(row);
    });
}

function renderExplainTimeline(data) {
    const el = $('explain-timeline');
    if (!el) return;
    el.innerHTML = '';
    const tl = data.timeline || [];
    if (tl.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'explain-empty';
        empty.textContent = t('dash.explain.noActivity');
        el.appendChild(empty);
        return;
    }
    const ICONS = {
        req:    '·',
        strike: '!',
        block:  '✕',
        trap:   '◆',
        radar:  '◎',
        alert:  '▲',
    };
    tl.forEach(row => {
        const tlRow = document.createElement('div');
        const typeClass = (row.type || 'REQUEST').toLowerCase();
        tlRow.className = `tl-row tl-${typeClass}`;

        const icon = document.createElement('span');
        icon.className = 'tl-icon';
        icon.textContent = ICONS[row.icon] || '·';

        const ts = document.createElement('span');
        ts.className = 'tl-ts';
        ts.textContent = String(row.ts || '').substring(11, 19) || '—';

        const detail = document.createElement('span');
        detail.className = 'tl-detail';
        let txt = row.detail || '';
        if (row.url) txt = `${row.verb ? row.verb + ' ' : ''}${row.url} — ${txt}`;
        detail.textContent = txt;

        tlRow.append(icon, ts, detail);
        el.appendChild(tlRow);
    });
}

function renderExplainRaw(data) {
    const el = $('explain-raw');
    if (!el) return;
    el.innerHTML = '';
    const raws = data.rawRequests || [];
    if (raws.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'explain-empty';
        empty.textContent = t('dash.explain.noRaw');
        el.appendChild(empty);
        return;
    }
    raws.forEach(r => {
        const entry = document.createElement('div');
        entry.className = 'raw-entry';
        const meta = document.createElement('div');
        meta.className = 'raw-meta';
        meta.textContent = `${String(r.ts).substring(11, 19)}  ${r.verb || ''} ${r.url || ''}`;
        const body = document.createElement('pre');
        body.className = 'raw-body';
        body.textContent = r.body || '';
        entry.append(meta, body);
        if (r.bodyTruncated) {
            const trunc = document.createElement('div');
            trunc.className = 'raw-truncated';
            trunc.textContent = t('dash.explain.truncated');
            entry.appendChild(trunc);
        }
        el.appendChild(entry);
    });
}

async function handleExplainAction(action, ip) {
    if (!action) return;
    if (state.explain.busy) return;
    if (action === 'close') {
        closeExplainPanel();
        return;
    }
    if (!ip) return;
    if (action === 'copy') {
        try {
            await navigator.clipboard.writeText(ip);
            showToast(t('dash.toast.ipCopied'), 'INFO');
        } catch (_) {
            showToast(t('dash.toast.copyFailed'), 'WARNING');
        }
        return;
    }

    state.explain.busy = true;
    try {
        let result = null;
        let label = '';
        switch (action) {
            case 'block-1h':
                result = await api(API.block, 'POST', { ip, duration: 3600, reason: 'Manual: Block 1h via Explain' });
                label = t('dash.explain.labelBlocked1h');
                break;
            case 'block-24h':
                result = await api(API.block, 'POST', { ip, duration: 86400, reason: 'Manual: Block 24h via Explain' });
                label = t('dash.explain.labelBlocked24h');
                break;
            case 'block-perm':


                result = await api(API.block, 'POST', { ip, duration: 31536000, reason: 'Manual: Permanent block via Explain' });
                label = t('dash.explain.labelBlockedPerm');
                break;
            case 'unblock':
                result = await api(API.unblock, 'POST', { ip });
                label = t('dash.explain.labelUnblocked');
                break;
            case 'allowlist':
                result = await api(API.allow, 'POST', { ip, reason: 'Manual allowlist via Explain' });
                label = t('dash.explain.labelAllowlisted');
                break;
            default:
                return;
        }
        if (checkAuth(result)) return;
        if (result === null) {
            showToast(t('dash.explain.actionNoResponse', { label }), 'CRITICAL');
            return;
        }
        if (result.success === false) {
            showToast(t('dash.explain.actionFailed', { label, message: result.message || '' }), 'WARNING');
            return;
        }
        showToast(label, 'INFO');

        await loadExplainData(ip);
        await loadSnapshot();
    } finally {
        state.explain.busy = false;
    }
}


const SPOTLIGHT_PAGE_ANCHORS = [
    { title: t('dash.section.telemetry'),      anchor: 'section-telemetry' },
    { title: t('dash.section.defenseMaster'),  anchor: 'section-defense-master' },
    { title: t('dash.section.defenseLayers'),  anchor: 'section-defense-layers' },
    { title: t('dash.section.intelligence'),   anchor: 'section-intelligence' },
    { title: t('dash.section.operations'),     anchor: 'section-operations' },
    { title: t('dash.section.controls'),       anchor: 'section-controls' },
    { title: t('dash.section.feed'),           anchor: 'section-feed' },
];

const SPOTLIGHT_ACTIONS = [
    { title: t('dash.spotlight.blockIp'),      run: () => { closeSpotlight(); document.getElementById('ip-input')?.focus(); } },
    { title: t('dash.spotlight.allowlistIp'),  run: () => { closeSpotlight(); document.getElementById('ip-input')?.focus(); } },
    { title: t('dash.spotlight.triggerPanic'), run: () => { closeSpotlight(); document.getElementById('btn-trigger-panic')?.click(); } },
    { title: t('dash.spotlight.liftPanic'),    run: () => { closeSpotlight(); document.getElementById('btn-lift-panic-ctrl')?.click(); } },
    { title: t('dash.feed.resetAll'),          run: () => { closeSpotlight(); document.getElementById('btn-reset-guard')?.click(); } },
    { title: t('dash.spotlight.clearIpLists'), run: () => { closeSpotlight(); document.getElementById('btn-clear-iplists')?.click(); } },
    { title: t('dash.spotlight.exportLogs'),   run: () => { closeSpotlight(); document.getElementById('btn-export-logs')?.click(); } },
    { title: t('dash.header.openEqualizer'),  run: () => { closeSpotlight(); window.open('/sentinel-config.html', '_blank', 'noopener'); } },
    { title: t('dash.spotlight.ackAllAlerts'), run: () => { closeSpotlight(); document.getElementById('btn-ack-all')?.click(); } },
    { title: t('dash.spotlight.clearAlerts'),  run: () => { closeSpotlight(); document.getElementById('btn-clear-alerts')?.click(); } },
    { title: t('dash.spotlight.toggleTheme'),  run: () => { closeSpotlight(); document.getElementById('btn-theme-toggle')?.click(); } },
    { title: t('dash.header.logout'),          run: () => { closeSpotlight(); document.getElementById('btn-logout')?.click(); } },
];


const SPOTLIGHT_GROUP_ORDER = ['Recent', 'Actions', 'IPs', 'URLs', 'Events', 'Alerts', 'Config', 'Pages'];

const SPOTLIGHT_GROUP_LABELS = {
    Recent:  t('dash.spotlight.groupRecent'),
    Actions: t('dash.spotlight.groupActions'),
    IPs:     t('dash.spotlight.groupIps'),
    URLs:    t('dash.spotlight.groupUrls'),
    Events:  t('dash.spotlight.groupEvents'),
    Alerts:  t('dash.spotlight.groupAlerts'),
    Config:  t('dash.spotlight.groupConfig'),
    Pages:   t('dash.spotlight.groupPages'),
    Other:   t('dash.spotlight.groupOther'),
};

const SPOTLIGHT_IP_STATUS_LABELS = {
    blocked:  t('dash.spotlight.statusBlocked'),
    allowed:  t('dash.spotlight.statusAllowed'),
    honeypot: t('dash.spotlight.statusHoneypot'),
    seen:     t('dash.spotlight.statusSeen'),
};


const SPOTLIGHT_IP_RE = /\b(?:\d{1,3}\.){3}\d{1,3}\b|\banon:[0-9a-f]+\b/g;


const SPOTLIGHT_URL_RE = /\s(\/[A-Za-z0-9_\-./?=&%+#:]*)/g;


function flattenConfig(obj, prefix = '', out = []) {
    if (!obj || typeof obj !== 'object') return out;
    for (const [k, v] of Object.entries(obj)) {
        const key = prefix ? `${prefix}.${k}` : k;
        if (v && typeof v === 'object' && !Array.isArray(v)) {
            flattenConfig(v, key, out);
        } else {
            out.push({ key, value: v });
        }
    }
    return out;
}

function buildSpotlightIndex() {
    const items = [];


    SPOTLIGHT_ACTIONS.forEach(a => {
        items.push({ group: 'Actions', title: a.title, action: a.run, icon: '⚡' });
    });


    SPOTLIGHT_PAGE_ANCHORS.forEach(p => {
        items.push({
            group: 'Pages',
            title: p.title,
            icon: '☷',
            action: () => {
                closeSpotlight();
                document.getElementById(p.anchor)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
            },
        });
    });


    const ipMap = new Map();
    const addIP = (rawIp, status) => {
        if (!rawIp) return;
        const ip = String(rawIp);
        if (ipMap.has(ip)) {
            if (status && ipMap.get(ip).status !== 'blocked') ipMap.set(ip, { status });
        } else {
            ipMap.set(ip, { status });
        }
    };

    const snap = lastDashboardData || {};
    (snap.blocklist || []).forEach(b => addIP(b.ip, 'blocked'));
    (snap.blacklist || []).forEach(b => addIP(b.ip, 'blocked'));
    (snap.allowlist || []).forEach(a => addIP(a.ip || a, 'allowed'));
    lastHoneypotHits.forEach(h => addIP(h.ip, 'honeypot'));

    state.logLines.forEach(({ text }) => {
        const matches = String(text).match(SPOTLIGHT_IP_RE);
        if (matches) matches.forEach(m => addIP(m, 'seen'));
    });

    ipMap.forEach(({ status }, ip) => {
        items.push({
            group: 'IPs',
            title: ip,
            meta: SPOTLIGHT_IP_STATUS_LABELS[status] || status,
            icon: '◉',
            action: () => { closeSpotlight(); openExplainPanel(ip); },
        });
    });


    const urlFreq = new Map();
    state.logLines.forEach(({ text }) => {
        const s = ' ' + String(text);
        let m;
        const re = new RegExp(SPOTLIGHT_URL_RE.source, 'g');
        while ((m = re.exec(s)) !== null) {
            const url = m[1];
            if (!url || url.length < 2) continue;
            urlFreq.set(url, (urlFreq.get(url) || 0) + 1);
        }
    });
    const topUrls = [...urlFreq.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 30);
    topUrls.forEach(([url, count]) => {
        items.push({
            group: 'URLs',
            title: url,
            meta: t('dash.spotlight.inFeed', { n: count }),
            icon: '⬡',
            action: () => { closeSpotlight(); flashLogLinesMatchingURL(url); },
        });
    });


    const recentLines = state.logLines.slice(-80);
    recentLines.forEach((line, idx) => {
        const text = String(line.text || '');
        const absoluteIdx = state.logLines.length - recentLines.length + idx;
        items.push({
            group: 'Events',
            title: text.slice(0, 80),
            meta: line.cls || '',
            icon: '·',
            sortKey: absoluteIdx,
            action: () => { closeSpotlight(); flashLogLineByIndex(absoluteIdx); },
        });
    });


    lastAlerts.forEach(a => {
        const sev = (a.severity || 'INFO').toUpperCase();
        items.push({
            group: 'Alerts',
            title: `[${sev}] ${a.title || ''}`,
            meta: fmtTs(a.timestamp).slice(11, 19),
            icon: '▲',
            action: () => { closeSpotlight(); flashAlertById(a.id); },
        });
    });


    const cfgRoots = ['defenses', 'blitzPolicy', 'rlPolicy', 'wafPolicy',
                      'rateLimiting', 'monitoring', 'security', 'validation',
                      'panic', 'sonar', 'honeypotPolicy'];
    cfgRoots.forEach(rootKey => {
        if (snap[rootKey] && typeof snap[rootKey] === 'object') {
            const flat = flattenConfig(snap[rootKey], rootKey);
            flat.forEach(({ key, value }) => {
                items.push({
                    group: 'Config',
                    title: key,
                    meta: String(value),
                    icon: '⚙',
                    action: () => {
                        closeSpotlight();
                        window.open('/sentinel-config.html#' + encodeURIComponent(key), '_blank', 'noopener');
                    },
                });
            });
        }
    });

    return items;
}


function fuzzyMatch(query, candidate) {
    if (!query) return 1;
    const q = String(query).toLowerCase();
    const c = String(candidate).toLowerCase();
    let qi = 0, score = 0, prevMatchIdx = -1, prefixBonus = 0;
    for (let ci = 0; ci < c.length && qi < q.length; ci++) {
        if (c[ci] === q[qi]) {
            if (qi === 0 && ci === 0) prefixBonus = 10;
            if (prevMatchIdx === ci - 1) score += 3;
            else score += 1;
            prevMatchIdx = ci;
            qi++;
        }
    }
    if (qi < q.length) return 0;
    return score + prefixBonus;
}

function filterSpotlight(query) {
    const index = buildSpotlightIndex();
    const q = String(query || '').trim();


    if (!q) {
        const recent = [];

        const snap = lastDashboardData || {};
        const bl = (snap.blocklist || snap.blacklist || []).slice(0, 10);
        bl.forEach(b => {
            const ip = b.ip;
            if (!ip) return;
            recent.push({
                group: 'Recent',
                title: ip,
                meta: SPOTLIGHT_IP_STATUS_LABELS.blocked,
                icon: '◉',
                action: () => { closeSpotlight(); openExplainPanel(ip); },
            });
        });

        const last5 = state.logLines.slice(-5).reverse();
        last5.forEach((line, idx) => {
            const text = String(line.text || '');
            const absoluteIdx = state.logLines.length - 1 - idx;
            recent.push({
                group: 'Recent',
                title: text.slice(0, 80),
                meta: line.cls || '',
                icon: '·',
                action: () => { closeSpotlight(); flashLogLineByIndex(absoluteIdx); },
            });
        });
        return recent;
    }


    const scored = [];
    for (const item of index) {
        const titleScore = fuzzyMatch(q, item.title || '');
        const metaScore = item.meta ? fuzzyMatch(q, String(item.meta)) * 0.5 : 0;
        const score = Math.max(titleScore, metaScore);
        if (score > 0) scored.push({ item, score });
    }


    const byGroup = {};
    scored.forEach(({ item, score }) => {
        const g = item.group || 'Other';
        (byGroup[g] = byGroup[g] || []).push({ item, score });
    });
    const out = [];
    SPOTLIGHT_GROUP_ORDER.forEach(g => {
        const list = byGroup[g];
        if (!list || list.length === 0) return;
        list.sort((a, b) => b.score - a.score || String(a.item.title).localeCompare(String(b.item.title)));
        list.slice(0, 8).forEach(({ item }) => out.push(item));
    });
    return out;
}

function renderSpotlightResults() {
    const container = document.getElementById('spotlight-results');
    if (!container) return;
    container.innerHTML = '';

    const results = state.spotlight.results || [];
    if (results.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'sr-empty';
        empty.textContent = state.spotlight.query
            ? t('dash.spotlight.noMatches')
            : t('dash.spotlight.typeToSearch');
        container.appendChild(empty);
        return;
    }

    let lastGroup = null;
    results.forEach((item, idx) => {
        if (item.group !== lastGroup) {
            const label = document.createElement('div');
            label.className = 'sr-group-label';
            label.textContent = SPOTLIGHT_GROUP_LABELS[item.group || 'Other'] || item.group;
            container.appendChild(label);
            lastGroup = item.group;
        }
        const row = document.createElement('div');
        row.className = 'sr-row' + (idx === state.spotlight.selectedIndex ? ' selected' : '');
        row.dataset.spotlightIdx = String(idx);

        const icon = document.createElement('span');
        icon.className = 'sr-icon';
        icon.textContent = item.icon || '·';

        const title = document.createElement('span');
        title.className = 'sr-title';
        title.textContent = item.title || '—';

        row.append(icon, title);

        if (item.meta) {
            const meta = document.createElement('span');
            meta.className = 'sr-meta';
            meta.textContent = String(item.meta);
            row.appendChild(meta);
        }
        container.appendChild(row);
    });
}


function flashLogLineByIndex(idx) {
    const body = document.getElementById('log-body');
    if (!body) return;
    const rows = body.querySelectorAll('.log-line');
    const row = rows[idx];
    if (!row) return;
    row.scrollIntoView({ behavior: 'smooth', block: 'center' });
    row.classList.remove('flash');

    void row.offsetWidth;
    row.classList.add('flash');
}


function flashLogLinesMatchingURL(url) {
    const body = document.getElementById('log-body');
    if (!body) return;
    const rows = Array.from(body.querySelectorAll('.log-line'));
    for (let i = rows.length - 1; i >= 0; i--) {
        if (rows[i].textContent.includes(url)) {
            rows[i].scrollIntoView({ behavior: 'smooth', block: 'center' });
            rows[i].classList.remove('flash');
            void rows[i].offsetWidth;
            rows[i].classList.add('flash');
            return;
        }
    }
}


function flashAlertById(id) {
    const list = document.getElementById('alerts-list');
    if (!list) return;
    const row = list.querySelector(`.alert-row[data-alert-id="${CSS.escape(String(id))}"]`);
    if (!row) return;
    row.scrollIntoView({ behavior: 'smooth', block: 'center' });
    row.classList.remove('flash');
    void row.offsetWidth;
    row.classList.add('flash');
}

function openSpotlight() {

    if (state.spotlight.open) {
        closeSpotlight();
        return;
    }
    const overlay = document.getElementById('spotlight');
    if (!overlay) return;
    overlay.classList.remove('hidden');
    overlay.setAttribute('aria-hidden', 'false');
    state.spotlight.open = true;
    state.spotlight.query = '';
    state.spotlight.selectedIndex = 0;
    state.spotlight.results = filterSpotlight('');
    const input = document.getElementById('spotlight-input');
    if (input) {
        input.value = '';


        setTimeout(() => input.focus(), 0);
    }
    renderSpotlightResults();
}

function closeSpotlight() {
    const overlay = document.getElementById('spotlight');
    if (!overlay) return;
    overlay.classList.add('hidden');
    overlay.setAttribute('aria-hidden', 'true');
    const input = document.getElementById('spotlight-input');
    if (input) input.value = '';
    state.spotlight.open = false;
    state.spotlight.query = '';
    state.spotlight.results = [];
    state.spotlight.selectedIndex = 0;
}

let _spotlightFrame = null;
function handleSpotlightInput(e) {
    const value = e.target.value;
    state.spotlight.query = value;
    if (_spotlightFrame) cancelAnimationFrame(_spotlightFrame);
    _spotlightFrame = requestAnimationFrame(() => {
        state.spotlight.results = filterSpotlight(value);
        state.spotlight.selectedIndex = 0;
        renderSpotlightResults();
    });
}

function handleSpotlightKeyboard(e) {
    const len = state.spotlight.results.length;
    if (e.key === 'ArrowDown') {
        if (len > 0) {
            state.spotlight.selectedIndex = (state.spotlight.selectedIndex + 1) % len;
            renderSpotlightResults();

            const sel = document.querySelector('#spotlight-results .sr-row.selected');
            sel?.scrollIntoView({ block: 'nearest' });
        }
        e.preventDefault();
        return;
    }
    if (e.key === 'ArrowUp') {
        if (len > 0) {
            state.spotlight.selectedIndex = (state.spotlight.selectedIndex - 1 + len) % len;
            renderSpotlightResults();
            const sel = document.querySelector('#spotlight-results .sr-row.selected');
            sel?.scrollIntoView({ block: 'nearest' });
        }
        e.preventDefault();
        return;
    }
    if (e.key === 'Enter') {
        if (state.spotlight.busy) return;
        const item = state.spotlight.results[state.spotlight.selectedIndex];
        if (item && typeof item.action === 'function') {
            state.spotlight.busy = true;
            try { item.action(); }
            finally { setTimeout(() => { state.spotlight.busy = false; }, 200); }
        }
        e.preventDefault();
        return;
    }
    if (e.key === 'Escape') {
        closeSpotlight();

        e.stopPropagation();
        e.preventDefault();
        return;
    }
}

function bindSpotlightControls() {
    const input = document.getElementById('spotlight-input');
    if (input && !input.dataset.spotBound) {
        input.addEventListener('input', handleSpotlightInput);
        input.addEventListener('keydown', handleSpotlightKeyboard);
        input.dataset.spotBound = '1';
    }

    const results = document.getElementById('spotlight-results');
    if (results && !results.dataset.spotBound) {
        results.addEventListener('click', (e) => {
            const row = e.target.closest('.sr-row[data-spotlight-idx]');
            if (!row) return;
            const idx = parseInt(row.dataset.spotlightIdx, 10);
            const item = state.spotlight.results[idx];
            if (item?.action) {
                state.spotlight.selectedIndex = idx;
                item.action();
            }
        });
        results.dataset.spotBound = '1';
    }

    const backdrop = document.querySelector('#spotlight .spotlight-backdrop');
    if (backdrop && !backdrop.dataset.spotBound) {
        backdrop.addEventListener('click', closeSpotlight);
        backdrop.dataset.spotBound = '1';
    }


    if (!document.body.dataset.spotKbBound) {
        document.addEventListener('keydown', (e) => {
            if (!state.authenticated) return;
            if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
                e.preventDefault();
                if (state.spotlight.open) closeSpotlight();
                else openSpotlight();
                return;
            }
            if (e.key === '/' && !state.spotlight.open
                && !e.target.matches('input,textarea,select,[contenteditable]')) {
                e.preventDefault();
                openSpotlight();
            }
        }, true);
        document.body.dataset.spotKbBound = '1';
    }
}


function bindEvents() {

    $('login-btn')?.addEventListener('click', doLogin);
    $('login-passphrase')?.addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });
    $('btn-logout')?.addEventListener('click', doLogout);
    $('btn-generate-passphrase')?.addEventListener('click', handleGeneratePassphrase);
    $('btn-copy-passphrase')   ?.addEventListener('click', handleCopyPassphrase);
    $('btn-lift-panic')?.addEventListener('click', handleLiftPanic);


    document.querySelectorAll('.toggle-btn').forEach(btn => {
        btn.addEventListener('click', () => handleToggle(btn.dataset.layer));
    });


    $('btn-block-ip')      ?.addEventListener('click', handleBlockIP);
    $('btn-unblock-ip')    ?.addEventListener('click', handleUnblockIP);
    $('btn-allow-ip')      ?.addEventListener('click', handleAllowIP);
    $('btn-clear-iplists') ?.addEventListener('click', handleClearIPLists);
    $('ip-input')          ?.addEventListener('keydown', e => { if (e.key === 'Enter') handleBlockIP(); });


    $('btn-ack-all')     ?.addEventListener('click', handleAckAll);
    $('btn-clear-alerts')?.addEventListener('click', handleClearAlerts);


    $('btn-trigger-panic') ?.addEventListener('click', handleTriggerPanic);
    $('btn-lift-panic-ctrl')?.addEventListener('click', handleLiftPanic);


    $('btn-launch-attack')?.addEventListener('click', handleLaunchAttack);


    $('btn-autoscroll')  ?.addEventListener('click', handleAutoScroll);
    $('btn-export-logs') ?.addEventListener('click', handleExportLogs);
    $('btn-reset-guard') ?.addEventListener('click', handleResetGuard);


    $('btn-refresh-workers')?.addEventListener('click', refreshWorkers);


    ['btn-open-equalizer', 'btn-open-equalizer-header'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.addEventListener('click', () => window.open('/sentinel-config.html', '_blank', 'noopener'));
    });


    $('explain-backdrop')?.addEventListener('click', closeExplainPanel);

    document.querySelectorAll('[data-explain-action]').forEach(btn => {
        btn.addEventListener('click', () => handleExplainAction(btn.dataset.explainAction, state.explain.ip));
    });


    $('log-body')?.addEventListener('click', e => {
        const ip = e.target?.dataset?.ip;
        if (ip) openExplainPanel(ip);
    });


    document.addEventListener('keydown', e => {
        if (e.key === 'Escape' && state.explain.open) {
            closeExplainPanel();
        }
    });


    bindSpotlightControls();


    bindDensityControls();
    bindPanelCollapseControls();
    document.addEventListener('keydown', handleDensityKeyboard);
}


const DENSITY_VALUES = ['compact', 'default', 'roomy'];


const COLLAPSIBLE_SECTIONS = [
    'section-telemetry',
    'section-defense-master',
    'section-defense-layers',
    'section-intelligence',
    'section-operations',
    'section-controls',
    'section-feed',
];

function applyDensity(level) {
    if (!DENSITY_VALUES.includes(level)) level = 'default';
    document.documentElement.setAttribute('data-density', level);
    try { localStorage.setItem('sentinel-density', level); } catch (_) {}
    document.querySelectorAll('.density-btn').forEach(btn => {
        const match = btn.dataset.density === level;
        btn.setAttribute('aria-checked', match ? 'true' : 'false');
    });


    if (typeof rerenderLogFeed === 'function') {
        rerenderLogFeed();
    }
}

function bindDensityControls() {
    document.querySelectorAll('.density-btn').forEach(btn => {
        if (btn.dataset.densityBound) return;
        btn.addEventListener('click', () => applyDensity(btn.dataset.density));
        btn.dataset.densityBound = '1';
    });

    applyDensity(document.documentElement.getAttribute('data-density') || 'default');
}


function getCollapsedState() {
    try {
        return JSON.parse(localStorage.getItem('sentinel-collapsed') || '{}');
    } catch (_) {
        return {};
    }
}

function setCollapsedState(s) {
    try { localStorage.setItem('sentinel-collapsed', JSON.stringify(s)); } catch (_) {}
}

function applyCollapsedState() {
    const s = getCollapsedState();
    COLLAPSIBLE_SECTIONS.forEach(id => {
        const el = document.getElementById(id);
        if (!el) return;
        el.classList.toggle('collapsed', !!s[id]);
    });
}

function togglePanelCollapse(sectionId) {
    const el = document.getElementById(sectionId);
    if (!el) return;
    const s = getCollapsedState();
    s[sectionId] = !s[sectionId];
    setCollapsedState(s);
    el.classList.toggle('collapsed', s[sectionId]);
}

function collapseAll() {
    const s = {};
    COLLAPSIBLE_SECTIONS.forEach(id => { s[id] = true; });
    setCollapsedState(s);
    applyCollapsedState();
}

function expandAll() {
    setCollapsedState({});
    applyCollapsedState();
}

function bindPanelCollapseControls() {
    COLLAPSIBLE_SECTIONS.forEach(id => {
        const el = document.getElementById(id);
        if (!el || el.dataset.collapseBound) return;
        el.addEventListener('click', () => togglePanelCollapse(id));
        el.dataset.collapseBound = '1';
    });
    applyCollapsedState();
}


function handleDensityKeyboard(e) {


    const tgt = e.target;
    if (tgt && tgt.matches && tgt.matches('input, textarea, select, [contenteditable]')) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;


    if (!e.shiftKey) return;

    switch (e.key) {
        case 'J':
        case 'j':
            collapseAll();
            e.preventDefault();
            break;
        case 'L':
        case 'l':
            expandAll();
            e.preventDefault();
            break;
        case 'K':
        case 'k': {


            const feed = document.getElementById('section-feed');
            if (!feed) return;
            const s = getCollapsedState();
            const isolated = COLLAPSIBLE_SECTIONS.every(id =>
                id === 'section-feed' ? !s[id] : !!s[id]);
            if (isolated) {
                expandAll();
            } else {
                const newS = {};
                COLLAPSIBLE_SECTIONS.forEach(id => {
                    newS[id] = (id !== 'section-feed');
                });
                setCollapsedState(newS);
                applyCollapsedState();
                feed.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
            e.preventDefault();
            break;
        }
    }
}


async function boot() {
    bindEvents();


    const authData = await api(API.authStatus);

    if (authData && authData.authenticated === true) {
        state.authenticated = true;
        await loadSnapshot();
        startPolling();
    } else {
        window.location.replace('/sentinel.html?reason=expired');
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
} else {
    boot();
}
