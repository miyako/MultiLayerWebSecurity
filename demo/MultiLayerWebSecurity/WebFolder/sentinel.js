

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

    snapshotRange:     '/api/dashboard/snapshots/range',
    snapshotAt:        '/api/dashboard/snapshots/at',
    snapshotIntensity: '/api/dashboard/snapshots/intensity',
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

    timeTravel: {
        viewingTime: false,
        minuteKey: null,
        playing: false,
        playSpeed: 1,
        playTimer: null,
        intensityBuckets: [],
        bucketsLoadedAt: 0,
        intensityTimer: null,
        dragging: false,
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
    if (s >= 86400) return `${Math.floor(s/86400)}d ${Math.floor((s%86400)/3600)}h`;
    if (s >= 3600)  return `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m`;
    if (s >= 60)    return `${Math.floor(s/60)}m ${s%60}s`;
    return `${s}s`;
}

function fmtTs(ts) {
    if (!ts) return '—';
    return ts.replace('T', ' ').substring(0, 19);
}

function numFmt(n) {
    return typeof n === 'number' ? n.toLocaleString() : (n ?? '—');
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
    console.warn('[Sentinel] Session expired or privilege revoked — showing login');
    stopPolling();
    state.authenticated = false;
    showLogin('Session expired. Please authenticate again.');
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
        showLogin('Authentication failed. Check your passphrase.');
        return;
    }

    if (!result || result.success !== true) {
        showLogin('Authentication error. Try again.');
        return;
    }


    clearDpgDisplay();
    state.authenticated = true;
    showDashboard();
    await loadSnapshot();
    startPolling();

    initTimeTravel().catch(err => console.warn('[Sentinel] initTimeTravel failed:', err));
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
    if (ttlEl) ttlEl.textContent = 'expires in 5:00';
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
                title: 'Generate failed',
                message: 'Could not reach the server. Try again in a moment.',
            });
            return;
        }
        if (r.success === false) {
            const msg = r.retryAfterSec
                ? `Too many generations — wait ${r.retryAfterSec}s.`
                : (r.message || 'Generation refused.');
            showAlertToast({
                id: -Date.now(),
                severity: 'WARNING',
                title: 'Generate refused',
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
        ttlEl.textContent = 'expired';
        ttlEl.classList.add('expired');
        clearDpgDisplay();
        return;
    }
    const sec = Math.floor(remainingMs / 1000);
    const m   = Math.floor(sec / 60);
    const s   = sec % 60;
    ttlEl.textContent = `expires in ${m}:${String(s).padStart(2, '0')}`;
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
            title: 'Copy failed',
            message: 'Clipboard access denied. Code is still visible above.',
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
            $('panic-label').textContent  = 'CPU PANIC ACTIVE';
            $('panic-reason').textContent = 'CPU saturation — rejecting non-allowlisted traffic';
            $('panic-timer').textContent  = panicState.cpuPanicSecondsRemaining + 's';
        } else {
            $('panic-label').textContent  = 'PANIC MODE ACTIVE';
            $('panic-reason').textContent = panicState.reason || '';
            $('panic-timer').textContent  = panicState.secondsRemaining + 's';
        }
    } else {
        banner.classList.add('hidden');
    }
}

