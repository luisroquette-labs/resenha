import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = dirname(fileURLToPath(import.meta.url));
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const json = (path) => JSON.parse(read(path));
const projects = ['Resenha.Core', 'Resenha.Platform', 'Resenha.Windows', 'Resenha.TargetBroker', 'Resenha.Core.Tests', 'Resenha.Platform.Tests'];

test('solution references exactly the six existing projects with no escaping references', () => {
  const declared = [...read('Resenha.Windows.sln').matchAll(/^Project\("[^"]+"\) = "([^"]+)", "([^"]+)"/gm)];
  assert.deepEqual(declared.map((match) => match[1]), projects);
  for (const [, , path] of declared) assert.ok(existsSync(resolve(root, path.replaceAll('\\', '/'))));
  for (const name of projects) {
    for (const [, path] of read(`${name}/${name}.csproj`).matchAll(/ProjectReference Include="([^"]+)"/g)) {
      const destination = resolve(root, name, path);
      assert.ok(destination.startsWith(`${root}/`));
      assert.ok(existsSync(destination));
    }
  }
});

test('exact SDK/runtime/test pins and conservative publish configuration are explicit', () => {
  const global = json('global.json');
  assert.deepEqual(global.sdk, { version: '10.0.401', rollForward: 'disable', allowPrerelease: false });
  assert.equal(global['msbuild-sdks']['MSTest.Sdk'], '4.4.0');
  assert.equal(global.test.runner, 'Microsoft.Testing.Platform');
  const props = read('Directory.Build.props');
  for (const name of ['TreatWarningsAsErrors', 'CodeAnalysisTreatWarningsAsErrors', 'RestorePackagesWithLockFile', 'RestoreLockedMode']) assert.ok(props.includes(`<${name}>true</${name}>`));
  for (const name of ['PublishTrimmed', 'PublishSingleFile', 'PublishAot']) assert.ok(props.includes(`<${name}>false</${name}>`));
  assert.match(props, /<RuntimeFrameworkVersion>10\.0\.12<\/RuntimeFrameworkVersion>/);
  for (const name of ['Resenha.Windows', 'Resenha.TargetBroker']) {
    const project = read(`${name}/${name}.csproj`);
    assert.match(project, /<RuntimeIdentifier>win-x64<\/RuntimeIdentifier>/);
    assert.match(project, /<SelfContained>true<\/SelfContained>/);
  }
  for (const name of ['Resenha.Core.Tests', 'Resenha.Platform.Tests']) assert.match(read(`${name}/${name}.csproj`), /Sdk="MSTest.Sdk"/);
});

test('portable Core has no UI, native, network or project/package dependencies', () => {
  const project = read('Resenha.Core/Resenha.Core.csproj');
  assert.match(project, /<TargetFramework>net10\.0<\/TargetFramework>/);
  assert.doesNotMatch(project, /PackageReference|ProjectReference|UseWPF|UseWindowsForms|RuntimeIdentifier/);
  const core = read('Resenha.Core/Contracts.cs');
  assert.doesNotMatch(core, /DllImport|LibraryImport|System\.Windows|HttpClient|WebRequest|Process\.Start/);
  const asyncMethods = [...core.matchAll(/ValueTask<[^;]+?\s(\w+Async)\(([^;]+?)\);/g)];
  assert.equal(asyncMethods.length, 14);
  for (const [, name, parameters] of asyncMethods) {
    assert.match(parameters, /^AttemptId attempt,/, name);
    assert.match(parameters, /CancellationToken cancellationToken$/, name);
  }
});

test('entry points remain inert and normal integrity', () => {
  assert.match(read('Resenha.Windows/App.xaml.cs'), /Shutdown\(0\)/);
  assert.doesNotMatch(read('Resenha.Windows/App.xaml'), /StartupUri=/);
  assert.match(read('Resenha.TargetBroker/Program.cs'), /Main\(\) => 0/);
  assert.match(read('Resenha.Windows/app.manifest'), /level="asInvoker" uiAccess="false"/);
});

test('unobserved native toolchain and unrun checks remain blocked', () => {
  const lock = json('toolchain-lock.json');
  assert.equal(lock.status, 'blocked-awaiting-authorized-windows-host');
  assert.equal(lock.approvedHostInventory, null);
  for (const name of ['lockedRestore', 'compile', 'coreTests', 'platformTests']) assert.equal(lock.validation[name], 'not-run');
  assert.equal(lock.validation.dependencyLocks, 'pending-sdk-generated-restore');
  assert.deepEqual(json('Resenha.Core/packages.lock.json').dependencies, { 'net10.0': {} });
});
