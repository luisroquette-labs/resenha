// TEST DATA ONLY. No Windows process, signature, scan or hardware observation runs here.
import { createHash } from 'node:crypto';

export const sha256 = value => createHash('sha256').update(value).digest('hex');
export function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  return JSON.stringify(value);
}

export function createSyntheticBundle(schema, stage = 'hosted-ready') {
  const artifactUtf8 = 'MZ SYNTHETIC TEST DATA ONLY - NOT AN EXECUTABLE\n';
  const sourceCommit = '1'.repeat(40);
  const version = '0.0.0';
  const publisher = 'SYNTHETIC TEST PUBLISHER - NOT A CERTIFICATE';
  const certificateThumbprint = 'A'.repeat(40);
  const toolSha256 = sha256('SYNTHETIC verifier - no validation executed');
  const evidenceFiles = {};
  const payloadUtf8 = Object.fromEntries(['Resenha.exe', 'Resenha.TargetBroker.exe', 'native/whisper-cli.exe', 'runtime/System.Runtime.dll', 'unins000.exe', 'LICENSES.txt'].sort().map(path => [path, `${/\.(exe|dll)$/.test(path) ? 'MZ ' : ''}SYNTHETIC TEST DATA ONLY ${path}\n`]));
  const raw = label => {
    const content = JSON.stringify({ synthetic: true, observation: `SYNTHETIC ONLY: ${label}; no native test was executed.` });
    const hash = sha256(content);
    const path = `raw/${label}-${hash}.json`;
    evidenceFiles[path] = content;
    return { path, sha256: hash };
  };
  const pin = path => {
    const content = `SYNTHETIC INPUT ONLY: ${path}`;
    evidenceFiles[path] = content;
    return { path, sha256: sha256(content) };
  };
  const os = name => ({ name, edition: 'Pro', release: name === 'windows10' ? '22H2' : '25H2', build: name === 'windows10' ? '10.0.19045.9999' : '10.0.26200.9999', architecture: 'x64' });
  const model = structuredClone(schema.properties.model.properties);
  for (const key of Object.keys(model)) model[key] = model[key].const;
  const files = Object.entries(payloadUtf8).map(([path, content]) => ({ path, byteLength: Buffer.byteLength(content), sha256: sha256(content), isPe: content.startsWith('MZ') }));
  const toolchain = Object.fromEntries(Object.entries(schema.$defs.build.properties.toolchain.properties).map(([key, rule]) => [key, rule.const ?? (key.endsWith('Sha256') ? sha256(`SYNTHETIC ${key}`) : key === 'powerShellVersion' ? '7.0.0' : `SYNTHETIC-${key}`)]));
  const manifest = {
    schemaVersion: 1, evidenceClass: 'synthetic', stage, platform: 'windows', architecture: 'x64', version,
    filename: `Resenha-${version}-windows-x64-setup.exe`, byteLength: Buffer.byteLength(artifactUtf8), sha256: sha256(artifactUtf8), sourceCommit,
    whisperCommit: schema.properties.whisperCommit.const, model, requirements: structuredClone(schema.properties.requirements.const),
    build: { recordedAtUtc: '2026-10-04T10:00:00Z', host: { os: os('windows11'), physical: true, authorizationReference: 'SYNTHETIC-NO-HOST-AUTHORIZATION' }, sourceCommit, toolchain,
      preflight: { sourceCommit, exitCode: 0, totalTests: 1, skippedTests: 0, report: raw('preflight') },
      inputs: ['Windows/global.json', 'Windows/toolchain-lock.json', 'Windows/native/CMakePresets.json', 'Windows/model-manifest.json', ...['Resenha.Core', 'Resenha.Core.Tests', 'Resenha.Platform', 'Resenha.Platform.Tests', 'Resenha.ReleaseVerifier', 'Resenha.TargetBroker', 'Resenha.Windows'].map(project => `Windows/${project}/packages.lock.json`)].map(pin) },
    payload: { inventorySha256: sha256(canonical(files)), files },
    signatures: { verifiedAtUtc: '2026-10-04T10:20:00Z', publisher, certificateThumbprint,
      items: [...files.filter(file => file.isPe), { path: `Resenha-${version}-windows-x64-setup.exe`, sha256: sha256(artifactUtf8) }].map(file => ({ path: file.path, sha256: file.sha256, authority: file.path.startsWith('runtime/') ? 'vendor' : 'release', status: 'Valid', publisher: file.path.startsWith('runtime/') ? 'SYNTHETIC VENDOR - NOT A CERTIFICATE' : publisher, certificateThumbprint: file.path.startsWith('runtime/') ? 'B'.repeat(40) : certificateThumbprint,
        certificateNotBeforeUtc: '2026-01-01T00:00:00Z', certificateNotAfterUtc: '2027-01-01T00:00:00Z', publiclyTrusted: true, chainTrusted: true, digestAlgorithm: 'SHA256', timestamp: { atUtc: file.path.startsWith('runtime/') ? '2026-09-01T10:00:00Z' : '2026-10-04T10:10:00Z', protocol: 'RFC3161', status: 'Valid', chainTrusted: true } })) },
    scan: { scanner: 'Microsoft Defender', engineVersion: 'SYNTHETIC-ENGINE', platformVersion: 'SYNTHETIC-PLATFORM', signatureVersion: 'SYNTHETIC-DEFINITIONS', signatureUpdatedAtUtc: '2026-10-04T00:00:00Z', artifactSha256: sha256(artifactUtf8), payloadInventorySha256: sha256(canonical(files)),
      targets: ['installer', 'payload'].map(kind => ({ kind, startedAtUtc: '2026-10-04T10:30:00Z', completedAtUtc: '2026-10-04T10:35:00Z', complete: true, exitCode: 0, detections: 0, remediations: 0, remediationDisabled: true, detailReport: raw(`scan-${kind}`) })) },
    physical: ['windows10', 'windows11'].map(name => ({ observedAtUtc: '2026-10-04T12:00:00Z', verifier: 'SYNTHETIC-OBSERVER-NOT-A-PERSON', hardware: { physical: true, cpu: 'SYNTHETIC-CPU', cpuFeatures: structuredClone(schema.$defs.physical.properties.hardware.properties.cpuFeatures.const), ramGiB: 8, microphone: 'SYNTHETIC-MICROPHONE' }, os: os(name), sourceCommit, appVersion: version, artifactSha256: sha256(artifactUtf8), artifactByteLength: Buffer.byteLength(artifactUtf8), model: structuredClone(model),
      checks: Object.fromEntries(Object.keys(schema.$defs.physical.properties.checks.properties).map(name => [name, { outcome: 'observed-pass', observation: `SYNTHETIC ONLY: ${name}; no physical test executed.` }])),
      cycles: Array.from({ length: 10 }, (_, index) => ({ number: index + 1, recordings: 1, clipboardCommits: 1, insertions: 1, returnedIdle: true, observation: `SYNTHETIC ONLY: cycle ${index + 1}; no dictation executed.` })),
      corpus: ['pt', 'en', 'es'].map(language => ({ language, utterances: 5, wordErrorRate: 0.1, anglicismRetention: language === 'en' ? 'not-applicable' : 1, networkDisconnected: true, silenceProducedNoText: true, report: raw(`corpus-${name}-${language}`) })) })),
    hosting: stage === 'hosted-ready' ? { url: `https://github.com/luisroquette-labs/resenha/releases/download/windows-v${version}/Resenha-${version}-windows-x64-setup.exe`, releaseTag: `windows-v${version}`, releaseId: '1', assetId: '2', immutableRelease: true, downloadedAtUtc: '2026-10-04T13:00:00Z', downloadedByteLength: Buffer.byteLength(artifactUtf8), downloadedSha256: sha256(artifactUtf8), browser: 'SYNTHETIC-BROWSER', os: os('windows11'), physical: true, markOfTheWebZoneId: 3, smartScreen: 'reputation-warning', publisherDisplay: publisher, reputationDisclosure: 'SYNTHETIC warning disclosure; no actual browser download.', detailReport: raw('hosting') } : null,
    verification: { tool: 'Scripts/windows/verify-release.ps1', toolSha256, verifiedAtUtc: '2026-10-04T14:00:00Z', sourceCommit, artifactSha256: sha256(artifactUtf8), payloadInventorySha256: sha256(canonical(files)), stage, exitCode: 0 },
  };
  const groups = [['build', manifest.build, []], ['payload', manifest.payload, ['build']], ['signatures', manifest.signatures, ['payload']], ['scan', manifest.scan, ['signatures']], ...manifest.physical.map(run => [`physical-${run.os.name}`, run, ['scan']])];
  if (manifest.hosting) groups.push(['hosting', manifest.hosting, ['physical-windows10', 'physical-windows11']]);
  groups.push(['verification', manifest.verification, groups.map(([kind]) => kind)]);
  const refs = {};
  for (const [kind, group, dependencies] of groups) {
    const report = { schemaVersion: 1, kind, evidenceClass: 'synthetic', sourceCommit, artifactSha256: manifest.sha256, dependsOn: dependencies.map(kind => refs[kind]), observations: structuredClone(group) };
    const content = JSON.stringify(report);
    const hash = sha256(content);
    const path = `reports/${kind}-${hash}.json`;
    evidenceFiles[path] = content;
    group.report = { path, sha256: hash };
    refs[kind] = group.report;
  }
  return { warning: 'SYNTHETIC TEST FIXTURE ONLY. NOT RELEASE EVIDENCE. NEVER PROMOTE.', expected: { sourceCommit, publisher, certificateThumbprint, toolSha256, evaluationTimeUtc: '2026-10-04T15:00:00Z' }, artifactUtf8, payloadUtf8, evidenceFiles, manifest };
}