function updateThreatBadge(d, opts = {}) {
    const badge = $('threat-badge');
    if (!badge) return;
    let level = 'NORMAL', cls = 'threat-normal';
    if (d.panicState && (d.panicState.active || d.panicState.cpuPanicActive)) {
        level = 'PANIC'; cls = 'threat-critical';
    } else if (d.alertSummary && d.alertSummary.critical > 0) {
        level = 'CRITICAL'; cls = 'threat-critical';
    } else if (d.alertSummary && d.alertSummary.warning > 0) {
        level = 'ELEVATED'; cls = 'threat-elevated';
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

function updateCPU(d, opts = {}) {
    const cpu = typeof d.cpu === 'number' ? d.cpu : parseFloat(d.cpu) || 0;


    if (!opts.historical) {
        state.cpuHistory.push(cpu);
        if (state.cpuHistory.length > GRAPH_SAMPLES) state.cpuHistory.shift();
    }
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

function updateRate(d, opts = {}) {
    const rate = typeof d.currentRate === 'number' ? d.currentRate : 0;

    if (!opts.historical) {
        state.rateHistory.push(rate);
        if (state.rateHistory.length > GRAPH_SAMPLES) state.rateHistory.shift();
    }
    setText('rate-val', numFmt(rate) + ' req/min');
    drawGraph('rate-canvas', state.rateHistory, null,
        'rgba(46,160,67,0.9)', 'rgba(46,160,67,0.15)');
}

function updateToggles(d, opts = {}) {


    const masterOn = d.master !== false;


    const masterBtn = $('tog-master');
    if (masterBtn) {
        masterBtn.dataset.state = masterOn ? 'true' : 'false';
        masterBtn.textContent   = masterOn ? 'ENGAGED' : 'DISENGAGED';
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
            btn.textContent   = on ? 'ENGAGED' : 'DISENGAGED';
            btn.disabled      = false;
            btn.removeAttribute('aria-disabled');
            btn.title         = '';
        } else {

            btn.dataset.state = 'false';
            btn.textContent   = 'DISENGAGED';
            btn.disabled      = true;
            btn.setAttribute('aria-disabled', 'true');
            btn.title         = 'Master Switch is OFF — re-engage the Master Switch first to manage individual defense layers.';
        }
    }


    const masterCard = $('dcard-master');
    const masterLine = $('master-status-line');
    if (masterCard && masterLine) {
        if (masterOn) {
            masterCard.style.borderColor = '';
            masterCard.style.boxShadow   = '';
            masterLine.style.color       = 'var(--text-secondary)';
            masterLine.textContent       = 'All defenses active — including Panic Mode fail-safe. Per-layer toggles below operate normally.';
        } else {
            masterCard.style.borderColor = 'var(--red, #ff3b30)';
            masterCard.style.boxShadow   = '0 0 0 1px rgba(255,59,48,0.35), 0 0 18px rgba(255,59,48,0.2)';
            masterLine.style.color       = 'var(--red, #ff3b30)';
            masterLine.textContent       = 'Master OFF — every defense bypassed, INCLUDING Panic Mode. Panic indicator on dashboard may show active (workers still monitor) but no blocks are applied.';
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
    if (blocklist.length === 0) { body.textContent = 'No blocked IPs.'; return; }
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
    const data = await api(API.snapshot);
    if (checkAuth(data)) return;
    if (!data || !data.recentAlerts) return;

    lastAlerts = data.recentAlerts;
    if (data) lastDashboardData = data;
    const list = $('alerts-list');
    if (!list) return;
    list.innerHTML = '';
    const alerts = [...data.recentAlerts].reverse().slice(0, 30);
    if (alerts.length === 0) { list.textContent = 'No alerts.'; return; }
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
        meta.textContent = fmtTs(a.timestamp) + (a.acknowledged ? ' — acked' : '');
        row.append(title, msg, meta);
        row.addEventListener('click', () => ackAlert(a.id));
        list.appendChild(row);
    });


    const fresh = [...data.recentAlerts].filter(a =>
        typeof a.id === 'number'
        && a.id > state.highestSeenAlertId
        && !a.acknowledged
        && (a.severity === 'WARNING' || a.severity === 'CRITICAL')
    );
    if (fresh.length > 0) {

        fresh.slice(-4).forEach(showAlertToast);
    }


    const maxId = data.recentAlerts.reduce((m, a) => Math.max(m, a.id || 0), 0);
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
    hint.textContent = sev === 'critical' ? 'Click to acknowledge' : 'Auto-dismiss in 5s · click to ack';

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
        beats.textContent = `${w.beatCount} beats`;
        const ago   = document.createElement('span');
        ago.className   = 'worker-ago';
        ago.textContent = `${w.lastBeatAgoSec}s ago`;
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
    if (data.hits.length === 0) { list.textContent = 'No hits recorded.'; return; }
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


function wrapIPsInLogLine(text) {
    const escaped = escapeHTML(text);
    return escaped.replace(LOG_IP_REGEX, m => {

        return `<span class="log-ip clickable" data-ip="${m}">${m}</span>`;
    });
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


        el.innerHTML = wrapIPsInLogLine(text);
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


        if (state.timeTravel?.viewingTime) {
            state.pollTimer = setTimeout(tick, pollIntervalFor(POLL_INTERVAL_MS));
            return;
        }
        const d = await api(API.status);
        if (checkAuth(d)) return;
        if (d) {
            updateStats(d);
            updateCPU(d);
            updateRate(d);
            updateToggles(d);
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
    if (data.recentAlerts) await loadAlerts();
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
                title: 'Master Switch is OFF',
                message: 'Re-engage the Master Switch to manage individual defense layers.',
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
        const ok = confirm(
            'DISENGAGE Global Defense Master?\n\n' +
            'Every defense layer will be bypassed:\n' +
            '  • CPU panic + general panic mode\n' +
            '  • Header validation, IP blocklist/allowlist\n' +
            '  • Honeypot, WAF, per-IP & global rate limits\n' +
            '  • Sonar IDS scoring + sniper/drone queues\n\n' +
            'State is preserved (blocklist, allowlist, alerts, sessions, telemetry, ' +
            'honeypot lists). The system will process UNMITIGATED traffic until you ' +
            're-engage the master.\n\n' +
            'Continue?'
        );
        if (!ok) return;
    }

    const r = await api(url + `?enabled=${next}`, 'POST');
    if (checkAuth(r)) return;
    btn.dataset.state = next ? 'true' : 'false';
    btn.textContent   = next ? 'ENGAGED' : 'DISENGAGED';


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
    if (statusEl) { statusEl.classList.remove('hidden'); statusEl.textContent = `Launching ${vector}…`; }
    const data = await api(url, 'POST', {});
    if (checkAuth(data)) return;
    if (statusEl) {
        statusEl.textContent = data
            ? `✓ ${data.message || 'Attack launched'}`
            : '✗ Launch failed — check system log';
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
    if (!confirm('Reset ALL protection state? This clears stats, blocklist, logs, alerts, and honeypot hits.')) return;
    const r = await api(API.resetGuard, 'POST', {});
    if (checkAuth(r)) return;
    state.logLines = []; state.cpuHistory = []; state.rateHistory = [];
    await loadSnapshot();
}

async function handleClearIPLists() {
    const ok = confirm(
        'Clear ALL IP lists?\n\n' +
        'This resets blocklist, allowlist, and strikes inside Data/ip_lists.json ' +
        '(the file and its top-level structure are preserved).\n\n' +
        'Note: clearing the allowlist removes any localhost protection entry ' +
        '(e.g. 127.0.0.1) — re-add it manually if needed after the test run.'
    );
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
                title: 'Clear All failed',
                message: 'Backend did not respond. Check server logs.',
            });
            return;
        }
        if (r.success === false) {
            showAlertToast({
                id: -Date.now(),
                severity: 'CRITICAL',
                title: 'Clear All failed',
                message: r.message || 'Disk save failed — ip_lists.json may still hold stale data.',
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
    if (btn) btn.textContent = `AUTO ↓: ${state.autoScroll ? 'ON' : 'OFF'}`;
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
    setText('explain-geo', ip.startsWith('anon:') ? 'header-derived anon client' : 'geo: —');
    const statusEl = $('explain-status');
    if (statusEl) statusEl.textContent = 'Loading…';
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
        if (statusEl) statusEl.textContent = 'Failed to load — check connection.';
        return;
    }
    if (state.explain.ip !== ip) return;
    if (checkAuth(data)) return;
    if (data === null) {
        const statusEl = $('explain-status');
        if (statusEl) statusEl.textContent = 'Backend did not respond.';
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
    setText('explain-geo', isAnon ? 'header-derived anon client' : 'geo: —');


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
        el.textContent = `Allowlisted — exempt from all blocks.`;
        return;
    }
    if (s.blocked) {
        if (s.permanent) {
            el.textContent = `BLOCKED — permanent (${s.strikes}/${s.permanentThreshold} strikes).`;
        } else {
            const rem = Number(s.expirySec || 0);
            const mins = Math.floor(rem / 60);
            const secs = rem % 60;
            el.textContent = `BLOCKED — ${mins}m${secs}s remaining (${s.strikes}/${s.permanentThreshold} strikes).`;
        }
        return;
    }
    if ((s.strikes || 0) > 0) {
        el.textContent = `Clean — ${s.strikes}/${s.permanentThreshold} strike(s) on record.`;
    } else {
        el.textContent = 'Clean — no strikes, not blocked.';
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
        empty.textContent = 'No requests recorded in current ring buffer.';
        el.appendChild(empty);
        return;
    }

    const totals = document.createElement('div');
    totals.className = 'summary-row';
    totals.innerHTML = `<span>Requests</span><strong>${sum.totalRequests}</strong>`;
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
        fs.innerHTML = `<span>First seen</span><strong>${escapeHTML(fmtTs(sum.firstSeen))}</strong>`;
        el.appendChild(fs);
    }
    if (sum.lastSeen) {
        const ls = document.createElement('div');
        ls.className = 'summary-row';
        ls.innerHTML = `<span>Last seen</span><strong>${escapeHTML(fmtTs(sum.lastSeen))}</strong>`;
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
        empty.textContent = 'No activity recorded.';
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
        empty.textContent = 'No raw bodies captured for this IP.';
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
            trunc.textContent = '(truncated at 2 KB)';
            entry.appendChild(trunc);
        }
        el.appendChild(entry);
    });
}

