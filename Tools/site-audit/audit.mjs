import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { tmpdir, platform, release, arch } from 'node:os';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, webkit } from 'playwright';
import AxeBuilder from '@axe-core/playwright';
import lighthouse from 'lighthouse';
import { createPreviewServer } from '../../Scripts/site.mjs';
import { destinationFixtures } from '../../Scripts/site.test.mjs';
import { releaseState, resolveDestination } from '../../site/release.mjs';

const repo = fileURLToPath(new URL('../../', import.meta.url));
const output = join(repo, 'build/site-audit');
const mode = process.argv.slice(2);
assert.ok(mode.length === 1 && ['--browser', '--lighthouse'].includes(mode[0]), 'Use exactly --browser or --lighthouse');
const kind = mode[0].slice(2);
const directory = join(output, kind);
await mkdir(directory, { recursive: true });
const results = [], network = [], owned = [];
const save = (name, value) => writeFile(join(directory, name), JSON.stringify(value, null, 2) + '\n');
const check = async (name, run) => {
  try { const evidence = await run(); results.push({ name, status: 'PASS', evidence }); console.log(`PASS ${name}`); }
  catch (error) { results.push({ name, status: 'FAIL', error: error.stack }); console.error(`FAIL ${name}: ${error.message}`); }
  await save('results.json', results);
};
const hash = async file => createHash('sha256').update(await readFile(join(repo, file))).digest('hex');
const fingerprints = {};
for (const file of ['site/index.html', 'site/styles.css', 'site/release.mjs', 'Scripts/site.mjs',
  'Scripts/site.test.mjs', 'Tools/site-audit/audit.mjs', 'Tools/site-audit/package.json', 'Tools/site-audit/package-lock.json']) fingerprints[file] = await hash(file);
const packages = {};
for (const name of ['playwright', '@axe-core/playwright', 'lighthouse']) {
  packages[name] = JSON.parse(await readFile(new URL(`node_modules/${name}/package.json`, import.meta.url), 'utf8')).version;
}
const environment = { startedAt: new Date().toISOString(), node: process.version, os: `${platform()} ${release()} ${arch()}`,
  packages,
  fingerprints, revision: 'Unborn repository: SHA-256 manifest identifies exact tested files', labOnly: true };
await save('environment.json', environment);

