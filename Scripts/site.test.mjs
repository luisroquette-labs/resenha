import test from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { mkdtemp, readFile, writeFile, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { releaseState, resolveDestination, resolvePresentation } from '../site/release.mjs';
import { consentState, GA4_ID, GTM_ID } from '../site/analytics.mjs';
import { DOWNLOAD_URL, EMBED_ORIGIN, FORM_ID, FORM_URL, isFormMessage } from '../site/download-gate.mjs';
import { DOWNLOAD_PLATFORMS, platformConfig } from '../site/download-platforms.mjs';
import { projectWindowsRelease } from './windows/promote-release.mjs';
import { createPreviewServer } from './site.mjs';

// Synthetic destinations are never fetched; browser audits must intercept them.
const macos = { state: 'published', platform: 'macos', version: 'v0.0.0-test', architecture: 'arm64', minimumOS: 'macOS 14+',
  url: 'https://github.com/example/resenha-test/releases/download/v0.0.0-test/Resenha-test.dmg',
  evidence: { channel: 'macos', url: 'https://github.com/example/resenha-test/releases/download/v0.0.0-test/Resenha-test.dmg',
    verifiedAt: '2026-10-02T00:00:00Z', artifact: { platform: 'macos', version: 'v0.0.0-test',
      sha256: 'a'.repeat(64), notarizationId: '12345678-1234-1234-1234-123456789abc', notarizationStatus: 'Accepted' } } };
const negative = (name, change, channel = 'macos') => {
  const record = structuredClone(macos);
  change(record);
  return { name, channel, record, active: false };
};
const urlCase = (name, url) => negative(name, record => { record.url = url; record.evidence.url = url; });
const windows = { state: 'published', platform: 'windows', version: '1.2.3', architecture: 'x64',
  minimumOS: 'Windows 10 22H2 / Windows 11 25H2',
  url: 'https://github.com/luisroquette/resenha/releases/download/windows-v1.2.3/Resenha-1.2.3-windows-x64-setup.exe',
  evidence: { channel: 'windows',
    url: 'https://github.com/luisroquette/resenha/releases/download/windows-v1.2.3/Resenha-1.2.3-windows-x64-setup.exe',
    verifiedAt: '2026-10-04T12:00:00Z', artifact: { platform: 'windows', version: '1.2.3',
      filename: 'Resenha-1.2.3-windows-x64-setup.exe', sha256: 'b'.repeat(64), sourceCommit: 'c'.repeat(40),
      signature: 'valid-trusted-rfc3161', scan: 'passed-zero-detections', physicalWindows10: true,
      physicalWindows11: true, hostedSha256: 'b'.repeat(64) } } };
const negativeWindows = (name, change) => {
  const record = structuredClone(windows); change(record);
  return { name, channel: 'windows', record, active: false };
};

export const destinationFixtures = [
  negative('unavailable', r => { r.state = 'unavailable'; }),
  negative('planned-with-url', r => { r.state = 'planned'; }),
  negative('missing-url', r => { delete r.url; }),
  urlCase('empty-url', ''),
  urlCase('whitespace-url', '   '),
  urlCase('malformed-url', 'not a URL'),
  urlCase('http-url', macos.url.replace('https:', 'http:')),
  urlCase('javascript-url', 'javascript:alert(1)'),
  urlCase('data-url', 'data:text/html,test'),
  urlCase('file-url', 'file:///example.invalid/test'),
  urlCase('credentialed-url', macos.url.replace('https://', 'https://user:password@')),
  urlCase('wrong-host', macos.url.replace('github.com', 'example.invalid')),
  negative('missing-evidence', r => { delete r.evidence; }),
  negative('evidence-url-mismatch', r => { r.evidence.url = 'https://example.invalid/other'; }),
  negative('unknown-state', r => { r.state = 'unknown'; }),
  negative('unknown-channel', () => {}, 'other'),
  negative('unknown-platform', r => { r.platform = 'windows'; }),
  negative('missing-version', r => { delete r.version; }),
  negative('missing-architecture', r => { delete r.architecture; }),
  negative('missing-minimum-os', r => { delete r.minimumOS; }),
  negative('artifact-platform-mismatch', r => { r.evidence.artifact.platform = 'windows'; }),
  negative('artifact-version-mismatch', r => { r.evidence.artifact.version = 'different'; }),
  negative('missing-evidence-channel', r => { delete r.evidence.channel; }),
  negative('missing-evidence-url', r => { delete r.evidence.url; }),
  negative('missing-verified-at', r => { delete r.evidence.verifiedAt; }),
  negative('missing-artifact', r => { delete r.evidence.artifact; }),
  negative('missing-artifact-platform', r => { delete r.evidence.artifact.platform; }),
  negative('missing-artifact-version', r => { delete r.evidence.artifact.version; }),
  negative('missing-artifact-sha256', r => { delete r.evidence.artifact.sha256; }),
  negative('invalid-notarization', r => { r.evidence.artifact.notarizationStatus = 'Rejected'; }),
  { name: 'valid-macos-release', channel: 'macos', record: structuredClone(macos), active: true },
  { name: 'valid-public-source', channel: 'source', active: true, record: { state: 'published',
    url: 'https://github.com/example/resenha-test', evidence: { channel: 'source',
      url: 'https://github.com/example/resenha-test', verifiedAt: '2026-10-02T00:00:00Z' } } },
  { name: 'valid-published-store', channel: 'store', active: true, record: { state: 'published',
    url: 'https://apps.apple.com/br/app/resenha-test/id1234567890', evidence: { channel: 'store',
      url: 'https://apps.apple.com/br/app/resenha-test/id1234567890', verifiedAt: '2026-10-02T00:00:00Z' } } },
  negativeWindows('windows-wrong-filename', r => { r.evidence.artifact.filename = 'Resenha.exe'; }),
  negativeWindows('windows-missing-signature', r => { delete r.evidence.artifact.signature; }),
  negativeWindows('windows-scan-not-clean', r => { r.evidence.artifact.scan = 'pending'; }),
  negativeWindows('windows-missing-physical-10', r => { r.evidence.artifact.physicalWindows10 = false; }),
  negativeWindows('windows-missing-physical-11', r => { r.evidence.artifact.physicalWindows11 = false; }),
  negativeWindows('windows-hosted-hash-mismatch', r => { r.evidence.artifact.hostedSha256 = 'd'.repeat(64); }),
  { name: 'valid-windows-release', channel: 'windows', record: structuredClone(windows), active: true },
];

function get(origin, path, method = 'GET') {
  return new Promise((accept, reject) => {
    const req = request(origin, { path, method }, res => {
      const parts = [];
      res.on('data', part => parts.push(part));
      res.on('end', () => accept({ status: res.statusCode, headers: res.headers, body: Buffer.concat(parts).toString() }));
    });
    req.on('error', reject);
    req.end();
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  test('CK-7/15: exact finite catalogue has 36 inactive and four active fixtures', () => {
    assert.equal(destinationFixtures.length, 40);
    assert.equal(new Set(destinationFixtures.map(f => f.name)).size, 40);
    assert.equal(destinationFixtures.filter(f => !f.active).length, 36);
    assert.equal(destinationFixtures.filter(f => f.active).length, 4);
  });
  for (const fixture of destinationFixtures) test(`CK-7: ${fixture.name}`, () => {
    const before = structuredClone(fixture.record);
    const output = resolveDestination(fixture.channel, fixture.record);
    assert.equal(output.active, fixture.active);
    assert.equal(output.href, fixture.active ? fixture.record.url : null);
    assert.ok(output.label.length && output.reason.length);
    assert.ok(Object.isFrozen(output));
    assert.deepEqual(fixture.record, before);
  });
  test('CK-7/15: published DMG and source resolve while retired Store fails closed', () => {
    assert.equal(resolveDestination('source', releaseState.source).active, true);
    assert.equal(resolveDestination('source', releaseState.source).href, 'https://github.com/luisroquette/resenha');
    assert.equal(resolveDestination('macos', releaseState.macos).active, true);
    assert.match(resolveDestination('macos', releaseState.macos).href, /Resenha-1\.0\.0-arm64\.dmg$/u);
    assert.equal(releaseState.store.url, null);
    assert.equal(releaseState.store.evidence, null);
    assert.equal(resolveDestination('store', releaseState.store).active, false);
    assert.equal(releaseState.windows.state, 'unavailable');
    assert.equal(resolveDestination('windows', releaseState.windows).active, false);
    assert.equal(resolvePresentation('windows', windows).active, false);
    assert.equal(resolvePresentation('windows', windows, Object.freeze({ platform: 'windows' })).active, true);
    for (const channel of ['macos', 'source', 'store', 'windows'])
      for (const record of [null, undefined, {}, '', [], { state: 'published' }]) assert.equal(resolveDestination(channel, record).active, false);
    assert.equal(resolveDestination('__proto__', macos).active, false);
  });
  test('download gate accepts only the exact CF Gauss iframe and form', async () => {
    const iframeWindow = {};
    const valid = { origin: EMBED_ORIGIN, source: iframeWindow, data: { source: 'cfgauss-embed-form', formId: FORM_ID, event: 'success' } };
    assert.equal(isFormMessage(valid, iframeWindow), true);
    assert.equal(isFormMessage({ ...valid, origin: 'https://example.com' }, iframeWindow), false);
    assert.equal(isFormMessage({ ...valid, source: {} }, iframeWindow), false);
    assert.equal(isFormMessage({ ...valid, data: { ...valid.data, formId: 'outro-form' } }, iframeWindow), false);
    assert.match(FORM_URL, /^https:\/\/cfgauss\.com\.br\/t\/formembed-/u);
    assert.match(DOWNLOAD_URL, /^https:\/\/cfgauss\.com\.br\/t\/formredirect-/u);
    assert.equal(platformConfig('windows'), null);
    assert.equal(DOWNLOAD_PLATFORMS.windows, null);
    assert.equal(platformConfig('__proto__'), null);
    const clonedMac = platformConfig('macos');
    assert.notEqual(clonedMac, DOWNLOAD_PLATFORMS.macos);
    assert.deepEqual(clonedMac, DOWNLOAD_PLATFORMS.macos);
    assert.match(await readFile(new URL('../site/download-gate.mjs', import.meta.url), 'utf8'), /Informe nome, e-mail e WhatsApp\./u);
    assert.match(execFileSync(process.execPath, ['--input-type=module', '-e',
      `import(${JSON.stringify(new URL('../site/download-gate.mjs', import.meta.url).href)}).then(() => process.stdout.write('ok'))`],
    { encoding: 'utf8', timeout: 5000 }), /^ok$/u);
  });
  test('CK-15: promotion projects only exact hosted observed Windows evidence', () => {
    const manifest = { schemaVersion: 1, evidenceClass: 'observed', stage: 'hosted-ready', version: '1.2.3',
      filename: 'Resenha-1.2.3-windows-x64-setup.exe', byteLength: 42, sha256: 'b'.repeat(64), sourceCommit: 'c'.repeat(40),
      signatures: { publisher: 'Resenha Publisher' }, hosting: { url: windows.url, downloadedSha256: 'b'.repeat(64) } };
    const verification = { contractValid: true, hostedReady: true, canEnablePublicDownload: true,
      sourceCommit: 'c'.repeat(40), artifactSha256: 'b'.repeat(64), verifiedAtUtc: '2026-10-04T12:00:00Z' };
    const download = { url: windows.url, sha256: 'b'.repeat(64), byteLength: 42, publisherDisplay: 'Resenha Publisher' };
    assert.deepEqual(projectWindowsRelease(manifest, verification, download), windows);
    for (const mutate of [
      value => { value.manifest.evidenceClass = 'synthetic'; }, value => { value.verification.hostedReady = false; },
      value => { value.download.sha256 = 'd'.repeat(64); }, value => { value.manifest.hosting.url += '?latest=1'; },
    ]) {
      const value = structuredClone({ manifest, verification, download }); mutate(value);
      assert.throws(() => projectWindowsRelease(value.manifest, value.verification, value.download));
    }
  });
  test('Consent Mode v2 denies analytics and all advertising signals by default', () => {
    const denied = consentState(false);
    assert.equal(denied.analytics_storage, 'denied');
    assert.equal(denied.ad_storage, 'denied');
    assert.equal(denied.ad_user_data, 'denied');
    assert.equal(denied.ad_personalization, 'denied');
    assert.equal(consentState(true).analytics_storage, 'granted');
    assert.match(GTM_ID, /^GTM-[A-Z0-9]+$/u);
    assert.match(GA4_ID, /^G-[A-Z0-9]+$/u);
  });
  test('CK-7: malformed evidence and concrete-destination partitions', () => {
    for (const fixture of destinationFixtures.filter(item => item.active)) {
      for (const change of [r => { r.evidence.channel = 'other'; }, r => { r.evidence.verifiedAt = 'invalid'; },
        r => { r.url += '?fake=1'; r.evidence.url = r.url; }, r => { r.url += '#fake'; r.evidence.url = r.url; },
        r => { r.url = r.url.replace('https://', 'https://').replace(/(\.com)/u, '$1:444'); r.evidence.url = r.url; }]) {
        const record = structuredClone(fixture.record); change(record);
        assert.equal(resolveDestination(fixture.channel, record).active, false);
      }
    }
    for (const url of [macos.url.replace('/download/v0.0.0-test/', '/download/latest/'),
      macos.url.replace('/releases/download/v0.0.0-test/Resenha-test.dmg', '/archive/refs/heads/main.zip'),
      macos.url.replace('/v0.0.0-test/', '/%2e%2e/'), macos.url.replace('/v0.0.0-test/', '/.. /'),
      macos.url.replace('https://', 'https:'), macos.url.replace('https://', 'https:////'),
      macos.url.replace('https://', 'https://@')]) {
      const record = structuredClone(macos); record.url = url; record.evidence.url = url;
      assert.equal(resolveDestination('macos', record).active, false);
    }
    const source = structuredClone(destinationFixtures.find(item => item.name === 'valid-public-source').record);
    source.url = 'https://github.com/example'; source.evidence.url = source.url;
    assert.equal(resolveDestination('source', source).active, false);
    const store = structuredClone(destinationFixtures.find(item => item.name === 'valid-published-store').record);
    store.url = 'https://apps.apple.com/br/app/resenha'; store.evidence.url = store.url;
    assert.equal(resolveDestination('store', store).active, false);
  });
  test('CK-16: importing fixtures registers no tests and opens no server', () => {
    const stdout = execFileSync(process.execPath, ['--input-type=module', '-e',
      `const {destinationFixtures}=await import(${JSON.stringify(import.meta.url)}); if(destinationFixtures.length!==40) process.exit(2);`],
    { encoding: 'utf8', timeout: 5000 });
    assert.equal(stdout, '');
  });
  test('CK-13/16: preview confinement and lifecycle at root and subpath', async () => {
    const fixtureRoot = await mkdtemp(join(tmpdir(), 'resenha-site-'));
    const { mkdir } = await import('node:fs/promises');
    const root = join(fixtureRoot, 'site'); await mkdir(root);
    await writeFile(join(root, 'index.html'), '<h1>Owned fixture</h1>');
    await writeFile(join(root, 'styles.css'), 'body {}');
    await writeFile(join(root, 'release.mjs'), 'export const test = true;');
    await writeFile(join(root, 'media.mjs'), 'export const test = true;');
    await writeFile(join(root, 'analytics.mjs'), 'export const test = true;');
    await writeFile(join(root, 'download-gate.mjs'), 'export const test = true;');
    await writeFile(join(root, 'download-platforms.mjs'), 'export const test = true;');
    await writeFile(join(root, 'windows-release-evidence.json'), '{"state":"unavailable"}');
    await writeFile(join(fixtureRoot, 'outside.txt'), 'OWNED_OUTSIDE_SENTINEL');
    await symlink(join(fixtureRoot, 'outside.txt'), join(root, 'escape.txt'));
    try {
      for (const prefix of ['/', '/resenha/']) {
        const preview = await createPreviewServer({ root, prefix });
        try {
          assert.equal(preview.server.address().address, '127.0.0.1');
        assert.equal((await get(preview.origin, prefix)).status, 200);
          assert.equal((await get(preview.origin, prefix + 'privacy/')).status, 404);
          const head = await get(preview.origin, prefix, 'HEAD');
          assert.equal(head.status, 200); assert.equal(head.body, '');
          assert.match(head.headers['content-type'], /text\/html/u);
          for (const [name, type] of [['styles.css', 'text/css'], ['release.mjs', 'text/javascript'], ['media.mjs', 'text/javascript'], ['analytics.mjs', 'text/javascript'], ['download-gate.mjs', 'text/javascript'], ['download-platforms.mjs', 'text/javascript'], ['windows-release-evidence.json', 'application/json']]) {
            assert.ok((await get(preview.origin, prefix + name)).headers['content-type'].startsWith(type));
          }
          for (const path of ['../outside.txt', '%2e%2e/outside.txt', '%2e%2e%2foutside.txt', '%ZZ', '%00', 'escape.txt', '%5c..%5coutside.txt', '/outside.txt']) {
            const denied = await get(preview.origin, prefix + path);
            assert.ok(denied.status >= 400, path); assert.ok(!denied.body.includes('OWNED_OUTSIDE_SENTINEL'));
          }
          assert.equal((await get(preview.origin, prefix, 'POST')).status, 405);
          assert.equal((await get(preview.origin, prefix + 'missing')).status, 404);
          if (prefix !== '/') assert.equal((await get(preview.origin, '/')).status, 404);
          assert.equal((await get(preview.origin, prefix)).status, 200);
        } finally { await preview.close(); }
      }
      await assert.rejects(createPreviewServer({ root, prefix: '/../' }));
      await assert.rejects(createPreviewServer({ root, port: -1 }));
    } finally { await rm(fixtureRoot, { recursive: true, force: true }); }
  });
  test('CK-5/11/15/19: actual document is usable at root/subpath with truthful static slots', async () => {
    let rootBody;
    for (const prefix of ['/', '/resenha/']) {
      const preview = await createPreviewServer({ prefix });
      try {
        const response = await get(preview.origin, prefix);
        assert.equal(response.status, 200);
        const html = response.body;
        if (rootBody) assert.equal(html, rootBody); else rootBody = html;
        assert.match(html, /<html\b[^>]*lang="pt-BR"/u);
        assert.match(html, /<title>[^<]*Resenha[^<]*<\/title>/u);
        assert.match(html, /name="description"[^>]*content="[^"]*alternativa gratuita[^"]*Wispr Flow[^"]*"/iu);
        assert.match(html, /property="og:title"/u);
        assert.match(html, /property="og:description"/u);
        assert.match(html, /licença MIT/u);
        assert.match(html, /SwiftUI/u); assert.match(html, /whisper\.cpp/u); assert.match(html, /ATALHO LIVRE/u);
        assert.match(html, /Acessibilidade/u);
        assert.match(html, /Apple Silicon/u); assert.match(html, /AVFoundation/u);
        assert.match(html, /alternativa open source ao Wispr Flow/iu);
        assert.match(html, /sem limite semanal/iu);
        assert.match(html, /2\.000 palavras no desktop/iu);
        assert.equal((html.match(/id="download"/gu) ?? []).length, 1);
        assert.ok((html.match(/href="#download"/gu) ?? []).length >= 2);
        assert.match(html.match(/<section\b[^>]*id="inicio"[\s\S]*?<\/section>/u)?.[0] ?? '', /href="#download"/u);
        assert.match(html.match(/<nav\b[\s\S]*?<\/nav>/u)?.[0] ?? '', /href="#download"/u);
        assert.equal((html.match(/data-release-channel="macos"/gu) ?? []).length, 1);
        assert.equal((html.match(/data-release-channel="windows"/gu) ?? []).length, 1);
        assert.ok((html.match(/data-release-channel="source"/gu) ?? []).length >= 1);
        assert.doesNotMatch(html, /href="(?:|#|https?:\/\/(?:github\.com|apps\.apple\.com)[^"]*)"/u);
        assert.match(html, /rel="canonical"/u);
        assert.match(html, /application\/ld\+json/u);
        assert.equal((await get(preview.origin, prefix + 'googleb0847bf7435d170c.html')).body.trim(), 'google-site-verification: googleb0847bf7435d170c.html');
        assert.match(html, /analytics\.mjs\?v=20261004-1/u);
        assert.doesNotMatch(html, /aggregateRating/u);
        assert.doesNotMatch(html, /<(?:form|input|iframe)\b/iu);
        assert.match(html, /<details[\s>]/u); assert.match(html, /<summary[\s>]/u);
        for (const name of ['styles.css', 'release.mjs', 'media.mjs', 'assets/brand/resenha-mark.svg',
          'assets/brand/resenha-app-icon.png', 'assets/product/hud-listening.png',
          'assets/product/settings-general.webp', 'assets/product/settings-shortcut.webp',
          'assets/product/settings-sounds.webp', 'assets/product/settings-audio.webp',
          'assets/product/settings-transcription.webp', 'assets/product/settings-about.webp',
          'assets/product/resenha-flow.mp4', 'assets/product/resenha-settings.mp4',
          'assets/product/resenha-flow-poster.webp']) {
          assert.ok(html.includes(name));
          assert.equal((await get(preview.origin, prefix + name)).status, 200);
        }
        assert.equal((html.match(/Interface real do app/gu) ?? []).length, 1);
        assert.equal((html.match(/<video\b/gu) ?? []).length, 2);
        assert.doesNotMatch(html, /OpenAI|chave API/u);
        assert.match(html, /atalho é gravado dentro do Resenha/u);
        assert.match(html, /Option direita isolada/u);
        assert.match(html, /Windows em validação/u);
        assert.match(html, /class="voice-ribbon"/u);
        assert.match(html, /class="hero-stamp"/u);
        assert.ok((html.match(/data-reveal/gu) ?? []).length >= 8);
        assert.match(html, /type="module"/u);
        assert.match(html, /styles\.css\?v=20261004-3/u);
        assert.match(html, /release\.mjs\?v=20261004-4/u);
        assert.match(html, /media\.mjs\?v=20261003-2/u);
        const media = await get(preview.origin, prefix + 'media.mjs');
        assert.equal(media.status, 200);
        assert.match(media.body, /IntersectionObserver/u);
        assert.match(media.body, /prefers-reduced-motion/u);
        const gate = await get(preview.origin, prefix + 'download-gate.mjs');
        assert.match(gate.body, /analytics\.mjs\?v=20261004-1/u);
        assert.match(gate.body, /Informe nome, e-mail e WhatsApp\./u);
        const privacy = await get(preview.origin, prefix + 'privacy/');
        assert.equal(privacy.status, 200);
        assert.match(privacy.body, /Sua voz fica no seu computador/u);
        assert.match(privacy.body, /No Windows, o MVP não grava histórico em disco/u);
        assert.match(privacy.body, /Acessibilidade devolve o foco/u);
        assert.match(privacy.body, /não lê o conteúdo de outros apps/u);
        assert.match(privacy.body, /Consent Mode v2/u);
        assert.match(privacy.body, /negado por padrão/u);
        assert.match(privacy.body, /CRM\/Trello/u);
        const comparison = await get(preview.origin, prefix + 'alternativa-wispr-flow/');
        assert.equal(comparison.status, 200);
        assert.match(comparison.body, /<title>Alternativa gratuita e sem limite ao Wispr Flow \| Resenha<\/title>/u);
        assert.match(comparison.body, /Sem limite semanal imposto pelo plano/u);
        assert.match(comparison.body, /Resenha é um projeto independente/u);
        assert.match(comparison.body, /Windows x64 em validação/u);
        assert.match(comparison.body, /wisprflow\.ai\/pricing/u);
        assert.match(comparison.body, /application\/ld\+json/u);
        assert.match(comparison.body, /src="\.\.\/media\.mjs\?v=20261003-2"/u);
        assert.match(comparison.body, /src="\.\.\/release\.mjs\?v=20261004-4"/u);
        assert.match(comparison.body, /src="\.\.\/analytics\.mjs\?v=20261004-1"/u);
        assert.ok((comparison.body.match(/data-reveal/gu) ?? []).length >= 5);
        const robots = await get(preview.origin, prefix + 'robots.txt');
        assert.equal(robots.status, 200);
        assert.match(robots.body, /Sitemap: https:\/\/luisroquette\.github\.io\/resenha\/sitemap\.xml/u);
        const sitemap = await get(preview.origin, prefix + 'sitemap.xml');
        assert.equal(sitemap.status, 200);
        assert.match(sitemap.body, /alternativa-wispr-flow/u);
      } finally { await preview.close(); }
    }
  });
}