async function handleExplainAction(action, ip) {
    if (!action) return;


    if (state.timeTravel?.viewingTime) {
        showToast('Exit time-travel to act', 'WARNING');
        return;
    }
    if (state.explain.busy) return;
    if (action === 'close') {
        closeExplainPanel();
        return;
    }
    if (!ip) return;
    if (action === 'copy') {
        try {
            await navigator.clipboard.writeText(ip);
            showToast('IP copied', 'INFO');
        } catch (_) {
            showToast('Copy failed', 'WARNING');
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
                label = 'Blocked 1h';
                break;
            case 'block-24h':
                result = await api(API.block, 'POST', { ip, duration: 86400, reason: 'Manual: Block 24h via Explain' });
                label = 'Blocked 24h';
                break;
            case 'block-perm':


                result = await api(API.block, 'POST', { ip, duration: 31536000, reason: 'Manual: Permanent block via Explain' });
                label = 'Blocked (permanent)';
                break;
            case 'unblock':
                result = await api(API.unblock, 'POST', { ip });
                label = 'Unblocked';
                break;
            case 'allowlist':
                result = await api(API.allow, 'POST', { ip, reason: 'Manual allowlist via Explain' });
                label = 'Allowlisted';
                break;
            default:
                return;
        }
        if (checkAuth(result)) return;
        if (result === null) {
            showToast(`${label} — backend did not respond`, 'CRITICAL');
            return;
        }
        if (result.success === false) {
            showToast(`${label} failed: ${result.message || ''}`, 'WARNING');
            return;
        }
        showToast(label, 'INFO');

        await loadExplainData(ip);
        await loadSnapshot();
    } finally {
        state.explain.busy = false;
    }
}