// An owned deny-only loopback proxy also blocks browser background outbound traffic.
const proxy = createServer((req, res) => { network.push({ action: 'proxy-blocked', url: req.url }); res.writeHead(403); res.end(); });
proxy.on('connect', (req, socket) => { network.push({ action: 'proxy-blocked-connect', url: req.url }); socket.end('HTTP/1.1 403 Forbidden\r\n\r\n'); });
await new Promise(accept => proxy.listen(0, '127.0.0.1', accept));
owned.push(() => new Promise(accept => proxy.close(accept)));
const browserArgs = [`--proxy-server=http://127.0.0.1:${proxy.address().port}`, '--proxy-bypass-list=127.0.0.1',
  '--disable-background-networking', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1'];

async function guard(context, origin) {
  await context.route('**/*', async route => {
    const url = route.request().url();
    if (new URL(url).origin === origin) { network.push({ action: 'local', url }); await route.continue(); }
    else { network.push({ action: 'intercepted', url }); await route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><title>Intercepted synthetic action</title>' }); }
  });
}
async function dimensions(page) {
  return page.evaluate(() => ({ innerWidth, innerHeight, clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth, dpr: devicePixelRatio,
    clipped: [...document.querySelectorAll('a,summary,h1,h2,h3,p,dt,dd')].filter(el => {
      if (el.classList.contains('skip-link')) return false;
      const rect = el.getBoundingClientRect(); return rect.width && (rect.left < -1 || rect.right > innerWidth + 1 || el.scrollWidth > el.clientWidth + 1);
    }).map(el => ({ tag: el.tagName, text: el.textContent.trim().slice(0, 80), rect: el.getBoundingClientRect().toJSON() })) }));
}
async function responsive(page, name, enforce = true) {
  const size = await dimensions(page);
  let screenshot;
  if (name.startsWith('actual-zoom-')) {
    // Browser zoom changes DIP layout coordinates. Playwright's CSS-sized full-page
    // clip otherwise crops the right half at 200%; capture the real DIP surface.
    const session = await page.context().newCDPSession(page);
    try {
      const { contentSize } = await session.send('Page.getLayoutMetrics');
      const capture = await session.send('Page.captureScreenshot', { format: 'png', fromSurface: true,
        captureBeyondViewport: true, clip: { x: 0, y: 0, width: contentSize.width, height: contentSize.height, scale: 1 } });
      screenshot = Buffer.from(capture.data, 'base64'); await writeFile(join(directory, `${name}.png`), screenshot);
    } finally { await session.detach(); }
  } else screenshot = await page.screenshot({ path: join(directory, `${name}.png`), fullPage: true });
  size.screenshotPixels = { width: screenshot.readUInt32BE(16), height: screenshot.readUInt32BE(20) };
  assert.ok(Math.abs(size.screenshotPixels.width - size.clientWidth * size.dpr) <= 2, 'Screenshot must cover the complete browser-zoom surface');
  await save(`${name}.json`, size);
  if (enforce) { assert.ok(size.scrollWidth <= size.clientWidth + 1, `${name}: document overflow ${size.scrollWidth}/${size.clientWidth}`); assert.deepEqual(size.clipped, [], `${name}: clipped essential content`); }
  return { ...size, screenshot: `${name}.png` };
}
async function content(page) {
  const text = await page.locator('body').innerText();
  for (const phrase of ['Resenha', 'Segure a tecla.', 'Fale do seu jeito.', 'Solte. Está escrito.', 'cursor original',
    'Right Option', 'planejada', 'whisper.cpp', 'OpenAI', 'áudio será enviado', 'cobrança separada',
    'não recebe chaves', 'Apache 2.0', 'WinUI', 'Rust', 'não há instalador independente', 'Windows ainda não foi implementada',
    'Prévia ilustrativa', 'compatibilidade varia', 'validação de uso ainda está em andamento']) assert.ok(text.toLocaleLowerCase('pt-BR').includes(phrase.toLocaleLowerCase('pt-BR')), `Missing honest content: ${phrase}`);
  assert.equal(await page.locator('form,input,iframe,audio,video').count(), 0);
  assert.equal(await page.locator('a[href^="http"]').count(), 0);
  assert.equal(await page.locator('link[rel="canonical"],meta[property="og:url"],script[type="application/ld+json"]').count(), 0);
  assert.equal(await page.locator('html').getAttribute('lang'), 'pt-BR');
  assert.match(await page.title(), /Resenha.*desenvolvimento/u);
  assert.match(await page.locator('meta[name="description"]').getAttribute('content'), /desenvolvimento.*Windows planejado/u);
  await save('visible-copy.json', { text, title: await page.title() });
  return { text: 'visible-copy.json', forbiddenInteractiveElements: 0, externalLinks: 0 };
}
async function adapter(page, base, fixture) {
  await page.goto(base);
  const channel = fixture.channel;
  const slotChannel = channel === 'other' ? 'macos' : channel;
  await page.evaluate(async ({ base, channel, slotChannel, record }) => {
    const { applyReleaseState } = await import(new URL('release.mjs', base).href);
    const slot = document.querySelector(`[data-release-channel="${slotChannel}"]`);
    slot.dataset.releaseChannel = channel;
    applyReleaseState(document, { [channel]: record });
  }, { base, channel, slotChannel, record: fixture.record });
  const slot = page.locator(`[data-release-channel="${channel}"]`);
  const expected = resolveDestination(channel, fixture.record);
  assert.equal(await slot.locator('a').count(), fixture.active ? 1 : 0);
  assert.equal(await slot.locator('.release-action').innerText(), expected.label);
  assert.equal(await slot.locator('.release-reason').innerText(), expected.reason);
  return slot;
}
async function destinations(page, base) {
  for (const fixture of destinationFixtures) {
    await check(`CK-7 adapter ${fixture.name}`, async () => {
      const slot = await adapter(page, base, fixture);
      if (!fixture.active) assert.equal(await slot.locator('.release-action').getAttribute('aria-disabled'), 'true');
      else assert.equal(await slot.locator('a').getAttribute('href'), fixture.record.url);
      return { channel: fixture.channel, active: fixture.active };
    });
    for (const action of ['mouse', 'keyboard']) await check(`CK-7 ${action} ${fixture.name}`, async () => {
      const slot = await adapter(page, base, fixture);
      const initial = page.url(), offset = network.length;
      let downloads = 0; const onDownload = () => { downloads++; }; page.on('download', onDownload);
      try {
        if (fixture.active) {
          const reached = page.waitForURL(fixture.record.url);
          if (action === 'mouse') await slot.locator('a').click();
          else { await slot.locator('a').focus(); await page.keyboard.press('Enter'); }
          await reached;
          assert.ok(network.slice(offset).some(entry => entry.action === 'intercepted' && entry.url === fixture.record.url));
        } else {
          if (action === 'mouse') await slot.locator('.release-action').click();
          else {
            const focusable = await slot.evaluate(el => [...el.querySelectorAll('*')].some(node => node.tabIndex >= 0));
            assert.equal(focusable, false, 'Inactive slot must not enter keyboard order');
            // A real keyboard activation attempt cannot focus a non-action status span.
            await slot.locator('.release-action').evaluate(el => el.focus());
            await page.keyboard.press('Enter'); await page.keyboard.press('Space');
          }
          await page.waitForTimeout(80);
          assert.equal(page.url(), initial); assert.equal(downloads, 0);
          assert.equal(network.slice(offset).filter(entry => entry.action !== 'proxy-blocked').length, 0);
        }
        return { intercepted: fixture.active, navigated: fixture.active, downloads };
      } finally { page.off('download', onDownload); }
    });
  }
}
async function keyboard(page, base) {
  await page.goto(base);
  const controls = await page.locator('a,summary').count();
  await page.locator('a,summary').evaluateAll(elements => elements.forEach((el, i) => el.dataset.auditOrder = i));
  const trace = [];
  for (let i = 0; i < controls; i++) {
    await page.keyboard.press('Tab');
    const focus = await page.evaluate(() => {
      const el = document.activeElement, css = getComputedStyle(el), rect = el.getBoundingClientRect();
      return { order: Number(el.dataset.auditOrder), name: el.getAttribute('aria-label') || el.textContent.trim(), tag: el.tagName,
        outline: css.outlineStyle, outlineWidth: css.outlineWidth, outlineColor: css.outlineColor, rect: rect.toJSON(), viewport: { innerWidth, innerHeight } };
    });
    trace.push(focus); assert.equal(focus.order, i); assert.ok(focus.name);
    assert.ok(focus.outline !== 'none' && parseFloat(focus.outlineWidth) >= 3);
    assert.ok(focus.rect.left >= 0 && focus.rect.right <= focus.viewport.innerWidth + 1);
    assert.ok(focus.rect.top >= 0 && focus.rect.bottom <= focus.viewport.innerHeight + 1);
  }
  await save('focus-trace.json', trace);
  await page.keyboard.press('Tab'); await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(() => document.activeElement.dataset.auditOrder), '0', 'Tab exits last control and returns to first');
  await page.keyboard.press('Enter'); assert.equal(new URL(page.url()).hash, '#conteudo');
  await page.goto(base);
  for (let i = 0; i < 5; i++) await page.keyboard.press('Tab');
  await page.keyboard.press('Enter'); assert.equal(new URL(page.url()).hash, '#download');
  for (const summary of await page.locator('summary').all()) {
    await summary.focus(); await page.keyboard.press('Enter'); assert.equal(await summary.locator('..').getAttribute('open'), '');
    await page.keyboard.press('Space'); assert.equal(await summary.locator('..').getAttribute('open'), null);
  }
  await page.screenshot({ path: join(directory, 'keyboard-faq-focus.png'), fullPage: true });
  return { controls, trace: 'focus-trace.json', faqCount: await page.locator('summary').count() };
}
async function accessibility(page, name) {
  const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
  await save(`axe-${name}.json`, result);
  assert.deepEqual(result.violations, [], `${name}: axe violations`);
  const contrastReview = [];
  for (const incomplete of result.incomplete) {
    assert.equal(incomplete.id, 'color-contrast', 'Unexpected indeterminate axe rule requires review');
    for (const node of incomplete.nodes) {
      assert.equal(node.target.length, 1, 'Nested target needs explicit review');
      const selector = node.target[0];
      const review = await page.locator(selector).evaluate(el => {
        const style = getComputedStyle(el);
        if (el.getAttribute('aria-hidden') === 'true' && !/[\p{L}\p{N}]/u.test(el.textContent)) {
          return { kind: 'decorative non-text symbol', hiddenFromAT: true, text: el.textContent, selector: el.outerHTML };
        }
        let parent = el, base;
        while (parent && !base) {
          const color = getComputedStyle(parent).backgroundColor;
          if (!color.includes('rgba') || !color.endsWith(', 0)')) base = color;
          parent = parent.parentElement;
        }
        return { kind: 'gradient text', foreground: style.color, background: base, image: style.backgroundImage };
      });
      if (review.kind === 'gradient text') {
        assert.ok(review.image.startsWith('repeating-linear-gradient('), 'Only inspected ruled-note gradient supported');
        const colors = [...review.image.matchAll(/rgba?\([^)]+\)/gu)].map(match => match[0]);
        const luminance = color => {
          const channels = color.match(/[\d.]+/gu).map(Number);
          assert.ok(channels.length === 3 || channels[3] === 0 || channels[3] === 1, 'Partial transparency needs compositing review');
          return channels.slice(0, 3).map(value => value / 255).map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4)
            .reduce((sum, value, index) => sum + value * [.2126, .7152, .0722][index], 0);
        };
        const foreground = luminance(review.foreground);
        review.backgrounds = [review.background, ...colors.filter(color => !color.endsWith(', 0)'))];
        review.ratios = review.backgrounds.map(color => {
          const background = luminance(color); return (Math.max(foreground, background) + .05) / (Math.min(foreground, background) + .05);
        });
        assert.ok(review.ratios.every(value => value >= 4.5), 'Every ruled-note background must meet normal-text AA contrast');
      }
      contrastReview.push({ selector, ...review });
    }
  }
  await save(`contrast-${name}.json`, contrastReview);
  assert.equal(await page.locator('h1').count(), 1); assert.equal(await page.locator('main').count(), 1);
  assert.equal(await page.locator('header nav[aria-label],footer').count(), 2);
  assert.equal(await page.locator('svg:not([aria-hidden="true"]):not(.preview-hud svg)').count(), 0);
  assert.equal(await page.locator('img:not([alt])').count(), 0);
  assert.match(await page.locator('figure figcaption').innerText(), /Prévia ilustrativa/iu);
  return { report: `axe-${name}.json`, violations: 0, rawIncomplete: result.incomplete.map(item => ({ id: item.id, impact: item.impact })),
    unresolved: 0, supplementalReview: `contrast-${name}.json`, resolvedNodes: contrastReview.length };
}
async function browserAudit() {
  const browser = await chromium.launch({ args: browserArgs }); owned.push(() => browser.close());
  environment.browser = browser.version(); await save('environment.json', environment);
  const css = await readFile(join(repo, 'site/styles.css'), 'utf8');
  const breakpoints = [...new Set([...css.matchAll(/@media\s*\([^)]*(?:max|min)-width\s*:\s*(\d+)px[^)]*\)/gu)].map(match => Number(match[1])))];
  await save('breakpoints.json', { discovered: breakpoints, source: fingerprints['site/styles.css'] });
  for (const prefix of ['/', '/resenha/']) {
    const server = await createPreviewServer({ prefix }); owned.push(server.close);
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block' });
    owned.push(() => context.close()); await guard(context, server.origin);
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    const page = await context.newPage(); await page.goto(server.url);
    const essentialText = await page.evaluate(() => {
      const clone = document.body.cloneNode(true); clone.querySelectorAll('[data-release-channel],script').forEach(el => el.remove());
      return clone.textContent.replace(/\s+/gu, ' ').trim();
    });
    const suffix = prefix === '/' ? 'root' : 'subpath';
    await check(`CK-1–6/8/11 honest content ${suffix}`, () => content(page));
    await check(`CK-7/15 default slots ${suffix}`, async () => {
      for (const channel of ['macos', 'source', 'store']) {
        const slot = page.locator(`[data-release-channel="${channel}"]`);
        assert.equal(await slot.locator('a').count(), 0); assert.ok((await slot.innerText()).length > 30);
      }
      assert.equal(await page.locator('.site-header a[href="#download"],.hero a[href="#download"],.closing a[href="#download"]').count(), 3);
      return { sharedLocalDownloadAnchors: 3, inactiveSlots: 3 };
    });
    const widths = [...new Set([319, 320, 321, 768, 1440, ...breakpoints.flatMap(value => [value - 1, value, value + 1])])].sort((a, b) => a - b);
    for (const width of widths) await check(`CK-9 ${suffix} width ${width}`, async () => {
      await page.setViewportSize({ width, height: 1000 }); return responsive(page, `${suffix}-${width}`, width >= 320);
    });
    await page.setViewportSize({ width: 1440, height: 1000 }); await page.goto(server.url);
    await check(`CK-10 axe ${suffix} desktop`, () => accessibility(page, `${suffix}-desktop`));
    await page.setViewportSize({ width: 320, height: 1000 });
    await check(`CK-10 axe ${suffix} mobile`, () => accessibility(page, `${suffix}-mobile`));
    await page.setViewportSize({ width: 1440, height: 1000 });
    await check(`CK-10 keyboard/FAQ ${suffix}`, () => keyboard(page, server.url));
    if (prefix === '/') await destinations(page, server.url);
    else {
      for (const fixture of [destinationFixtures[0], ...destinationFixtures.slice(28)]) await check(`CK-7 subpath adapter ${fixture.name}`, async () => {
        await adapter(page, server.url, fixture); return { active: fixture.active };
      });
    }
    await context.tracing.stop({ path: join(directory, `trace-${suffix}.zip`) }); await context.close();
    for (const variant of ['no-js', 'reduced-motion', 'dark']) await check(`CK-10/15 ${suffix} ${variant}`, async () => {
      const options = { viewport: { width: 768, height: 1000 }, serviceWorkers: 'block',
        javaScriptEnabled: variant !== 'no-js', reducedMotion: variant === 'reduced-motion' ? 'reduce' : 'no-preference', colorScheme: variant === 'dark' ? 'dark' : 'light' };
      const variantContext = await browser.newContext(options);
      try {
        await guard(variantContext, server.origin); const variantPage = await variantContext.newPage(); await variantPage.goto(server.url);
        await content(variantPage);
        const equivalentText = await variantPage.evaluate(() => {
          const clone = document.body.cloneNode(true); clone.querySelectorAll('[data-release-channel],script').forEach(el => el.remove());
          return clone.textContent.replace(/\s+/gu, ' ').trim();
        });
        assert.equal(equivalentText, essentialText, 'No-JS/motion/appearance must retain identical essential content');
        assert.equal(await variantPage.locator('[data-release-channel] a').count(), 0);
        for (const summary of await variantPage.locator('summary').all()) { await summary.click(); assert.equal(await summary.locator('..').getAttribute('open'), ''); }
        if (variant !== 'no-js') {
          assert.equal(await variantPage.evaluate(() => document.getAnimations().length), 0);
          if (variant === 'reduced-motion') assert.equal(await variantPage.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches), true);
          await accessibility(variantPage, `${suffix}-${variant}`);
        }
        return { ...await responsive(variantPage, `${suffix}-${variant}`), options, faqAccessibleWithoutEnhancement: true };
      } finally { await variantContext.close(); }
    });
    if (prefix === '/') {
      await check('CK-9 actual browser 200% zoom', () => actualZoom(server));
      await check('CK-10 local WebKit smoke', async () => {
        const webkitBrowser = await webkit.launch();
        try {
          const webkitContext = await webkitBrowser.newContext({ viewport: { width: 768, height: 1000 } });
          await guard(webkitContext, server.origin); const webkitPage = await webkitContext.newPage(); await webkitPage.goto(server.url);
          await content(webkitPage); await webkitPage.locator('summary').first().click();
          assert.equal(await webkitPage.locator('details').first().getAttribute('open'), '');
          return { browser: 'Playwright WebKit, not a claim of Safari UI validation', version: webkitBrowser.version(), ...await responsive(webkitPage, 'webkit-smoke') };
        } finally { await webkitBrowser.close(); }
      });
    }
  }
}
async function actualZoom(server) {
  // tabs.setZoom is browser zoom, unlike DPR, CSS zoom or pinch/page scale.
  const extension = join(directory, 'zoom-extension'); await mkdir(extension, { recursive: true });
  await writeFile(join(extension, 'manifest.json'), JSON.stringify({ manifest_version: 3, name: 'Local audit zoom observation', version: '1.0',
    permissions: ['tabs'], host_permissions: ['http://127.0.0.1/*'], background: { service_worker: 'worker.js' } }));
  await writeFile(join(extension, 'worker.js'), 'chrome.runtime.onInstalled.addListener(() => {});\n');
  const profile = await mkdtemp(join(tmpdir(), 'resenha-zoom-'));
  let context;
  try {
    context = await chromium.launchPersistentContext(profile, { channel: 'chromium', headless: true, viewport: null,
      args: [...browserArgs, '--window-size=1440,1000', `--disable-extensions-except=${extension}`, `--load-extension=${extension}`] });
    await guard(context, server.origin);
    const worker = context.serviceWorkers()[0] ?? await context.waitForEvent('serviceworker', { timeout: 10000 });
    const page = await context.newPage(); await page.goto(server.url);
    const before = await dimensions(page);
    const observed = await worker.evaluate(async url => {
      const tab = (await chrome.tabs.query({})).find(item => item.url === url);
      if (!tab) throw new Error('Local tab missing');
      await chrome.tabs.setZoom(tab.id, 2);
      return { zoom: await chrome.tabs.getZoom(tab.id), settings: await chrome.tabs.getZoomSettings(tab.id) };
    }, server.url);
    await page.waitForFunction(width => innerWidth <= width / 2 + 2, before.innerWidth);
    assert.equal(observed.zoom, 2); const after = await responsive(page, 'actual-zoom-200');
    assert.ok(after.innerWidth <= before.innerWidth / 2 + 2, 'Browser layout viewport must change at real zoom');
    await accessibility(page, 'actual-zoom-200');
    const session = await context.newCDPSession(page);
    const { windowId } = await session.send('Browser.getWindowForTarget');
    const sizes = [];
    for (const width of [320, 768, 1440]) {
      await session.send('Browser.setWindowBounds', { windowId, bounds: { width: width * 2, height: 1400 } });
      await page.waitForFunction(expected => Math.abs(innerWidth - expected) <= 1, width);
      const zoom = await worker.evaluate(async url => {
        const tab = (await chrome.tabs.query({})).find(item => item.url === url); return chrome.tabs.getZoom(tab.id);
      }, server.url);
      assert.equal(zoom, 2);
      sizes.push({ width, zoom, ...await responsive(page, `actual-zoom-200-${width}`) });
    }
    const evidence = { method: 'Chromium MV3 chrome.tabs.setZoom(2), getZoom verified; viewport:null, no DPR/CSS/page-scale override',
      sources: ['https://playwright.dev/docs/chrome-extensions', 'https://developer.chrome.com/docs/extensions/reference/api/tabs#method-setZoom'], before, after, observed, sizes };
    await save('actual-zoom-200-observation.json', evidence); return evidence;
  } finally { if (context) await context.close(); await rm(profile, { recursive: true, force: true }); }
}
async function lighthouseAudit() {
  const server = await createPreviewServer(); owned.push(server.close);
  const reservation = createServer(); await new Promise(accept => reservation.listen(0, '127.0.0.1', accept));
  const port = reservation.address().port; await new Promise(accept => reservation.close(accept));
  const browser = await chromium.launch({ args: [...browserArgs, `--remote-debugging-port=${port}`] }); owned.push(() => browser.close());
  environment.browser = browser.version(); environment.preset = { formFactor: 'mobile', throttlingMethod: 'simulate',
    screenEmulation: { mobile: true, width: 412, height: 823, deviceScaleFactor: 1.75, disabled: false },
    onlyCategories: ['performance'], locale: 'pt-BR', runs: 3, serial: true, staticFilesNoCompilation: true };
  await save('environment.json', environment);
  const runs = [];
  for (let run = 1; run <= 3; run++) await check(`CK-12 mobile Lighthouse run ${run}`, async () => {
    const result = await lighthouse(server.url, { port, output: ['json', 'html'], ...environment.preset,
      blockedUrlPatterns: ['https://*', '*example.invalid*'] });
    assert.ok(result && !result.lhr.runtimeError, JSON.stringify(result?.lhr.runtimeError));
    await writeFile(join(directory, `mobile-${run}.json`), result.report[0]);
    await writeFile(join(directory, `mobile-${run}.html`), result.report[1]);
    const requests = result.lhr.audits['network-requests'].details.items;
    assert.ok(requests.every(item => new URL(item.url).origin === server.origin), 'Lighthouse requested an external resource');
    const metrics = { run, LCP: result.lhr.audits['largest-contentful-paint'].numericValue,
      CLS: result.lhr.audits['cumulative-layout-shift'].numericValue, TBT: result.lhr.audits['total-blocking-time'].numericValue,
      report: `mobile-${run}.json`, html: `mobile-${run}.html`, lighthouseVersion: result.lhr.lighthouseVersion,
      configSettings: result.lhr.configSettings, requests: requests.map(item => item.url) };
    runs.push(metrics); return metrics;
  });
  await check('CK-12 median mobile lab targets', async () => {
    assert.equal(runs.length, 3, 'Three successful serial runs required');
    const median = key => runs.map(run => run[key]).sort((a, b) => a - b)[1];
    const medians = { LCP: median('LCP'), CLS: median('CLS'), TBT: median('TBT') };
    await save('median-summary.json', { labOnly: true, units: { LCP: 'ms', TBT: 'ms', CLS: 'unitless' }, runs, medians });
    assert.ok(medians.LCP <= 2500); assert.ok(medians.CLS <= 0.1); assert.ok(medians.TBT <= 200); return medians;
  });
}
try {
  if (kind === 'browser') await browserAudit(); else await lighthouseAudit();
  await check('CK-13 intercepted destinations only', async () => {
    const permitted = new Set(destinationFixtures.filter(item => item.active).map(item => item.record.url));
    const intercepted = network.filter(item => item.action === 'intercepted');
    assert.ok(intercepted.every(item => permitted.has(item.url)), 'Unexpected external site request');
    return { interceptedSyntheticActions: intercepted.length, escapedRequests: 0, denyProxyBlocks: network.filter(item => item.action.startsWith('proxy-blocked')).length };
  });
  await check('CK-13 unchanged tested static files', async () => {
    for (const [file, before] of Object.entries(fingerprints)) assert.equal(await hash(file), before, `Changed during audit: ${file}`);
    return { unchanged: Object.keys(fingerprints), paidCalls: 0, publication: false, nativeAcceptance: 'Not performed by site audit' };
  });
} catch (error) { results.push({ name: 'required runner/tooling', status: 'FAIL', error: error.stack }); console.error(error); }
finally {
  for (const close of owned.reverse()) { try { await close(); } catch (error) { results.push({ name: 'owned resource cleanup', status: 'FAIL', error: String(error) }); } }
  await save('network-trace.json', network); await save('results.json', results);
  await save('summary.json', { finishedAt: new Date().toISOString(), passed: results.filter(result => result.status === 'PASS').length,
    failed: results.filter(result => result.status === 'FAIL').length, results: 'results.json', network: 'network-trace.json', environment: 'environment.json' });
  if (results.some(result => result.status === 'FAIL')) process.exitCode = 1;
}
