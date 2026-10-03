import { createServer } from 'node:http';
import { realpath, readFile, stat } from 'node:fs/promises';
import { resolve, relative, isAbsolute, extname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const defaultRoot = fileURLToPath(new URL('../site/', import.meta.url));
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.ico': 'image/x-icon',
  '.mp4': 'video/mp4' };
const inside = (root, candidate) => {
  const path = relative(root, candidate);
  return path !== '..' && !path.startsWith('../') && !isAbsolute(path);
};

export async function createPreviewServer({ root = defaultRoot, prefix = '/', port = 0 } = {}) {
  if (!/^\/(?:[A-Za-z0-9_-]+\/)*$/u.test(prefix)) throw new Error('Prefix must be / or a slash-terminated path such as /resenha/.');
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new Error('Invalid port.');
  const siteRoot = await realpath(root);
  if (!(await stat(siteRoot)).isDirectory()) throw new Error('Site root is not a directory.');
  const server = createServer(async (req, res) => {
    const reply = (status, message, headers = {}) => {
      res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8', 'X-Content-Type-Options': 'nosniff', ...headers });
      res.end(req.method === 'HEAD' ? undefined : message);
    };
    if (req.method !== 'GET' && req.method !== 'HEAD') return reply(405, 'Method not allowed', { Allow: 'GET, HEAD' });
    let pathname;
    try { pathname = decodeURIComponent((req.url ?? '').split('?')[0]); }
    catch { return reply(400, 'Malformed URL'); }
    if (!pathname.startsWith('/') || /[\u0000-\u001f\u007f\\]/u.test(pathname)
      || pathname.split('/').some(part => part === '..' || part === '.')) return reply(400, 'Invalid path');
    if (!pathname.startsWith(prefix)) return reply(404, 'Not found');
    const requested = pathname.slice(prefix.length);
    const local = requested ? (requested.endsWith('/') ? `${requested}index.html` : requested) : 'index.html';
    const candidate = resolve(siteRoot, local);
    if (!inside(siteRoot, candidate)) return reply(403, 'Forbidden');
    try {
      const actual = await realpath(candidate);
      if (!inside(siteRoot, actual)) return reply(403, 'Forbidden');
      if (!(await stat(actual)).isFile()) return reply(404, 'Not found');
      const body = await readFile(actual);
      res.writeHead(200, { 'Content-Type': types[extname(actual)] ?? 'application/octet-stream',
        'Content-Length': body.length, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      res.end(req.method === 'HEAD' ? undefined : body);
    } catch (error) {
      reply(error.code === 'ENOENT' || error.code === 'ENOTDIR' ? 404 : 500, 'File unavailable');
    }
  });
  await new Promise((accept, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => { server.removeListener('error', reject); accept(); });
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  return { server, origin, url: origin + prefix, prefix,
    close: () => new Promise((accept, reject) => server.close(error => error ? reject(error) : accept())) };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const args = process.argv.slice(2);
  if (!args.includes('--serve')) throw new Error('Use --serve [--port 4173] [--prefix /resenha/]');
  const value = (flag, fallback) => args.includes(flag) ? args[args.indexOf(flag) + 1] : fallback;
  const preview = await createPreviewServer({ port: Number(value('--port', '4173')), prefix: value('--prefix', '/') });
  console.log(`Resenha preview: ${preview.url}`);
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, async () => { await preview.close(); });
}
