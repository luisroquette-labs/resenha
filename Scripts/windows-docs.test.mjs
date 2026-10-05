import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const paths = [
  'docs/specs/23-windows-mvp.md',
  'docs/specs/24-windows-store-msix.md',
  'docs/testing/WINDOWS-MVP-EVIDENCE.md',
  'docs/testing/WINDOWS-RELEASE-EVIDENCE.md',
  'docs/testing/WINDOWS-STORE-EVIDENCE.md',
  'README.md',
  'docs/architecture.md',
  'docs/specs/00-constitution.md',
  'docs/PRIVACY.md',
];
const docs = Object.fromEntries(paths.map(path => [path, readFileSync(resolve(root, path), 'utf8')]));
const spec = docs[paths[0]];
const storeSpec = docs[paths[1]];
const physical = docs[paths[2]];
const release = docs[paths[3]];
const storeEvidence = docs[paths[4]];

function requires(text, expressions) {
  for (const expression of expressions) assert.match(text, expression);
}

test('owned documentation links resolve, including the current task authority', () => {
  for (const [path, text] of Object.entries(docs)) {
    for (const [, href] of text.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
      if (/^(?:https?:|#)/.test(href)) continue;
      const target = resolve(dirname(resolve(root, path)), href.split('#')[0]);
      assert.ok(existsSync(target), `${path}: missing link ${href}`);
    }
  }
});

test('exact accepted OS/toolchain/CPU predicates are disclosed with vendor-support caveat', () => {
  requires(spec, [
    /Home\/Pro 22H2/, /10\.0\.19045/, /Home\/Pro 25H2/, /10\.0\.26200/,
    /not a claim of Microsoft Windows 10 or \.NET 10 vendor support/,
    /AVX2, FMA, F16C, SSE4\.2 and OS-enabled AVX state/,
    /8 GiB RAM/, /1 GiB free beyond/, /C# 14, WPF/, /10\.0\.401/,
    /10\.0\.12/, /net10\.0-windows10\.0\.19041\.0/, /MSTest\.Sdk `4\.4\.0`/,
    /rollForward: disable/, /Inno Setup 6\.7\.3/, /MSVC v143/,
    /unreviewed obsolete patch blocks release/,
  ]);
  for (const path of ['README.md', 'docs/architecture.md', 'docs/specs/00-constitution.md']) {
    requires(docs[path], [/10\.0\.19045/, /10\.0\.26200/, /AVX2/, /FMA/, /F16C/, /SSE4\.2/]);
  }
});

test('every CK/HR maps to a producer and initially pending observation ledgers', () => {
  const gates = [...Array.from({ length: 10 }, (_, i) => `CK-${i + 1}`), 'HR-1', 'HR-2', 'HR-3'];
  for (const gate of gates) {
    assert.ok(spec.includes(`| ${gate} |`), `${gate}: producer mapping missing`);
    for (const dossier of [physical, release]) {
      assert.ok(dossier.includes(`| ${gate} | pending |`), `${gate}: blank ledger missing`);
    }
  }
});

test('physical protocol covers ten recorded cycles on each OS and truthful execution boundaries', () => {
  requires(physical, [
    /No physical Windows run or host possession is established/,
    /VMs\/mocks\/cross-compiles supplement, never replace physical hardware/,
    /## Notepad and Chrome insertion protocol/, /ABNT2/, /AltGr/,
    /contenteditable/, /selected existing text/, /last-instant focus change/,
    /protected\/password\/read-only/, /## Ten cycles per OS/,
    /Windows 10 speech\/output/, /Windows 11 speech\/output/,
    /## Installation and owned-data removal/, /non-ASCII/,
  ]);
  const cycles = physical.split('## Ten cycles per OS')[1].split('## Offline corpus')[0];
  for (let i = 1; i <= 10; i++) {
    assert.ok(cycles.includes(`| ${String(i).padStart(2, '0')} | pending | pending |`));
  }
});

test('failure producers, retry safety, clipboard and RAM recovery are mandatory', () => {
  requires(physical, [
    /Microphone permission denied/, /Missing\/disabled endpoint/,
    /Disconnect during startup\/capture/, /Missing model/,
    /Corrupt\/wrong-size\/hash model/, /CLI crash\/nonzero/,
    /Inference timeout/, /Clipboard contention/, /External clipboard replacement/,
    /Blocked\/partial\/ambiguous SendInput/, /TargetBroker timeout/,
    /Lost release/, /Lock\/suspend/, /Forced termination\/next launch/,
    /Stale completion/, /Audio stop acknowledgment missing/,
  ]);
  requires(spec, [
    /Write failure preserves completed text in RAM/, /Copy again/,
    /No automatic insertion retry/, /not confirmed editor acceptance/,
    /residual last-instant focus races exist/, /before any input dispatch/,
  ]);
});

test('offline corpus declares real inference, quality normalization and cleanup observations', () => {
  requires(physical, [
    /five utterances per language/, /PT-BR\/EN\/ES/, /disconnect networking/,
    /substitutions \+ deletions \+ insertions/, /do not remove substantive words/,
    /≤20% WER/, /≥90%/, /Silence \/ empty \/ short input/,
    /Success\/error\/cancel\/exit\/next-start/, /Cold\/warm seconds/,
    /reference commit \/ audio hashes/,
  ]);
  requires(spec, [
    /190085487/, /ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb/,
    /4979e04f5dcaccb36057e059bbaed8a2f5288315/,
    /No cloud audio, paid AI API, backend, account, telemetry or disk transcript history/,
  ]);
});

test('release templates have no prefilled successes and bind exact bytes to every downstream gate', () => {
  for (const dossier of [physical, release]) {
    assert.doesNotMatch(dossier, /\|\s*(?:PASS|PASSED|SUCCESS|COMPLETE|VERIFIED|true)\s*\|/i);
    const lines = dossier.split('\n');
    const observationRows = lines.filter((line, index) =>
      line.startsWith('| ') && !line.startsWith('| ---') && !lines[index + 1]?.startsWith('| ---'));
    // Every non-header table row in a blank evidence template must remain pending.
    for (const row of observationRows) {
      assert.ok(row.includes('pending'), `prefilled observation: ${row}`);
    }
  }
  requires(release, [
    /exact final|exact tested final/, /source SHA/, /SHA-256/, /RFC 3161/,
    /Per-PE signature/, /Installer and uninstaller signature/,
    /Definitions must\nbe at most 24 hours old/, /detections \/ remediations/,
    /Repackaging or signing after scan\/QA invalidates/,
    /Windows 10 observed value/, /Windows 11 observed value/,
    /Mark of the Web/, /SmartScreen/, /external checksum/,
    /unchanged/, /Latest PR SHA/, /Merge commit \/ main CI terminal state/,
    /No certificate, physical\nhost/, /download remains unavailable/,
  ]);
});

test('privacy and required-form contract preserve owned data and separate macOS history', () => {
  requires(docs['docs/PRIVACY.md'], [
    /não afirma uma versão Windows publicada/, /WASAPI local/, /offline/,
    /histórico opcional do macOS não se aplica ao Windows/,
    /somente em RAM/, /Copiar novamente/, /reparse points/,
    /sucesso, erro, cancelamento, saída/, /Não prometemos apagamento/,
    /Remover modelo e configurações, selecionado por/, /arquivo original importado/,
    /nome, email e WhatsApp/, /redirect dedicado permanecem pendentes/,
  ]);
  requires(spec, [
    /mandatory/, /dedicated form/, /wrong form/, /duplicate\/stale success/,
    /not\naccess control/, /Never\nrun `next build`/,
  ]);
});

test('Store MSIX spec keeps trusted consumer distribution separate from test EXE', () => {
  requires(storeSpec, [
    /primary Windows consumer distribution/u, /Microsoft signs an accepted MSIX/u,
    /exact package identity and publisher values copied from Partner Center/u,
    /SYNTHETIC-NOT-FOR-SUBMISSION/u, /never represented as the final app/u,
    /Windows\.FullTrustApplication/u, /runFullTrust/u, /microphone/u,
    /MSIX-001/u, /MSIX-007/u, /Store\s+acknowledgement is not certification/u,
  ]);
  requires(storeEvidence, [
    /Partner Center identity/u, /exact candidate SHA-256/u,
    /certification result/iu, /clean physical Store install/iu,
    /SmartScreen/u, /pending/u,
  ]);
});