// Bounded structural checker for the exact schema keywords below; never used by the release/site verifier.
export function schemaErrors(value, rule, schema = rule, path = '$') {
  if (rule.$ref) return schemaErrors(value, schema.$defs[rule.$ref.slice(8)], schema, path);
  if (rule.oneOf) return rule.oneOf.filter(choice => !schemaErrors(value, choice, schema, path).length).length === 1 ? [] : [`${path}:oneOf`];
  const errors = [];
  if ('const' in rule && canonical(value) !== canonical(rule.const)) errors.push(`${path}:const`);
  if (rule.enum && !rule.enum.some(item => canonical(item) === canonical(value))) errors.push(`${path}:enum`);
  const isType = { object: value !== null && typeof value === 'object' && !Array.isArray(value), array: Array.isArray(value), string: typeof value === 'string', integer: Number.isSafeInteger(value), number: typeof value === 'number' && Number.isFinite(value), boolean: typeof value === 'boolean', null: value === null };
  if (rule.type && !isType[rule.type]) return [...errors, `${path}:type`];
  if (rule.properties && isType.object) {
    for (const key of rule.required) if (!(key in value)) errors.push(`${path}:missing:${key}`);
    for (const [key, child] of Object.entries(value)) {
      if (key in rule.properties) errors.push(...schemaErrors(child, rule.properties[key], schema, `${path}.${key}`));
      else if (rule.additionalProperties === false) errors.push(`${path}:unknown:${key}`);
    }
  }
  if (rule.items && isType.array) {
    if (value.length < rule.minItems || value.length > rule.maxItems) errors.push(`${path}:length`);
    if (rule.uniqueItems && new Set(value.map(canonical)).size !== value.length) errors.push(`${path}:duplicate`);
    value.forEach((item, index) => errors.push(...schemaErrors(item, rule.items, schema, `${path}[${index}]`)));
  }
  if (typeof value === 'string') {
    if (rule.pattern && !new RegExp(rule.pattern).test(value)) errors.push(`${path}:pattern`);
    if (rule.minLength !== undefined && value.length < rule.minLength) errors.push(`${path}:minLength`);
    if (rule.maxLength !== undefined && value.length > rule.maxLength) errors.push(`${path}:maxLength`);
  }
  if (typeof value === 'number') {
    if (rule.minimum !== undefined && value < rule.minimum) errors.push(`${path}:minimum`);
    if (rule.maximum !== undefined && value > rule.maximum) errors.push(`${path}:maximum`);
  }
  return errors;
}

export function mutate(bundle, fixture) {
  const copy = structuredClone(bundle);
  const parts = fixture.path.split('/');
  const key = parts.pop();
  let target = copy;
  for (const part of parts) target = target[part];
  if (fixture.remove) delete target[key];
  else target[key] = fixture.value;
  return copy;
}
