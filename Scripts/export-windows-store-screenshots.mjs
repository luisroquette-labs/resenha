import playwright from '../Tools/site-audit/node_modules/playwright-core/index.js';
import { mkdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const { chromium } = playwright;
const output = path.join(root, 'Windows/Store/Screenshots/pt-BR');
const markPath = path.join(root, 'AppStore/brand/mark/resenha-mark-ink-1024.png');
const mark = `data:image/png;base64,${(await readFile(markPath)).toString('base64')}`;
await mkdir(output, { recursive: true });

const slides = [
  {
    file: '01-fale-solte-continue.png',
    eyebrow: 'DITADO LOCAL PARA WINDOWS',
    title: 'Fale. Solte. Continue.',
    subtitle: 'Sua voz chega ao campo em que você já estava escrevendo.',
    body: `<div class="editor"><div class="editor-top"><span></span><span></span><span></span><b>Mensagem</b></div><div class="editor-label">MENSAGEM</div><div class="transcript">Éric, avise ao Luís que a COESA atualizou o README da Resenha e rodou o benchmark do whisper.cpp.</div><div class="caret"></div></div><div class="hud"><img src="${mark}"><div><small>RESENHA</small><strong>Ouvindo…</strong></div><div class="bars">${'<i></i>'.repeat(18)}</div></div>`,
  },
  {
    file: '02-atalho-e-idiomas.png',
    eyebrow: 'DO SEU JEITO',
    title: 'Um atalho. Três idiomas.',
    subtitle: 'Configure uma vez e dite em português, inglês ou espanhol.',
    body: `<div class="settings"><div class="window-title"><img src="${mark}"><div><b>resenha.</b><span>Ajustes</span></div></div><div class="setting-label">ATALHO GLOBAL</div><div class="field-row"><div class="field key"><kbd>Ctrl</kbd><b>+</b><kbd>Alt</kbd><b>+</b><kbd>Espaço</kbd></div><button>Gravar atalho</button></div><div class="two"><div><div class="setting-label">IDIOMA</div><div class="select">Português (Brasil)<span>⌄</span></div></div><div><div class="setting-label">MICROFONE</div><div class="select">Microfone padrão<span>⌄</span></div></div></div><div class="privacy"><b>100% local</b><span>O áudio e a transcrição ficam neste computador.</span></div></div>`,
  },
  {
    file: '03-clipboard-seguro.png',
    eyebrow: 'NÃO PERCA O QUE DISSE',
    title: 'Seu texto fica no Ctrl+V.',
    subtitle: 'Mesmo se outro aplicativo tomar o foco, a transcrição continua disponível.',
    body: `<div class="split"><div class="mini-window muted"><div class="mini-bar">Terminal</div><pre>$ rodando benchmark…\n<span>janela mudou de foco</span></pre></div><div class="arrow">→</div><div class="mini-window"><div class="mini-bar">Documento</div><div class="paste"><small>CTRL + V</small><p>O feedback do cliente foi positivo, mas precisamos revisar o onboarding e entregar o dashboard antes do deadline.</p></div></div></div><div class="clipboard"><span>✓</span><div><b>Texto preservado</b><small>Pronto para colar em qualquer aplicativo</small></div></div>`,
  },
  {
    file: '04-privacidade-local.png',
    eyebrow: 'PRIVACIDADE SEM LETRINHAS MIÚDAS',
    title: 'Seu áudio não sai do PC.',
    subtitle: 'Sem conta, sem anúncio, sem analytics e sem backend.',
    body: `<div class="local-flow"><div class="node"><span>01</span><b>Microfone</b><small>Áudio temporário</small></div><div class="connector"></div><div class="node active"><span>02</span><b>whisper.cpp</b><small>Transcrição local</small></div><div class="connector"></div><div class="node"><span>03</span><b>Seu texto</b><small>Clipboard + cursor</small></div></div><div class="lockline"><b>⌁ 100% local</b><span>O modelo é baixado uma vez, verificado e usado offline.</span></div>`,
  },
  {
    file: '05-portugues-com-anglicismos.png',
    eyebrow: 'PT-BR DE VERDADE',
    title: 'Português. Com anglicismos.',
    subtitle: 'Para reuniões, código, produto e tudo que mistura os dois mundos.',
    body: `<div class="language-card"><div class="chips"><span class="on">PT-BR</span><span>EN</span><span>ES</span></div><blockquote>“Abra um <em>pull request</em> no GitHub, rode o <em>benchmark</em> do whisper.cpp e confirme se o <em>build</em> do SwiftUI passou.”</blockquote><div class="result"><small>TRANSCRIÇÃO</small><p>Abra um pull request no GitHub, rode o benchmark do whisper.cpp e confirme se o build do SwiftUI passou.</p></div></div>`,
  },
];

const css = `
  @import url('https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Newsreader:opsz,wght@6..72,500;6..72,650&family=Manrope:wght@400;500;600;700&display=swap');
  :root{--paper:#f1eee4;--ink:#171b19;--muted:#66706b;--sage:#5b8f82;--sage2:#a9c9c0;--soft:#dfe8df;--line:#c7ccc5;--white:#faf9f4}
  *{box-sizing:border-box}html,body{margin:0;width:1920px;height:1080px;overflow:hidden;background:var(--paper);color:var(--ink)}body{font-family:Manrope,sans-serif}
  .page{position:relative;width:100%;height:100%;padding:70px 92px;overflow:hidden;background:radial-gradient(circle at 93% 5%,rgba(169,201,192,.38),transparent 28%),linear-gradient(135deg,#f5f2e9,#ece9df)}
  .page:before,.page:after{content:"";position:absolute;border:2px solid rgba(91,143,130,.13);border-radius:50%;width:520px;height:520px;right:-160px;top:-235px}.page:after{width:390px;height:390px;right:-95px;top:-170px}
  header{display:flex;align-items:center;justify-content:space-between;position:relative;z-index:2}.brand{display:flex;align-items:center;gap:18px;font-size:34px;font-weight:700}.brand img{width:58px;height:58px;object-fit:contain}.local{font-family:'DM Mono';font-size:18px;color:var(--sage);letter-spacing:.08em}
  main{position:relative;z-index:2}.eyebrow{margin-top:55px;font-family:'DM Mono';font-size:18px;letter-spacing:.12em;color:var(--sage);font-weight:500}.title{font-family:Newsreader,Georgia,serif;font-size:84px;line-height:.98;margin:18px 0 15px;letter-spacing:-.025em}.subtitle{font-size:25px;color:var(--muted);margin:0;max-width:1000px}.stage{position:relative;margin-top:45px;height:595px}
  .editor{position:absolute;left:110px;right:110px;top:15px;height:500px;background:var(--white);border:1px solid var(--line);border-radius:24px;box-shadow:0 24px 70px rgba(38,48,43,.12);padding:105px 90px}.editor-top{position:absolute;left:0;right:0;top:0;height:65px;background:#e8eae4;border-radius:24px 24px 0 0;display:flex;align-items:center;padding:0 22px;gap:10px}.editor-top span{width:12px;height:12px;border-radius:2px;background:#9aa39d}.editor-top b{margin-left:18px;font-size:14px;color:#69736d;font-weight:600}.editor-label,.setting-label{font-family:'DM Mono';font-size:15px;letter-spacing:.08em;color:var(--sage);font-weight:500}.transcript{font-family:Newsreader,Georgia,serif;font-size:43px;line-height:1.25;max-width:1300px;margin-top:35px}.caret{width:3px;height:48px;background:var(--sage);display:inline-block;margin-top:4px}.hud{position:absolute;bottom:5px;left:50%;transform:translateX(-50%);width:720px;height:122px;border:1px solid #abb9b2;border-radius:38px;background:#f8f5ec;box-shadow:0 20px 50px rgba(23,27,25,.25);display:flex;align-items:center;padding:20px 25px;gap:18px}.hud img{width:66px;height:66px}.hud div:nth-child(2){min-width:145px;display:flex;flex-direction:column}.hud small{font-family:'DM Mono';font-size:13px;color:var(--sage);letter-spacing:.08em}.hud strong{font-size:22px}.bars{display:flex;align-items:center;height:70px;gap:7px;flex:1}.bars i{display:block;width:8px;border-radius:5px;background:var(--sage);height:22px}.bars i:nth-child(3n){height:60px}.bars i:nth-child(4n){height:42px}.bars i:nth-child(5n){height:30px}
  .settings{width:1090px;margin:0 auto;background:var(--white);border:1px solid var(--line);border-radius:24px;padding:38px 48px;box-shadow:0 24px 70px rgba(38,48,43,.13)}.window-title{display:flex;align-items:center;gap:15px;margin-bottom:28px}.window-title img{width:54px;height:54px}.window-title div{display:flex;flex-direction:column}.window-title b{font-family:Newsreader;font-size:31px}.window-title span{font-size:14px;color:var(--muted)}.field-row{display:grid;grid-template-columns:1fr auto;gap:16px;margin:9px 0 25px}.field,.select{height:58px;border:1px solid var(--line);border-radius:12px;background:#f6f4ed;display:flex;align-items:center;padding:0 16px}.key{gap:10px}.key kbd{font-family:'DM Mono';font-size:15px;border:1px solid #b9c0bb;background:white;border-radius:7px;padding:8px 12px;box-shadow:0 2px 0 #b9c0bb}.settings button{border:0;border-radius:11px;background:var(--sage);color:white;font-weight:700;font-size:16px;padding:0 25px}.two{display:grid;grid-template-columns:1fr 1fr;gap:22px}.select{margin-top:9px;justify-content:space-between}.privacy{margin-top:26px;background:var(--soft);border-radius:14px;padding:21px 24px;display:flex;flex-direction:column}.privacy b{font-size:18px}.privacy span{color:var(--muted);margin-top:4px}
  .split{display:grid;grid-template-columns:1fr 80px 1fr;align-items:center;gap:18px;padding:15px 40px}.mini-window{height:340px;background:var(--white);border:1px solid var(--line);border-radius:20px;box-shadow:0 24px 60px rgba(38,48,43,.12);overflow:hidden}.mini-window.muted{opacity:.58}.mini-bar{height:52px;background:#e8eae4;padding:15px 22px;font-weight:700}.mini-window pre{padding:32px;font:18px/1.7 'DM Mono';color:#33423b}.mini-window pre span{color:#9b655b}.arrow{text-align:center;font-size:48px;color:var(--sage)}.paste{padding:32px}.paste small,.result small{font:14px 'DM Mono';letter-spacing:.08em;color:var(--sage)}.paste p{font-family:Newsreader;font-size:30px;line-height:1.3}.clipboard{width:590px;height:94px;margin:18px auto 0;border:1px solid #a8b8b0;background:#f8f5ec;border-radius:24px;display:flex;align-items:center;gap:18px;padding:18px 24px;box-shadow:0 16px 40px rgba(23,27,25,.16)}.clipboard>span{display:grid;place-items:center;width:48px;height:48px;border-radius:50%;background:var(--sage);color:white;font-size:24px}.clipboard div{display:flex;flex-direction:column}.clipboard small{color:var(--muted);margin-top:2px}
  .local-flow{display:grid;grid-template-columns:1fr 80px 1fr 80px 1fr;align-items:center;padding:45px 70px}.node{height:250px;border:1px solid var(--line);background:var(--white);border-radius:26px;padding:30px;display:flex;flex-direction:column;justify-content:flex-end;box-shadow:0 20px 50px rgba(38,48,43,.1)}.node.active{background:var(--sage);color:white;transform:translateY(-16px)}.node span{font:18px 'DM Mono';color:var(--sage);margin-bottom:auto}.node.active span,.node.active small{color:#eaf2ef}.node b{font-family:Newsreader;font-size:34px}.node small{font-size:17px;color:var(--muted);margin-top:7px}.connector{height:2px;background:var(--sage2)}.lockline{margin:15px auto 0;width:840px;text-align:center;background:#e4ebe4;border-radius:18px;padding:20px}.lockline b{color:var(--sage);margin-right:18px}.lockline span{color:var(--muted)}
  .language-card{width:1250px;margin:0 auto;background:var(--white);border:1px solid var(--line);border-radius:26px;padding:35px 50px;box-shadow:0 24px 70px rgba(38,48,43,.12)}.chips{display:flex;gap:10px}.chips span{font:15px 'DM Mono';border:1px solid var(--line);border-radius:99px;padding:9px 16px;color:var(--muted)}.chips .on{background:var(--sage);color:white;border-color:var(--sage)}blockquote{font-family:Newsreader;font-size:35px;line-height:1.25;margin:26px 0;color:#37413c}blockquote em{color:var(--sage);font-style:normal}.result{border-left:4px solid var(--sage);background:#e8eee8;padding:20px 28px;border-radius:0 15px 15px 0}.result p{font-size:21px;line-height:1.35;margin:8px 0 0}
`;

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
for (const slide of slides) {
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body><div class="page"><header><div class="brand"><img src="${mark}">resenha.</div><div class="local">WINDOWS · 100% LOCAL</div></header><main><div class="eyebrow">${slide.eyebrow}</div><h1 class="title">${slide.title}</h1><p class="subtitle">${slide.subtitle}</p><div class="stage">${slide.body}</div></main></div></body></html>`, { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(output, slide.file), type: 'png' });
}
await browser.close();
console.log(`Exported ${slides.length} Windows Store screenshots to ${output}`);
