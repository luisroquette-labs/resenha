import { trackEvent } from './analytics.mjs?v=20261004-1';

export const FORM_ID = '0a702231-3472-412f-8e3b-00ecfa481100';
export const FORM_URL = 'https://cfgauss.com.br/t/formembed-download-resenha-para-macos-2e57ed14';
export const DOWNLOAD_URL = 'https://cfgauss.com.br/t/formredirect-0a702231-3472-412f-8e3b-00ecfa481100';
export const EMBED_ORIGIN = 'https://cfgauss.com.br';

export function isFormMessage(event, iframeWindow) {
  const data = event?.data;
  return event?.origin === EMBED_ORIGIN
    && event?.source === iframeWindow
    && data && typeof data === 'object'
    && data.source === 'cfgauss-embed-form'
    && data.formId === FORM_ID;
}

let gate;
let iframe;
let redirecting = false;

function createGate() {
  const dialog = document.createElement('dialog');
  dialog.className = 'download-gate';
  dialog.setAttribute('aria-labelledby', 'download-gate-title');
  dialog.innerHTML = `<div class="download-gate-shell"><button class="download-gate-close" type="button" aria-label="Fechar formulário">×</button><div class="download-gate-heading"><p class="kicker">Download gratuito</p><h2 id="download-gate-title">Um passo antes de baixar.</h2><p>Informe nome, e-mail e WhatsApp. O download do DMG notarizado começa logo após o envio.</p></div><iframe title="Liberar download do Resenha" loading="eager" referrerpolicy="strict-origin-when-cross-origin"></iframe><p class="download-gate-privacy">Seus dados seguem para o CRM/Trello da CF Gauss. Nenhum dado pessoal é enviado ao GA4.</p></div>`;
  const frame = dialog.querySelector('iframe');
  dialog.querySelector('.download-gate-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  dialog.addEventListener('close', () => {
    if (!redirecting) frame.removeAttribute('src');
  });
  window.addEventListener('message', event => {
    if (!isFormMessage(event, frame.contentWindow)) return;
    if (typeof event.data.height === 'number' && Number.isFinite(event.data.height) && event.data.height > 0) {
      frame.style.height = `${Math.min(760, Math.max(360, event.data.height))}px`;
    }
    if (event.data.event !== 'success' || redirecting) return;
    redirecting = true;
    trackEvent('download_form_success', { form_id: FORM_ID, download_version: '1.0.0', platform: 'macos_arm64' });
    trackEvent('download_start', { download_version: '1.0.0', platform: 'macos_arm64' });
    window.setTimeout(() => window.location.assign(DOWNLOAD_URL), 350);
  });
  document.body.append(dialog);
  return { dialog, frame };
}

export function openDownloadGate() {
  if (typeof document === 'undefined') return;
  if (!gate) ({ dialog: gate, frame: iframe } = createGate());
  redirecting = false;
  iframe.src = FORM_URL;
  trackEvent('download_gate_view', { form_id: FORM_ID, download_version: '1.0.0', platform: 'macos_arm64' });
  gate.showModal();
}
