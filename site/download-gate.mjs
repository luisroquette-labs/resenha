import { trackEvent } from './analytics.mjs?v=20261004-1';
import { DOWNLOAD_PLATFORMS, platformConfig } from './download-platforms.mjs?v=20261004-1';

export const FORM_ID = DOWNLOAD_PLATFORMS.macos.formId;
export const FORM_URL = DOWNLOAD_PLATFORMS.macos.formUrl;
export const DOWNLOAD_URL = DOWNLOAD_PLATFORMS.macos.redirectUrl;
export const EMBED_ORIGIN = DOWNLOAD_PLATFORMS.macos.embedOrigin;

export function isFormMessage(event, iframeWindow, config = DOWNLOAD_PLATFORMS.macos) {
  const data = event?.data;
  return config !== null
    && event?.origin === config.embedOrigin
    && event?.source === iframeWindow
    && data && typeof data === 'object'
    && data.source === 'cfgauss-embed-form'
    && data.formId === config.formId;
}

let activeSession;

function endSession(session) {
  if (!session || session.ended) return;
  session.ended = true;
  session.abort.abort();
  if (session.timer) window.clearTimeout(session.timer);
  session.frame.removeAttribute('src');
  session.dialog.remove();
  if (activeSession === session) activeSession = undefined;
}

function createSession(platform, config) {
  const abort = new AbortController();
  const dialog = document.createElement('dialog');
  dialog.className = 'download-gate';
  dialog.setAttribute('aria-labelledby', 'download-gate-title');
  const packageName = platform === 'windows' ? 'instalador assinado' : 'DMG notarizado';
  dialog.innerHTML = `<div class="download-gate-shell"><button class="download-gate-close" type="button" aria-label="Fechar formulário">×</button><div class="download-gate-heading"><p class="kicker">Download gratuito</p><h2 id="download-gate-title">Um passo antes de baixar.</h2><p>Informe nome, e-mail e WhatsApp. O download do ${packageName} começa logo após o envio.</p></div><iframe title="Liberar download do Resenha" loading="eager" referrerpolicy="strict-origin-when-cross-origin"></iframe><p class="download-gate-privacy">Seus dados seguem para o CRM/Trello da CF Gauss. Nenhum dado pessoal é enviado ao GA4.</p></div>`;
  const frame = dialog.querySelector('iframe');
  const session = { platform, config, abort, dialog, frame, ended: false, completed: false, timer: undefined };
  dialog.querySelector('.download-gate-close').addEventListener('click', () => dialog.close(), { signal: abort.signal });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); }, { signal: abort.signal });
  dialog.addEventListener('close', () => { if (!session.completed) endSession(session); }, { signal: abort.signal });
  window.addEventListener('message', event => {
    if (!isFormMessage(event, frame.contentWindow, config) || session !== activeSession || session.ended) return;
    if (typeof event.data.height === 'number' && Number.isFinite(event.data.height) && event.data.height > 0) {
      frame.style.height = `${Math.min(760, Math.max(360, event.data.height))}px`;
    }
    if (event.data.event !== 'success' || session.completed) return;
    session.completed = true;
    trackEvent('download_form_success', { form_id: config.formId, download_version: config.version, platform: config.analyticsPlatform });
    trackEvent('download_start', { download_version: config.version, platform: config.analyticsPlatform });
    session.timer = window.setTimeout(() => window.location.assign(config.redirectUrl), 350);
  }, { signal: abort.signal });
  document.body.append(dialog);
  frame.src = config.formUrl;
  return session;
}

export function openDownloadGate(platform = 'macos') {
  if (typeof document === 'undefined') return false;
  const config = platformConfig(platform);
  if (!config) return false;
  endSession(activeSession);
  activeSession = createSession(platform, config);
  trackEvent('download_gate_view', { form_id: config.formId, download_version: config.version, platform: config.analyticsPlatform });
  activeSession.dialog.showModal();
  return true;
}