const TT_DISABLED_BUTTON_IDS = [
    'btn-block-ip', 'btn-unblock-ip', 'btn-allow-ip',
    'btn-clear-iplists', 'btn-trigger-panic', 'btn-lift-panic',
    'btn-lift-panic-ctrl', 'btn-reset-guard', 'btn-launch-attack',
];

function ttApplyDisabledClass(on) {
    TT_DISABLED_BUTTON_IDS.forEach(id => {
        const el = $(id);
        if (!el) return;
        el.classList.toggle('tt-disabled', on);
        if (on) el.setAttribute('title', 'Disabled while viewing time. Press B to return to live.');
    });

    const mutatingExplainActions = ['block-1h', 'block-24h', 'block-perm', 'unblock', 'allowlist'];
    mutatingExplainActions.forEach(action => {
        const btn = document.querySelector(`[data-explain-action="${action}"]`);
        if (!btn) return;
        btn.classList.toggle('tt-disabled', on);
        if (on) btn.setAttribute('title', 'Disabled while viewing time. Press B to return to live.');
    });
}

async function initTimeTravel() {


    await loadIntensityBuckets();
    drawIntensityCanvas();
    bindTimeTravelControls();


    if (state.timeTravel.intensityTimer) clearInterval(state.timeTravel.intensityTimer);
    state.timeTravel.intensityTimer = setInterval(async () => {
        if (!state.authenticated || document.hidden) return;
        await loadIntensityBuckets();
        drawIntensityCanvas();
    }, 5 * 60 * 1000);
}

