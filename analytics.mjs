export const GTM_ID = 'GTM-N9M32M9K';
export const GA4_ID = 'G-WPGQ262EXC';
export const CONSENT_KEY = 'resenha_analytics_consent_v1';

export function consentState(granted = false) {
  const value = granted ? 'granted' : 'denied';
  return Object.freeze({
    analytics_storage: value,
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
    functionality_storage: 'granted',
    security_storage: 'granted',
    wait_for_update: 500,
  });
}

export function trackEvent(name, parameters = {}) {
  if (typeof window === 'undefined' || typeof window.gtag !== 'function') return;
  window.gtag('event', name, parameters);
}

function loadTagManager() {
  const script = document.createElement('script');
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtm.js?id=${encodeURIComponent(GTM_ID)}`;
  script.dataset.resenhaGtm = GTM_ID;
  document.head.append(script);
}

function renderConsentControls(storedChoice) {
  const banner = document.createElement('aside');
  banner.className = 'consent-banner';
  banner.dataset.siteEnhancement = 'analytics-consent';
  banner.setAttribute('aria-label', 'Preferências de métricas');
  banner.innerHTML = `<div><strong>Métricas do site</strong><p>Usamos GA4 para entender visitas e downloads. Nunca enviamos nome, e-mail, áudio ou transcrições ao Google.</p></div><div class="consent-actions"><button type="button" data-consent="essential">Somente essenciais</button><button type="button" data-consent="analytics">Aceitar métricas</button></div>`;

  const preferences = document.createElement('button');
  preferences.type = 'button';
  preferences.className = 'consent-preferences';
  preferences.dataset.siteEnhancement = 'analytics-consent';
  preferences.textContent = 'Cookies';
  preferences.setAttribute('aria-label', 'Reabrir preferências de métricas');
  preferences.addEventListener('click', () => banner.hidden = false);

  function choose(granted) {
    const choice = granted ? 'granted' : 'denied';
    try { localStorage.setItem(CONSENT_KEY, choice); } catch { /* The choice still applies to this page. */ }
    window.gtag('consent', 'update', consentState(granted));
    trackEvent('consent_update', { analytics_consent: choice });
    banner.hidden = true;
  }
  banner.querySelector('[data-consent="essential"]').addEventListener('click', () => choose(false));
  banner.querySelector('[data-consent="analytics"]').addEventListener('click', () => choose(true));
  banner.hidden = storedChoice === 'granted' || storedChoice === 'denied';
  document.body.append(banner, preferences);
}

function bootAnalytics() {
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function gtag() { window.dataLayer.push(arguments); };
  let storedChoice = null;
  try { storedChoice = localStorage.getItem(CONSENT_KEY); } catch { storedChoice = null; }
  window.gtag('consent', 'default', consentState(storedChoice === 'granted'));
  window.gtag('set', 'ads_data_redaction', true);
  window.gtag('set', 'url_passthrough', true);
  loadTagManager();
  renderConsentControls(storedChoice);
}

if (typeof window !== 'undefined' && typeof document !== 'undefined') {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bootAnalytics, { once: true });
  else bootAnalytics();
}
