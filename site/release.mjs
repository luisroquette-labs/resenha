import { openDownloadGate } from './download-gate.mjs?v=20261004-4';
import { platformConfig } from './download-platforms.mjs?v=20261004-1';

const copy = Object.freeze({
  macos: { label: 'Download em preparação', ready: 'Baixar para macOS', reason: 'Ainda não há um instalador público verificado.' },
  source: { label: 'Código público em preparação', ready: 'Ver código no GitHub', reason: 'O repositório público ainda não foi publicado.' },
  store: { label: 'Mac App Store não utilizada', ready: 'Ver na Mac App Store', reason: 'O Resenha para Mac é distribuído diretamente em DMG.' },
  windows: { label: 'Windows em validação', ready: 'Baixar para Windows', reason: 'O instalador será liberado após assinatura, scan e testes físicos no Windows 10 e 11.' },
});

export const releaseState = Object.freeze({
  macos: Object.freeze({ state: 'published', platform: 'macos', version: '1.0.0',
    architecture: 'Apple Silicon (arm64)', minimumOS: 'macOS 14+',
    url: 'https://github.com/luisroquette/resenha/releases/download/v1.0.0/Resenha-1.0.0-arm64.dmg',
    evidence: Object.freeze({ channel: 'macos',
      url: 'https://github.com/luisroquette/resenha/releases/download/v1.0.0/Resenha-1.0.0-arm64.dmg',
      verifiedAt: '2026-10-04T00:35:16Z', artifact: Object.freeze({ platform: 'macos', version: '1.0.0',
        sha256: '9fc0728419c8c2ca4feb0631667a4ce8cdf88cfd894c821b3f82b98533056985',
        notarizationId: 'e3471859-6fe0-4166-8c6e-bcb723afdab3', notarizationStatus: 'Accepted' }) }) }),
  source: Object.freeze({ state: 'published', url: 'https://github.com/luisroquette/resenha',
    evidence: Object.freeze({ channel: 'source', url: 'https://github.com/luisroquette/resenha',
      verifiedAt: '2026-10-03T02:30:00Z' }) }),
  store: Object.freeze({ state: 'planned', url: null, evidence: null }),
  windows: Object.freeze({ state: 'unavailable', platform: 'windows', version: null,
    architecture: 'x64', minimumOS: 'Windows 10 22H2 / Windows 11 25H2', url: null, evidence: null }),
});

const nonempty = value => typeof value === 'string' && value.trim().length > 0;

export function resolveDestination(channel, record) {
  const wording = Object.hasOwn(copy, channel) ? copy[channel] : null;
  const inactive = () => Object.freeze({ active: false, href: null,
    label: wording?.label ?? 'Indisponível', reason: wording?.reason ?? 'Canal não reconhecido.' });
  if (!wording || record?.state !== 'published' || !nonempty(record.url)) return inactive();
  const raw = record.url;
  const authority = /^https:\/\/([^/]+)\//iu.exec(raw)?.[1];
  if (!authority || authority.includes('@') || raw !== raw.trim() || /[\s\\]/u.test(raw)) return inactive();
  let url;
  try { url = new URL(raw); } catch { return inactive(); }
  if (url.protocol !== 'https:' || url.username || url.password || url.port || url.search || url.hash) return inactive();
  // Encoded separators and dot segments are not authored release destinations.
  if (/%|(?:^|\/)\.{1,2}(?:\/|$)/u.test(raw.slice(raw.indexOf('://') + 3))) return inactive();
  const repo = '[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+';
  const permitted = channel === 'source'
    ? url.hostname === 'github.com' && new RegExp(`^/${repo}/?$`).test(url.pathname)
    : channel === 'macos' || channel === 'windows'
      ? url.hostname === 'github.com' && new RegExp(`^/${repo}/releases/download/(?!latest/)[A-Za-z0-9_.-]+/[^/]+$`).test(url.pathname)
      : url.hostname === 'apps.apple.com' && /^\/(?:[a-z]{2}\/)?app\/(?:[^/]+\/)?id[1-9]\d*\/?$/u.test(url.pathname);
  if (!permitted) return inactive();
  const evidence = record.evidence;
  if (evidence?.channel !== channel || evidence.url !== raw || !nonempty(evidence.verifiedAt) || !Number.isFinite(Date.parse(evidence.verifiedAt))) return inactive();
  if (channel === 'macos' && (record.platform !== 'macos' || !nonempty(record.version)
    || !nonempty(record.architecture) || !nonempty(record.minimumOS)
    || evidence.artifact?.platform !== 'macos' || evidence.artifact.version !== record.version
    || !/^[a-f0-9]{64}$/u.test(evidence.artifact.sha256 ?? '')
    || !/^[a-f0-9-]{36}$/u.test(evidence.artifact.notarizationId ?? '')
    || evidence.artifact.notarizationStatus !== 'Accepted')) return inactive();
  if (channel === 'windows') {
    const expectedName = `Resenha-${record.version}-windows-x64-setup.exe`;
    const expectedPath = `/luisroquette/resenha/releases/download/windows-v${record.version}/${expectedName}`;
    if (record.platform !== 'windows' || record.architecture !== 'x64' || !nonempty(record.version)
      || url.pathname !== expectedPath || evidence.artifact?.platform !== 'windows'
      || evidence.artifact.version !== record.version || evidence.artifact.filename !== expectedName
      || !/^[a-f0-9]{64}$/u.test(evidence.artifact.sha256 ?? '')
      || !/^[a-f0-9]{40}$/u.test(evidence.artifact.sourceCommit ?? '')
      || evidence.artifact.signature !== 'valid-trusted-rfc3161'
      || evidence.artifact.scan !== 'passed-zero-detections'
      || evidence.artifact.physicalWindows10 !== true || evidence.artifact.physicalWindows11 !== true
      || evidence.artifact.hostedSha256 !== evidence.artifact.sha256) return inactive();
  }
  return Object.freeze({ active: true, href: raw, label: wording.ready,
    reason: ['macos', 'windows'].includes(channel) ? `${record.version} · ${record.architecture} · ${record.minimumOS}` : 'Destino publicado e verificado.' });
}

export function resolvePresentation(channel, record, formConfig = platformConfig(channel)) {
  const destination = resolveDestination(channel, record);
  if (!destination.active || !['macos', 'windows'].includes(channel) || formConfig) return destination;
  return Object.freeze({ active: false, href: null, label: copy[channel].label,
    reason: 'O formulário verificado desta plataforma ainda não está disponível.' });
}

export function applyReleaseState(root, state = releaseState) {
  for (const slot of root.querySelectorAll('[data-release-channel]')) {
    const channel = slot.dataset.releaseChannel;
    const result = resolvePresentation(channel, state?.[channel]);
    const gatedDownload = result.active && ['macos', 'windows'].includes(channel);
    const action = slot.ownerDocument.createElement(result.active ? (gatedDownload ? 'button' : 'a') : 'span');
    action.className = 'release-action';
    action.textContent = result.label;
    if (gatedDownload) {
      action.type = 'button';
      action.dataset.downloadGate = 'true';
      action.setAttribute('aria-haspopup', 'dialog');
      action.addEventListener('click', () => openDownloadGate(channel));
    } else if (result.active) action.href = result.href;
    else action.setAttribute('aria-disabled', 'true');
    const reason = slot.ownerDocument.createElement('p');
    reason.className = 'release-reason';
    reason.textContent = result.reason;
    slot.replaceChildren(action, reason);
  }
}

if (typeof document !== 'undefined') applyReleaseState(document);