async function loadIntensityBuckets() {
    const data = await api(API.snapshotIntensity);
    if (checkAuth(data)) return;
    if (!data) return;
    state.timeTravel.intensityBuckets = Array.isArray(data.buckets) ? data.buckets : [];
    state.timeTravel.bucketsLoadedAt = Date.now();
}

function drawIntensityCanvas() {
    const canvas = $('tt-intensity');
    if (!canvas) return;
    const track = $('tt-track');


    if (track) {
        const w = track.clientWidth || canvas.width;
        if (canvas.width !== w) canvas.width = w;
    }
    const ctx = canvas.getContext('2d');
    const W = canvas.width;
    const H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    const buckets = state.timeTravel.intensityBuckets || [];
    const SLOTS = 1440;
    const barW = W / SLOTS;


    const startSlot = SLOTS - buckets.length;


    ctx.fillStyle = 'rgba(255,255,255,0.04)';
    ctx.fillRect(0, 0, W, H);

    for (let i = 0; i < buckets.length; i++) {
        const b = buckets[i];
        if (!b) continue;
        const slot = startSlot + i;
        const x = slot * barW;
        const intensity = Math.max(0, Math.min(100, Number(b.intensity) || 0));
        const height = (intensity / 100) * H;


        const cpu = Number(b.cpu) || 0;
        const blocks = Number(b.blocks) || 0;
        const traffic = Number(b.traffic) || 0;
        let color;
        if (blocks > 0 && blocks >= cpu / 2 && blocks >= traffic / 4) {
            color = `rgba(229,72,77,${0.35 + intensity / 200})`;
        } else if (cpu >= 50) {
            color = `rgba(210,153,34,${0.35 + intensity / 200})`;
        } else {
            color = `rgba(29,111,235,${0.35 + intensity / 200})`;
        }
        ctx.fillStyle = color;
        ctx.fillRect(x, H - height, Math.max(1, barW), height);
    }
    updateScrubCursor();
}

function updateScrubCursor() {
    const cursor = $('tt-cursor');
    if (!cursor) return;
    if (!state.timeTravel.viewingTime) {
        cursor.style.right = '0px';
        return;
    }

    const buckets = state.timeTravel.intensityBuckets || [];
    if (buckets.length === 0) {
        cursor.style.right = '0px';
        return;
    }
    const idx = buckets.findIndex(b => b && String(b.minuteKey) === state.timeTravel.minuteKey);
    const track = $('tt-track');
    const W = track ? track.clientWidth : 0;
    if (idx < 0 || W <= 0) {
        cursor.style.right = '0px';
        return;
    }

    const SLOTS = 1440;
    const slot = SLOTS - buckets.length + idx;
    const slotsFromRight = SLOTS - 1 - slot;
    const px = (slotsFromRight / SLOTS) * W;
    cursor.style.right = `${px}px`;
}

function bucketIndexFromClientX(clientX) {
    const track = $('tt-track');
    if (!track) return -1;
    const rect = track.getBoundingClientRect();
    const x = Math.max(0, Math.min(rect.width, clientX - rect.left));
    const SLOTS = 1440;
    const slot = Math.floor((x / rect.width) * SLOTS);
    const buckets = state.timeTravel.intensityBuckets || [];
    const startSlot = SLOTS - buckets.length;
    const bucketIdx = slot - startSlot;
    if (bucketIdx < 0) return -1;
    if (bucketIdx >= buckets.length) return buckets.length - 1;
    return bucketIdx;
}

