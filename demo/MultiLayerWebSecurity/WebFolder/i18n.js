/* Sentinel UI localisation (en / ja).
 *
 * Load in <head> before the page scripts, followed by the page dictionary (i18n.<page>.js):
 *   <script src="i18n.js"></script>
 *   <script src="i18n.dashboard.js"></script>
 *
 * Language: localStorage 'sentinel-lang' if set, otherwise the browser language (ja* → ja, else en).
 *
 * Markup:   data-i18n="id"              → textContent
 *           data-i18n-html="id"         → innerHTML (only for trusted dictionary strings with markup)
 *           data-i18n-title / data-i18n-placeholder / data-i18n-aria-label = "id"
 * Code:     t('id') or t('id', { n: 5 }) → "{n}" placeholders are replaced.
 * Switch:   any element with [data-lang-toggle] toggles en ⇄ ja and reloads the page.
 */
(function () {
  'use strict';

  var STORE = 'sentinel-lang';
  var SUPPORTED = ['en', 'ja'];
  var dict = { en: {}, ja: {} };

  function detect() {
    var saved = null;
    try { saved = localStorage.getItem(STORE); } catch (e) { /* storage disabled */ }
    if (SUPPORTED.indexOf(saved) >= 0) return saved;
    var nav = (navigator.languages && navigator.languages[0]) || navigator.language || 'en';
    return nav.toLowerCase().indexOf('ja') === 0 ? 'ja' : 'en';
  }

  var lang = detect();
  document.documentElement.setAttribute('lang', lang);

  function t(id, params) {
    var s = dict[lang][id];
    if (s === undefined) s = dict.en[id];
    if (s === undefined) s = id;
    if (params) {
      s = s.replace(/\{(\w+)\}/g, function (m, k) {
        return Object.prototype.hasOwnProperty.call(params, k) ? String(params[k]) : m;
      });
    }
    return s;
  }

  var ATTRS = [
    ['data-i18n-title', 'title'],
    ['data-i18n-placeholder', 'placeholder'],
    ['data-i18n-aria-label', 'aria-label']
  ];

  function apply(root) {
    root = root || document;
    var i, els;
    els = root.querySelectorAll('[data-i18n]');
    for (i = 0; i < els.length; i++) els[i].textContent = t(els[i].getAttribute('data-i18n'));
    els = root.querySelectorAll('[data-i18n-html]');
    for (i = 0; i < els.length; i++) els[i].innerHTML = t(els[i].getAttribute('data-i18n-html'));
    ATTRS.forEach(function (pair) {
      var list = root.querySelectorAll('[' + pair[0] + ']');
      for (var j = 0; j < list.length; j++) list[j].setAttribute(pair[1], t(list[j].getAttribute(pair[0])));
    });
    var toggles = root.querySelectorAll('[data-lang-toggle]');
    for (i = 0; i < toggles.length; i++) {
      toggles[i].textContent = lang === 'ja' ? 'EN' : 'JA';
      toggles[i].setAttribute('title', t('common.switchLanguage'));
      toggles[i].setAttribute('aria-label', t('common.switchLanguage'));
    }
  }

  function setLang(next) {
    if (SUPPORTED.indexOf(next) < 0) return;
    try { localStorage.setItem(STORE, next); } catch (e) { /* storage disabled */ }
    location.reload();
  }

  function add(d) {
    for (var l in d) {
      if (!dict[l]) dict[l] = {};
      for (var k in d[l]) dict[l][k] = d[l][k];
    }
  }

  // Locale-aware number/time formatting helpers for page scripts.
  function locale() { return lang === 'ja' ? 'ja-JP' : 'en-US'; }

  add({
    en: { 'common.switchLanguage': 'Switch language (English / 日本語)' },
    ja: { 'common.switchLanguage': '表示言語を切り替え（English / 日本語）' }
  });

  document.addEventListener('click', function (e) {
    var el = e.target.closest && e.target.closest('[data-lang-toggle]');
    if (el) { e.preventDefault(); setLang(lang === 'ja' ? 'en' : 'ja'); }
  });
  document.addEventListener('DOMContentLoaded', function () { apply(document); });

  window.I18N = { add: add, t: t, apply: apply, setLang: setLang, locale: locale, get lang() { return lang; } };
  window.t = t;
}());
