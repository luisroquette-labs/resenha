import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { canonical, createSyntheticBundle, mutate, schemaErrors, sha256 } from './fixtures/windows-release/synthetic-fixture.mjs';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const schemaText = read('Windows/release-manifest.schema.json');
const schema = JSON.parse(schemaText);
const core = read('Windows/Resenha.Core/ReleasePolicy.cs');
const buildScript = read('Scripts/windows/build-release.ps1');
const verifyScript = read('Scripts/windows/verify-release.ps1');
const collectorScript = read('Scripts/windows/collect-physical-evidence.ps1');
const installer = read('Windows/Installer/Resenha.iss');
const fixtures = new Map(['candidate-ready', 'hosted-ready'].map(stage => [stage, JSON.parse(read(`Scripts/fixtures/windows-release/synthetic-${stage}.bundle.json`))]));
const { cases } = JSON.parse(read('Scripts/fixtures/windows-release/negative-cases.json'));

test('schema v1 and portable Core agree on the exact schema bytes', () => {
  assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
  assert.equal(schema.properties.schemaVersion.const, 1);
  assert.ok(core.includes(`SchemaSha256 = "${sha256(schemaText)}"`));
  const allowed = new Set(['$schema', '$id', 'title', 'description', '$defs', '$ref', 'type', 'properties', 'required', 'additionalProperties', 'const', 'enum', 'pattern', 'minLength', 'maxLength', 'minimum', 'maximum', 'items', 'minItems', 'maxItems', 'uniqueItems', 'oneOf']);
  const visit = rule => {
    for (const key of Object.keys(rule)) assert.ok(allowed.has(key), `unimplemented structural keyword: ${key}`);
    if (rule.properties) {
      assert.equal(rule.additionalProperties, false);
      assert.deepEqual(rule.required, Object.keys(rule.properties));
      Object.values(rule.properties).forEach(visit);
    }
    if (rule.$defs) Object.values(rule.$defs).forEach(visit);
    if (rule.items) visit(rule.items);
    if (rule.oneOf) rule.oneOf.forEach(visit);
    if (rule.$ref) assert.ok(schema.$defs[rule.$ref.slice(8)]);
  };
  visit(schema);
});

for (const [stage, bundle] of fixtures) {
  test(`${stage}: reproducible synthetic fixture has complete schema and byte-bound report DAG`, () => {
    assert.deepEqual(bundle, createSyntheticBundle(schema, stage));
    assert.deepEqual(schemaErrors(bundle.manifest, schema), []);
    assert.match(bundle.warning, /SYNTHETIC.*NEVER PROMOTE/);
    assert.equal(bundle.manifest.evidenceClass, 'synthetic');
    assert.equal(bundle.manifest.sha256, sha256(bundle.artifactUtf8));
    assert.equal(bundle.manifest.byteLength, Buffer.byteLength(bundle.artifactUtf8));
    assert.equal(bundle.manifest.payload.inventorySha256, sha256(canonical(bundle.manifest.payload.files)));
    for (const file of bundle.manifest.payload.files) {
      assert.equal(file.sha256, sha256(bundle.payloadUtf8[file.path]));
      assert.equal(file.byteLength, Buffer.byteLength(bundle.payloadUtf8[file.path]));
    }
    const groups = [['build', bundle.manifest.build, []], ['payload', bundle.manifest.payload, ['build']], ['signatures', bundle.manifest.signatures, ['payload']], ['scan', bundle.manifest.scan, ['signatures']], ...bundle.manifest.physical.map(run => [`physical-${run.os.name}`, run, ['scan']])];
    if (bundle.manifest.hosting) groups.push(['hosting', bundle.manifest.hosting, ['physical-windows10', 'physical-windows11']]);
    groups.push(['verification', bundle.manifest.verification, groups.map(([kind]) => kind)]);
    const seen = new Map();
    for (const [kind, group, dependencies] of groups) {
      const { report: reference, ...observations } = group;
      const bytes = bundle.evidenceFiles[reference.path];
      assert.equal(sha256(bytes), reference.sha256);
      assert.equal(reference.path, `reports/${kind}-${reference.sha256}.json`);
      const report = JSON.parse(bytes);
      assert.equal(report.evidenceClass, 'synthetic');
      assert.equal(report.artifactSha256, bundle.manifest.sha256);
      assert.equal(report.sourceCommit, bundle.expected.sourceCommit);
      assert.deepEqual(report.dependsOn, dependencies.map(kind => seen.get(kind)));
      assert.deepEqual(report.observations, observations);
      assert.equal('manifestSha256' in report, false);
      assert.equal('report' in report.observations, false);
      seen.set(kind, reference);
    }
    for (const [path, bytes] of Object.entries(bundle.evidenceFiles)) {
      if (path.startsWith('raw/')) assert.ok(path.endsWith(`-${sha256(bytes)}.json`));
    }
  });
}

for (const fixture of cases) {
  test(`schema contract: ${fixture.name} (${fixture.schemaValid ? 'requires semantic Core rejection' : 'rejected structurally'})`, () => {
    const bundle = mutate(fixtures.get('hosted-ready'), fixture);
    const errors = schemaErrors(bundle.manifest, schema);
    assert.equal(errors.length === 0, fixture.schemaValid, errors.join('\n'));
  });
}

test('every manifest group has a named missing-evidence regression', () => {
  const names = new Set(cases.map(fixture => fixture.name));
  assert.equal(names.size, cases.length);
  for (const key of schema.required) assert.ok(names.has(`missing-${key}`), key);
  assert.ok(cases.some(fixture => fixture.name === 'scan-stale-definitions' && fixture.error === 'scan.definitions-age'));
});