function isLiveEdge(minuteKey) {

    const buckets = state.timeTravel.intensityBuckets || [];
    if (buckets.length === 0) return true;
    return String(buckets[buckets.length - 1].minuteKey) === String(minuteKey);
}

function onTrackMousedown(e) {
    state.timeTravel.dragging = true;
    handleScrubAt(e.clientX);
    e.preventDefault();
}

function onTrackMousemove(e) {
    if (!state.timeTravel.dragging) return;
    handleScrubAt(e.clientX);
}

function onDocMouseup() {
    state.timeTravel.dragging = false;
}

function handleScrubAt(clientX) {
    const buckets = state.timeTravel.intensityBuckets || [];
    if (buckets.length === 0) return;
    const idx = bucketIndexFromClientX(clientX);
    if (idx < 0) return;
    const b = buckets[idx];
    if (!b) return;
    const minuteKey = String(b.minuteKey);
    if (isLiveEdge(minuteKey)) {
        exitViewingMode();
        return;
    }
    enterViewingMode(minuteKey);
    loadSnapshotAt(minuteKey);
}

function enterViewingMode(minuteKey) {
    state.timeTravel.viewingTime = true;
    state.timeTravel.minuteKey = minuteKey;
    const bar = $('time-travel-bar');
    if (bar) bar.classList.add('viewing-time');
    const backLive = $('tt-back-live');
    if (backLive) backLive.classList.remove('hidden');

    if (state.pollTimer) {
        clearTimeout(state.pollTimer);
        state.pollTimer = null;
    }
    ttApplyDisabledClass(true);
    setText('tt-time', minuteKey.replace('T', ' '));
    updateScrubCursor();
}

function exitViewingMode() {
    const wasViewing = state.timeTravel.viewingTime;
    state.timeTravel.viewingTime = false;
    state.timeTravel.minuteKey = null;
    const bar = $('time-travel-bar');
    if (bar) bar.classList.remove('viewing-time');
    const backLive = $('tt-back-live');
    if (backLive) backLive.classList.add('hidden');

    if (state.timeTravel.playing) {
        toggleTTPlay();
    }
    ttApplyDisabledClass(false);
    setText('tt-time', 'LIVE');
    updateScrubCursor();

    if (wasViewing && state.authenticated) {
        startPolling();
    }
}

async function loadSnapshotAt(minuteKey) {
    const url = `${API.snapshotAt}?t=${encodeURIComponent(minuteKey)}`;
    let r;
    try {
        r = await fetch(url, { method: 'GET', credentials: 'same-origin' });
    } catch (_) {
        setText('tt-time', `${minuteKey.replace('T', ' ')} (network error)`);
        return;
    }
    if (r.status === 401 || r.status === 403) {
        handleSessionExpired();
        return;
    }
    if (r.status === 404) {
        setText('tt-time', `${minuteKey.replace('T', ' ')} (no data)`);
        return;
    }
    if (!r.ok) {
        setText('tt-time', `${minuteKey.replace('T', ' ')} (error)`);
        return;
    }
    let snap;
    try { snap = await r.json(); } catch (_) { return; }
    if (!snap) return;


    const opts = { historical: true };
    updateStats(snap, opts);
    updateCPU(snap, opts);
    updateRate(snap, opts);
    if (snap.panicState) updatePanicBanner(snap.panicState, opts);
    updateThreatBadge(snap, opts);
    if (snap.alertSummary) updateAlerts(snap.alertSummary, opts);
    if (Array.isArray(snap.blocklist)) {
        updateBlocklist(snap.blocklist, snap.blocklistCount, opts);
    }
    setText('tt-time', minuteKey.replace('T', ' '));
}

