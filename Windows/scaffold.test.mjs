import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = dirname(fileURLToPath(import.meta.url));
const read = (path) => readFileSync(resolve(root, path), 'utf8').replaceAll('\r\n', '\n');
const json = (path) => JSON.parse(read(path));
const projects = ['Resenha.Core', 'Resenha.Platform', 'Resenha.Windows', 'Resenha.TargetBroker', 'Resenha.Core.Tests', 'Resenha.Platform.Tests', 'Resenha.ReleaseVerifier'];

test('solution references exactly the seven existing projects with no escaping references', () => {
  const declared = [...read('Resenha.Windows.sln').matchAll(/^Project\("[^"]+"\) = "([^"]+)", "([^"]+)"/gm)];
  assert.deepEqual(declared.map((match) => match[1]), projects);
  for (const [, , path] of declared) assert.ok(existsSync(resolve(root, path.replaceAll('\\', '/'))));
  for (const name of projects) {
    for (const [, path] of read(`${name}/${name}.csproj`).matchAll(/ProjectReference Include="([^"]+)"/g)) {
      const destination = resolve(root, name, path);
      const repositoryRelative = relative(root, destination);
      assert.ok(repositoryRelative !== '..' && !repositoryRelative.startsWith(`..${process.platform === 'win32' ? '\\' : '/'}`) && !isAbsolute(repositoryRelative));
      assert.ok(existsSync(destination));
    }
  }
});

test('exact SDK/runtime/test pins and conservative publish configuration are explicit', () => {
  const global = json('global.json');
  assert.deepEqual(global.sdk, { version: '10.0.401', rollForward: 'disable', allowPrerelease: false });
  assert.equal(global['msbuild-sdks']['MSTest.Sdk'], '4.4.0');
  assert.equal(global.test.runner, 'Microsoft.Testing.Platform');
  const toolchain = json('toolchain-lock.json');
  const props = read('Directory.Build.props');
  for (const name of ['TreatWarningsAsErrors', 'CodeAnalysisTreatWarningsAsErrors', 'RestorePackagesWithLockFile', 'RestoreLockedMode']) assert.ok(props.includes(`<${name}>true</${name}>`));
  for (const name of ['PublishTrimmed', 'PublishSingleFile', 'PublishAot']) assert.ok(props.includes(`<${name}>false</${name}>`));
  assert.doesNotMatch(props, /<RuntimeFrameworkVersion>/,
    'a global RuntimeFrameworkVersion creates conflicting Windows SDK reference packs');
  assert.equal(toolchain.requirements.dotnetRuntime, '10.0.12');
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

test('app composition owns one instance, real adapters and bounded local IPC', () => {
  const app = read('Resenha.Windows/App.xaml.cs');
  for (const boundary of ['SingleInstanceCoordinator', 'KeyboardHook', 'WasapiRecorder', 'ModelStore',
    'TargetBrokerClient', 'ClipboardService', 'TextInjector', 'WhisperCliTranscriber', 'DictationCoordinator']) {
    assert.ok(app.includes(boundary), boundary);
  }
  assert.match(app, /PipeOptions\.Asynchronous \| PipeOptions\.CurrentUserOnly/);
  assert.match(app, /shortcut\.Edge \+= ShortcutEdge/);
  assert.match(app, /await coordinator\.DisposeAsync\(\)/);
  assert.match(app, /await shortcut\.DisposeAsync\(\)/);
  assert.doesNotMatch(read('Resenha.Windows/App.xaml'), /StartupUri=/);
  const broker = read('Resenha.TargetBroker/Program.cs');
  const client = read('Resenha.Platform/TargetBrokerClient.cs');
  assert.match(broker, /arguments\.Length != 6/);
  assert.match(broker, /NamedPipeClientStream\("\."/);
  assert.match(broker, /payload\.Length > 64 \* 1024/);
  assert.match(client, /PipeOptions\.Asynchronous \| PipeOptions\.CurrentUserOnly/);
  assert.doesNotMatch(`${broker}\n${client}`, /TcpListener|HttpListener|Socket\(/);
  assert.match(read('Resenha.Windows/app.manifest'), /level="asInvoker" uiAccess="false"/);
});

test('cross-target evidence is recorded without claiming native Windows validation', () => {
  const lock = json('toolchain-lock.json');
  assert.equal(lock.status, 'blocked-awaiting-authorized-windows-host');
  assert.equal(lock.approvedHostInventory, null);
  assert.match(lock.validation.lockedRestore, /^passed-on-macos-cross-target-/);
  assert.match(lock.validation.compile, /^passed-on-macos-cross-target-/);
  assert.match(lock.validation.coreTests, /^passed-145-on-macos-/);
  assert.match(lock.validation.platformTests, /^passed-43-explicit-portable-plus-34-other-nonnative-on-macos-.*native-failed-or-inconclusive-as-required-/);
  assert.match(lock.validation.dependencyLocks, /^generated-with-sdk-10\.0\.401-/);
  for (const name of projects) assert.ok(existsSync(resolve(root, `${name}/packages.lock.json`)));
  assert.deepEqual(json('Resenha.Core/packages.lock.json').dependencies, { 'net10.0': {} });
});

test('cloud Windows validation is manual, bounded, pinned and cannot claim physical acceptance', () => {
  const workflow = read('../.github/workflows/windows-release-validation.yml');
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /pull_request:\n\s+types: \[labeled\]/);
  assert.match(workflow, /github\.event\.label\.name == 'windows-release-validation'/);
  assert.doesNotMatch(workflow, /\n\s+push:|\n\s+schedule:/);
  assert.match(workflow, /permissions:\n\s+contents: read/);
  assert.match(workflow, /runs-on: windows-2022/);
  assert.match(workflow, /timeout-minutes: 35/);
  for (const sha of ['fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09', '26b0ec14cb23fa6904739307f278c14f94c95bf1',
    '249970729cb0ef3589644e2896645e5dc5ba9c38']) assert.ok(workflow.includes(sha));
  assert.match(workflow, /TestCategory=WindowsIntegration/);
  assert.match(workflow, /TestCategory=WindowsNativeAudio/);
  assert.doesNotMatch(workflow, /TestCategory=PhysicalAcceptance/);
  assert.match(workflow, /working-directory: Windows\/native/);
  assert.doesNotMatch(workflow, /cmake --preset windows-x64-cpu -S native/);
  assert.match(workflow, /cmake --build --preset windows-x64-cpu/);
  assert.match(workflow, /innosetup-6\.7\.3\.exe/);
  assert.match(workflow, /9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732/);
  assert.ok(workflow.includes('Pyrsys B\\.V\\.'));
  assert.match(workflow, /UNSIGNED-NOT-FOR-DISTRIBUTION/);
  assert.match(workflow, /Invoke-BoundedProcess/);
  assert.match(workflow, /Inno smoke compilation.*300/);
  assert.match(workflow, /Smoke uninstall left the application directory behind/);
  assert.doesNotMatch(workflow, /upload-artifact|gh release|approvedHostInventory|physical-windows/u);
});

test('installer separates ephemeral unsigned smoke from the signed release contract', () => {
  const installer = read('Installer/Resenha.iss');
  assert.match(installer, /#ifdef SmokeUnsigned/);
  assert.match(installer, /UNSIGNED-NOT-FOR-DISTRIBUTION/);
  assert.match(installer, /SignedUninstaller=no/);
  assert.match(installer, /#ifdef SmokeUnsigned\nCompression=zip\/1\nSolidCompression=no\n#else\nCompression=lzma2\/max\nSolidCompression=yes/);
  assert.match(installer, /#else\nSignedUninstaller=yes\nSignTool=resenha/);
});

test('repository text policy keeps byte-identity contracts deterministic on Windows', () => {
  const attributes = read('../.gitattributes');
  assert.match(attributes, /^\* text=auto eol=lf$/m);
  assert.doesNotMatch(read('release-manifest.schema.json'), /\r/);
});
