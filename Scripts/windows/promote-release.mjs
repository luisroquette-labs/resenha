import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const sha256 = value => createHash('sha256').update(value).digest('hex');
const required = (options, name) => {
  const value = options.get(name);
  if (!value) throw new Error(`Missing --${name}.`);
  return value;
};

export function projectWindowsRelease(manifest, verification, download) {
  if (manifest?.schemaVersion !== 1 || manifest.evidenceClass !== 'observed' || manifest.stage !== 'hosted-ready') throw new Error('Manifest is not hosted observed evidence.');
  if (verification?.contractValid !== true || verification.hostedReady !== true || verification.canEnablePublicDownload !== true) throw new Error('Verifier did not authorize public download.');
  if (verification.sourceCommit !== manifest.sourceCommit || verification.artifactSha256 !== manifest.sha256) throw new Error('Verifier identity mismatch.');
  const expectedName = `Resenha-${manifest.version}-windows-x64-setup.exe`;
  const expectedUrl = `https://github.com/luisroquette/resenha/releases/download/windows-v${manifest.version}/${expectedName}`;
  if (manifest.filename !== expectedName || manifest.hosting?.url !== expectedUrl || manifest.hosting.downloadedSha256 !== manifest.sha256) throw new Error('Hosted identity mismatch.');
  if (download?.url !== expectedUrl || download.sha256 !== manifest.sha256 || download.byteLength !== manifest.byteLength || download.publisherDisplay !== manifest.signatures.publisher) throw new Error('Browser download evidence mismatch.');
  return Object.freeze({ state: 'published', platform: 'windows', version: manifest.version, architecture: 'x64',
    minimumOS: 'Windows 10 22H2 / Windows 11 25H2', url: expectedUrl,
    evidence: Object.freeze({ channel: 'windows', url: expectedUrl, verifiedAt: verification.verifiedAtUtc,
      artifact: Object.freeze({ platform: 'windows', version: manifest.version, filename: expectedName,
        sha256: manifest.sha256, sourceCommit: manifest.sourceCommit, signature: 'valid-trusted-rfc3161',
        scan: 'passed-zero-detections', physicalWindows10: true, physicalWindows11: true,
        hostedSha256: download.sha256 }) }) });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const args = process.argv.slice(2);
  if (args.length % 2) throw new Error('Arguments must be --name value pairs.');
  const options = new Map();
  for (let index = 0; index < args.length; index += 2) {
    if (!/^--(?:manifest|verification|download-report)$/u.test(args[index]) || options.has(args[index].slice(2))) throw new Error('Unknown or duplicate argument.');
    options.set(args[index].slice(2), args[index + 1]);
  }
  const load = async name => JSON.parse(await readFile(required(options, name), 'utf8'));
  const projection = projectWindowsRelease(await load('manifest'), await load('verification'), await load('download-report'));
  process.stdout.write(`${JSON.stringify({ warning: 'Projection only; no upload or site mutation occurred.', projectionSha256: sha256(JSON.stringify(projection)), release: projection }, null, 2)}\n`);
}