function toggleTTPlay() {
    if (state.timeTravel.playing) {
        if (state.timeTravel.playTimer) {
            clearInterval(state.timeTravel.playTimer);
            state.timeTravel.playTimer = null;
        }
        state.timeTravel.playing = false;
        const btn = $('tt-play');
        if (btn) btn.textContent = '▶';
        return;
    }

    if (!state.timeTravel.viewingTime) {
        const buckets = state.timeTravel.intensityBuckets || [];
        if (buckets.length < 2) return;
        const startMin = String(buckets[0].minuteKey);
        enterViewingMode(startMin);
        loadSnapshotAt(startMin);
    }
    state.timeTravel.playing = true;
    const btn = $('tt-play');
    if (btn) btn.textContent = '⏸';

    const speed = Math.max(1, Number(state.timeTravel.playSpeed) || 1);
    const tickMs = Math.max(33, Math.floor(1000 / speed));
    state.timeTravel.playTimer = setInterval(() => {
        const buckets = state.timeTravel.intensityBuckets || [];
        if (buckets.length === 0) return;
        const currentIdx = buckets.findIndex(b => String(b.minuteKey) === state.timeTravel.minuteKey);
        const nextIdx = currentIdx + 1;
        if (nextIdx >= buckets.length) {

            exitViewingMode();
            return;
        }
        const nextMin = String(buckets[nextIdx].minuteKey);
        state.timeTravel.minuteKey = nextMin;
        setText('tt-time', nextMin.replace('T', ' '));
        updateScrubCursor();
        loadSnapshotAt(nextMin);
    }, tickMs);
}

function scrubBy(deltaMin) {
    const buckets = state.timeTravel.intensityBuckets || [];
    if (buckets.length === 0) return;
    let idx;
    if (!state.timeTravel.viewingTime) {
        idx = buckets.length - 1 + deltaMin;
    } else {
        const cur = buckets.findIndex(b => String(b.minuteKey) === state.timeTravel.minuteKey);
        idx = cur + deltaMin;
    }
    if (idx < 0) idx = 0;
    if (idx >= buckets.length) {
        exitViewingMode();
        return;
    }
    const minuteKey = String(buckets[idx].minuteKey);
    if (isLiveEdge(minuteKey)) {
        exitViewingMode();
        return;
    }
    enterViewingMode(minuteKey);
    loadSnapshotAt(minuteKey);
}

function handleKeyboardTT(e) {


    if (e.target && e.target.matches('input,textarea,select,[contenteditable]')) return;
    switch (e.key) {
        case 'j':
        case 'J':
            scrubBy(-1);
            e.preventDefault();
            break;
        case 'k':
        case 'K':
            scrubBy(1);
            e.preventDefault();
            break;
        case ' ':
            toggleTTPlay();
            e.preventDefault();
            break;
        case 'b':
        case 'B':
            if (state.timeTravel.viewingTime) {
                exitViewingMode();
                e.preventDefault();
            }
            break;
    }
}

function bindTimeTravelControls() {
    const track = $('tt-track');
    if (track && !track.dataset.ttBound) {
        track.addEventListener('mousedown', onTrackMousedown);
        document.addEventListener('mousemove', onTrackMousemove);
        document.addEventListener('mouseup', onDocMouseup);
        track.dataset.ttBound = '1';
    }
    const play = $('tt-play');
    if (play && !play.dataset.ttBound) {
        play.addEventListener('click', toggleTTPlay);
        play.dataset.ttBound = '1';
    }
    const speed = $('tt-speed');
    if (speed && !speed.dataset.ttBound) {
        speed.addEventListener('change', e => {
            state.timeTravel.playSpeed = Number(e.target.value) || 1;

            if (state.timeTravel.playing) {
                toggleTTPlay();
                toggleTTPlay();
            }
        });
        speed.dataset.ttBound = '1';
    }
    const back = $('tt-back-live');
    if (back && !back.dataset.ttBound) {
        back.addEventListener('click', exitViewingMode);
        back.dataset.ttBound = '1';
    }
    if (!document.body.dataset.ttKbBound) {
        document.addEventListener('keydown', handleKeyboardTT);
        document.body.dataset.ttKbBound = '1';
    }

    if (!document.body.dataset.ttVisBound) {
        document.addEventListener('visibilitychange', () => {
            if (document.hidden && state.timeTravel.playing) {
                toggleTTPlay();
            }
        });
        document.body.dataset.ttVisBound = '1';
    }

    if (!document.body.dataset.ttResizeBound) {
        window.addEventListener('resize', () => drawIntensityCanvas());
        document.body.dataset.ttResizeBound = '1';
    }
}