test('candidate staging carries no hosted proof or self-hash', () => {
  const candidate = fixtures.get('candidate-ready');
  assert.equal(candidate.manifest.hosting, null);
  assert.equal(candidate.manifest.verification.stage, 'candidate-ready');
  assert.equal(Object.keys(candidate.evidenceFiles).some(path => path.startsWith('reports/hosting-')), false);
  assert.equal('manifestSha256' in candidate.manifest, false);
  assert.equal('sha256' in candidate.manifest.verification, false);
  assert.match(core, /CanEnablePublicDownload => HostedReady/);
  assert.match(core, /var observed = S\(root, "evidenceClass"\) == "observed"/);
});

test('raw report byte tampering is detectable independently of success fields', () => {
  const bundle = fixtures.get('hosted-ready');
  const reference = bundle.manifest.scan.report;
  const original = bundle.evidenceFiles[reference.path];
  assert.equal(sha256(original), reference.sha256);
  assert.notEqual(sha256(`${original}\n`), reference.sha256);
  assert.notEqual(sha256(`${bundle.artifactUtf8}changed`), bundle.manifest.sha256);
});

test('native CLI path is consistent across payload, signatures and extracted byte map', () => {
  for (const bundle of fixtures.values()) {
    assert.ok(bundle.payloadUtf8['native/whisper-cli.exe']);
    assert.equal('whisper-cli.exe' in bundle.payloadUtf8, false);
    assert.ok(bundle.manifest.payload.files.some(file => file.path === 'native/whisper-cli.exe'));
    assert.equal(bundle.manifest.signatures.items.find(item => item.path === 'native/whisper-cli.exe').authority, 'release');
    assert.equal(bundle.manifest.signatures.items.some(item => item.path === 'whisper-cli.exe'), false);
  }
});

test('positive fixtures preserve a vendor signature predating build and release signatures after build', () => {
  for (const bundle of fixtures.values()) {
    const { signatures, build } = bundle.manifest;
    const vendor = signatures.items.find(item => item.authority === 'vendor');
    assert.ok(vendor.timestamp.atUtc < build.recordedAtUtc);
    assert.ok(vendor.timestamp.atUtc >= vendor.certificateNotBeforeUtc);
    assert.ok(vendor.timestamp.atUtc <= vendor.certificateNotAfterUtc);
    assert.ok(signatures.items.filter(item => item.authority === 'release').every(item => item.timestamp.atUtc >= build.recordedAtUtc));
  }
});

test('anglicism retention applies to PT-BR and Spanish only, while English must be not-applicable', () => {
  const rule = schema.$defs.physical.properties.corpus.items;
  const corpus = fixtures.get('hosted-ready').manifest.physical[0].corpus;
  for (const language of ['pt', 'es']) {
    const result = corpus.find(item => item.language === language);
    assert.deepEqual(schemaErrors({ ...result, anglicismRetention: 0.9 }, rule, schema), []);
    assert.ok(schemaErrors({ ...result, anglicismRetention: 0.89 }, rule, schema).length);
    assert.ok(schemaErrors({ ...result, anglicismRetention: 'not-applicable' }, rule, schema).length);
  }
  const english = corpus.find(item => item.language === 'en');
  assert.equal(english.anglicismRetention, 'not-applicable');
  assert.deepEqual(schemaErrors(english, rule, schema), []);
  assert.ok(schemaErrors({ ...english, anglicismRetention: 1 }, rule, schema).length);
});

test('release tooling fails closed and cannot publish or silently invent physical passes', () => {
  assert.match(buildScript, /approved-windows-host/u);
  assert.match(buildScript, /HasPrivateKey/u);
  assert.match(buildScript, /self-signed certificate cannot create a public release/u);
  assert.match(buildScript, /immutable artifact directory already exists/u);
  assert.match(buildScript, /signtool verify \/pa \/all \/v/u);
  assert.match(buildScript, /signed-candidate-awaiting-defender-and-physical-evidence/u);
  assert.match(verifyScript, /Get-AuthenticodeSignature/u);
  assert.match(verifyScript, /Get-MpComputerStatus/u);
  assert.match(verifyScript, /definitions are older than 24 hours/u);
  assert.match(verifyScript, /canEnablePublicDownload/u);
  assert.match(collectorScript, /Virtual hardware cannot produce physical release evidence/u);
  assert.match(collectorScript, /Exactly ten observed cycles are required/u);
  assert.match(collectorScript, /outcome -ne 'observed-pass'/u);
  assert.match(collectorScript, /At least 8 GiB of physical RAM is required/u);
  assert.match(collectorScript, /Only \$expectedCaption Home\/Pro is accepted/u);
  for (const script of [buildScript, verifyScript, collectorScript]) assert.doesNotMatch(script, /gh\s+release|Invoke-WebRequest|Start-BitsTransfer/u);
});

test('installer is per-user, signed, fixed-identity and owns only Resenha data', () => {
  assert.match(installer, /AppId=\{\{A83D31F2-02BC-4F04-A101-7120B87F8E38\}/u);
  assert.match(installer, /DefaultDirName=\{localappdata\}\\Programs\\Resenha/u);
  assert.match(installer, /PrivilegesRequired=lowest/u);
  assert.match(installer, /SignedUninstaller=yes/u);
  assert.match(installer, /SignTool=resenha/u);
  assert.match(installer, /Remove model and settings|Remover também o modelo local/u);
  assert.doesNotMatch(installer, /runascurrentuser|restartreplace|uninsneveruninstall/u);
});