const SPOTLIGHT_PAGE_ANCHORS = [
    { title: 'Traffic Telemetry',        anchor: 'section-telemetry' },
    { title: 'Global Defense Master',    anchor: 'section-defense-master' },
    { title: 'Defense Layers',           anchor: 'section-defense-layers' },
    { title: 'Intelligence',             anchor: 'section-intelligence' },
    { title: 'Operations',               anchor: 'section-operations' },
    { title: 'Controls',                 anchor: 'section-controls' },
    { title: 'Live Intelligence Feed',   anchor: 'section-feed' },
];

const SPOTLIGHT_ACTIONS = [
    { title: 'Block IP…',           run: () => { closeSpotlight(); document.getElementById('ip-input')?.focus(); } },
    { title: 'Allowlist IP…',       run: () => { closeSpotlight(); document.getElementById('ip-input')?.focus(); } },
    { title: 'Trigger Panic',       run: () => { closeSpotlight(); document.getElementById('btn-trigger-panic')?.click(); } },
    { title: 'Lift Panic',          run: () => { closeSpotlight(); document.getElementById('btn-lift-panic-ctrl')?.click(); } },
    { title: 'Reset All State',     run: () => { closeSpotlight(); document.getElementById('btn-reset-guard')?.click(); } },
    { title: 'Clear IP Lists',      run: () => { closeSpotlight(); document.getElementById('btn-clear-iplists')?.click(); } },
    { title: 'Export Logs (CSV)',   run: () => { closeSpotlight(); document.getElementById('btn-export-logs')?.click(); } },
    { title: 'Open Security Equalizer', run: () => { closeSpotlight(); window.open('/sentinel-config.html', '_blank', 'noopener'); } },
    { title: 'Ack All Alerts',      run: () => { closeSpotlight(); document.getElementById('btn-ack-all')?.click(); } },
    { title: 'Clear Alerts',        run: () => { closeSpotlight(); document.getElementById('btn-clear-alerts')?.click(); } },
    { title: 'Toggle Theme',        run: () => { closeSpotlight(); document.getElementById('btn-theme-toggle')?.click(); } },
    { title: 'Logout',              run: () => { closeSpotlight(); document.getElementById('btn-logout')?.click(); } },
];


const SPOTLIGHT_GROUP_ORDER = ['Recent', 'Actions', 'IPs', 'URLs', 'Events', 'Alerts', 'Config', 'Pages'];


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
            meta: status,
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
            meta: `${count}× in feed`,
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
                meta: 'blocked',
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


    const hint = document.getElementById('spotlight-mode-hint');
    if (hint) {
        hint.textContent = state.timeTravel?.viewingTime
            ? '(viewing live data — Time-Travel active)'
            : '';
    }

    const results = state.spotlight.results || [];
    if (results.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'sr-empty';
        empty.textContent = state.spotlight.query
            ? 'No matches'
            : 'Type to search · ↑↓ to navigate';
        container.appendChild(empty);
        return;
    }

    let lastGroup = null;
    results.forEach((item, idx) => {
        if (item.group !== lastGroup) {
            const label = document.createElement('div');
            label.className = 'sr-group-label';
            label.textContent = item.group || 'Other';
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
}


async function boot() {
    bindEvents();


    const authData = await api(API.authStatus);

    if (authData && authData.authenticated === true) {

        state.authenticated = true;
        showDashboard();
        await loadSnapshot();
        startPolling();


        initTimeTravel().catch(err => console.warn('[Sentinel] initTimeTravel failed:', err));
    } else {

        showLogin();
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
} else {
    boot();
}
