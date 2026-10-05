// Promo overlay renderer — macOS / Windows / Linux (incl. Claude Cowork).
// Renders ANY overlay.html that follows references/contract.md into a transparent HEVC .mov for phones.
//
//   node render.js <job-folder> [--preview-only] [--prores]
//   node render.js --setup            (download FFmpeg + headless Chrome only)
//
// Same output on every OS: <name>-1080x1920-<dur>s-alpha-mobile.mov  (HEVC Main + alpha layer, 'hvc1', .mov)
//   macOS          → Apple VideoToolbox HEVC-alpha encoder
//   Windows/Linux  → x265 alpha-layer encoder (FFmpeg build with x265 ENABLE_ALPHA)
// Both decode with transparency on iPhone (verified with Apple's decoder).
const fs = require('fs'), path = require('path'), http = require('http'), https = require('https'), os = require('os');
const { spawn, spawnSync, execFileSync } = require('child_process');

const SKILL = path.resolve(__dirname, '..');
// downloads go next to the skill if it is writable, else to ~/.cache/promo-overlay (e.g. read-only skill mount in Cowork)
const WRITABLE = (() => { try { fs.accessSync(SKILL, fs.constants.W_OK); return SKILL; } catch { return path.join(os.homedir(), '.cache', 'promo-overlay'); } })();
const BIN = path.join(WRITABLE, 'bin');                    // downloaded FFmpeg lives here
const CACHE = path.join(WRITABLE, '.cache');               // downloaded headless Chrome lives here
const IS_WIN = process.platform === 'win32', IS_MAC = process.platform === 'darwin';
const log = m => console.log(m);

/* ======================================================================= setup: FFmpeg */
const FFMPEG_URLS = {
  'darwin-arm64': 'https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip',
  'darwin-x64':   'https://ffmpeg.martin-riedl.de/redirect/latest/macos/amd64/release/ffmpeg.zip',
  'win32-x64':    'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip',
  'linux-x64':    'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz',
  'linux-arm64':  'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz',
};
const exe = n => IS_WIN ? n + '.exe' : n;
function capabilities(ff) {
  try {
    const enc = execFileSync(ff, ['-hide_banner', '-encoders'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    const x265alpha = /libx265/.test(enc) && /yuva420p/.test(execFileSync(ff, ['-hide_banner', '-h', 'encoder=libx265'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }));
    const vtAlpha = IS_MAC && /hevc_videotoolbox/.test(enc);
    return { ok: true, x265alpha, vtAlpha, prores: /prores_ks/.test(enc) };
  } catch { return { ok: false }; }
}
function download(url, dest) {
  return new Promise((res, rej) => {
    const get = (u, n = 0) => https.get(u, { headers: { 'User-Agent': 'promo-overlay' } }, r => {
      if (r.statusCode >= 300 && r.statusCode < 400 && r.headers.location && n < 10) { r.resume(); return get(new URL(r.headers.location, u).href, n + 1); }
      if (r.statusCode !== 200) { r.resume(); return rej(new Error(`HTTP ${r.statusCode} for ${u}`)); }
      const total = +r.headers['content-length'] || 0; let got = 0, last = 0; const f = fs.createWriteStream(dest);
      r.on('data', c => { got += c.length; if (total && Date.now() - last > 2000) { last = Date.now(); process.stdout.write(`\r  downloading FFmpeg ${(100 * got / total).toFixed(0)}%   `); } });
      r.pipe(f); f.on('finish', () => f.close(() => { process.stdout.write('\n'); res(); })); f.on('error', rej);
    }).on('error', rej);
    get(url);
  });
}
function findFile(dir, name) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { const r = findFile(p, name); if (r) return r; } else if (e.name === name) return p;
  }
  return null;
}
async function ensureFfmpeg() {
  const cands = [process.env.PROMO_FFMPEG, path.join(BIN, exe('ffmpeg')), 'ffmpeg'].filter(Boolean);
  for (const c of cands) { const cap = capabilities(c); if (cap.ok && (cap.x265alpha || cap.vtAlpha)) return { ff: c, ...cap }; }
  const key = `${process.platform}-${process.arch}`, url = FFMPEG_URLS[key];
  if (!url) throw new Error(`No FFmpeg build known for ${key}. Install an FFmpeg whose libx265 supports yuva420p and set PROMO_FFMPEG.`);
  log(`Setting up FFmpeg for ${key} (one time) …`);
  fs.mkdirSync(BIN, { recursive: true });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'promo-ff-')), arc = path.join(tmp, path.basename(new URL(url).pathname) || 'ffmpeg.zip');
  await download(url, arc);
  const x = spawnSync('tar', ['-xf', arc, '-C', tmp], { stdio: 'inherit' });   // bsdtar (macOS/Windows 10+) reads zip; GNU tar reads tar.xz
  if (x.status !== 0 && /\.zip$/.test(arc)) spawnSync(IS_WIN ? 'powershell' : 'unzip', IS_WIN ? ['-NoProfile', '-Command', `Expand-Archive -Force '${arc}' '${tmp}'`] : ['-q', '-o', arc, '-d', tmp], { stdio: 'inherit' });
  const found = findFile(tmp, exe('ffmpeg'));
  if (!found) throw new Error('ffmpeg binary not found in ' + url);
  const dst = path.join(BIN, exe('ffmpeg')); fs.copyFileSync(found, dst); if (!IS_WIN) fs.chmodSync(dst, 0o755);
  if (IS_MAC) spawnSync('xattr', ['-d', 'com.apple.quarantine', dst], { stdio: 'ignore' });
  fs.rmSync(tmp, { recursive: true, force: true });
  const cap = capabilities(dst);
  if (!cap.ok || !(cap.x265alpha || cap.vtAlpha)) throw new Error('Downloaded FFmpeg cannot encode HEVC with alpha on this OS.');
  log('FFmpeg ready: ' + dst);
  return { ff: dst, ...cap };
}

/* ======================================================================= setup: headless Chrome */
function systemChrome() {
  const L = process.env.LOCALAPPDATA || '', PF = process.env.PROGRAMFILES || 'C:\\Program Files', PF86 = process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)';
  const paths = IS_MAC ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge']
    : IS_WIN ? [`${PF}\\Google\\Chrome\\Application\\chrome.exe`, `${PF86}\\Google\\Chrome\\Application\\chrome.exe`, `${L}\\Google\\Chrome\\Application\\chrome.exe`, `${PF86}\\Microsoft\\Edge\\Application\\msedge.exe`, `${PF}\\Microsoft\\Edge\\Application\\msedge.exe`]
    : ['/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/snap/bin/chromium'];
  return [process.env.PROMO_CHROME, ...paths].filter(Boolean).find(p => fs.existsSync(p));
}
async function ensureChrome() {
  const sys = process.env.PROMO_BUNDLED_CHROME ? null : systemChrome(); if (sys) return sys;   // PROMO_BUNDLED_CHROME=1 forces a downloaded one
  // 1) Chrome for Testing headless shell (macOS, Windows, Linux x64)
  if (!process.env.PROMO_PLAYWRIGHT) try {
    const B = require('@puppeteer/browsers');
    const platform = B.detectBrowserPlatform();
    if (platform && platform !== 'linux_arm') {                // CfT has no Linux-arm64 build (Cowork on Apple Silicon)
      const installed = (await B.getInstalledBrowsers({ cacheDir: CACHE })).find(b => b.browser === B.Browser.CHROMEHEADLESSSHELL);
      if (installed) return installed.executablePath;
      const buildId = await B.resolveBuildId(B.Browser.CHROMEHEADLESSSHELL, platform, 'stable');
      log(`Setting up headless Chrome ${buildId} (one time) …`);
      return (await B.install({ browser: B.Browser.CHROMEHEADLESSSHELL, buildId, cacheDir: CACHE, platform })).executablePath;
    }
  } catch (e) { log('headless Chrome download failed (' + e.message + ') — trying Playwright Chromium'); }
  // 2) Playwright Chromium (also ships Linux arm64)
  const env = { ...process.env, PLAYWRIGHT_BROWSERS_PATH: path.join(CACHE, 'ms-playwright') };
  process.env.PLAYWRIGHT_BROWSERS_PATH = env.PLAYWRIGHT_BROWSERS_PATH;
  const pw = require('playwright-core');
  let p = pw.chromium.executablePath();
  if (!fs.existsSync(p)) {
    log('Setting up Playwright Chromium (one time) …');
    const cli = path.join(path.dirname(require.resolve('playwright-core/package.json')), 'cli.js');
    const r = spawnSync(process.execPath, [cli, 'install', 'chromium'], { stdio: 'inherit', env });
    if (r.status !== 0) throw new Error('Could not download a browser. On Linux you may need: npx playwright-core install-deps chromium (needs sudo/apt)');
    p = pw.chromium.executablePath();
  }
  return p;
}

/* ======================================================================= main */
const args = process.argv.slice(2);
if (args.includes('--setup')) {
  (async () => { const f = await ensureFfmpeg(); const c = await ensureChrome();
    log(`OK\n  ffmpeg: ${f.ff} (${f.vtAlpha ? 'VideoToolbox HEVC-alpha' : 'x265 alpha'})\n  chrome: ${c}`); })()
    .catch(e => { console.error('SETUP FAILED: ' + e.message); process.exit(1); });
} else main().catch(e => { console.error(e.stack || e); process.exit(1); });

async function main() {
  const puppeteer = require('puppeteer-core');
  const { PNG } = require('pngjs');
  const SRC = path.resolve(args.find(a => !a.startsWith('--')) || '');
  const PREVIEW_ONLY = args.includes('--preview-only'), PRORES = args.includes('--prores');
  if (!fs.existsSync(SRC) || !fs.statSync(SRC).isDirectory()) { console.error('usage: node render.js <job-folder> [--preview-only] [--prores]'); process.exit(1); }

  const readJSON = f => fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : null;
  const classic = !fs.existsSync(path.join(SRC, 'overlay.html')) && fs.existsSync(path.join(SRC, 'config.json'));
  const cfg = classic ? readJSON(path.join(SRC, 'config.json')) : null;
  const job = { ...(cfg || {}), ...(readJSON(path.join(SRC, 'job.json')) || {}) };
  const DUR = job.duration || 15, FPS = job.fps || 30, NAME = (job.name || 'promo-overlay').replace(/[^\w\-ก-๙]+/g, '-');
  const OUT = path.resolve(SRC, job.outDir || '.'); fs.mkdirSync(OUT, { recursive: true });
  const ck = job.checks || {};
  const CLEAR = ck.clearZone || { x: 100, y: 820, w: 880, h: 330 };
  const REVEAL = ck.reveal || (classic ? { x: 540, y: 1780, at: job.cardIn ?? 3 } : null);
  // frame budget: top section ≤ top 2/7 (y < TOP_LIMIT), bottom section ≤ lowest 1/4 (y >= LIMIT); nothing visible in between.
  // content in [TOP_LIMIT, MID) counts as "top too tall", in [MID, LIMIT) as "bottom too tall".
  const LIMIT = ck.bottomLimit ?? 1440, TOP_LIMIT = ck.topLimit ?? 548, MID = ck.bandSplit ?? 1000, VIS = 32;
  const zones = im => { if (job.sheet) return { top: null, bot: null };
    const a = (x, y) => im.data[(y * im.width + x) * 4 + 3], row = y => { for (let x = 0; x < im.width; x += 4) if (a(x, y) >= VIS) return true; return false; };
    let top = null, bot = null;
    for (let y = MID - 1; y >= TOP_LIMIT; y -= 2) if (row(y)) { top = y; break; }
    for (let y = MID; y < LIMIT; y += 2) if (row(y)) { bot = y; break; }
    return { top, bot }; };
  const worse = (cur, z, t) => { if (z.top !== null && (!cur.top || z.top > cur.top.y)) cur.top = { y: z.top, t };
    if (z.bot !== null && (!cur.bot || z.bot < cur.bot.y)) cur.bot = { y: z.bot, t }; };
  const topMsg = r => `top section too tall: content at y=${r.y} (t=${r.t.toFixed(1)}s), limit y<${TOP_LIMIT} (top 2/7)`;
  const botMsg = r => `bottom section too tall: content at y=${r.y} (t=${r.t.toFixed(1)}s), limit y>=${LIMIT} (lowest 1/4)`;

  const FF = PREVIEW_ONLY ? null : await ensureFfmpeg();
  const CHROME = await ensureChrome();

  // ---- temp copy of the job: design + gsap + bundled fonts + job.js (+ config.js in classic mode) ----
  const JOB = fs.mkdtempSync(path.join(os.tmpdir(), 'promo-overlay-'));
  fs.cpSync(SRC, JOB, { recursive: true, filter: s => !/\.(mov|mp4)$/i.test(s) });
  if (classic) fs.copyFileSync(path.join(SKILL, 'templates/card-bottom/overlay.html'), path.join(JOB, 'overlay.html'));
  fs.copyFileSync(require.resolve('gsap/dist/gsap.min.js'), path.join(JOB, 'gsap.min.js'));
  fs.mkdirSync(path.join(JOB, 'fonts'), { recursive: true });
  for (const f of fs.readdirSync(path.join(SKILL, 'fonts'))) if (!fs.existsSync(path.join(JOB, 'fonts', f))) fs.copyFileSync(path.join(SKILL, 'fonts', f), path.join(JOB, 'fonts', f));
  const bring = (p, tag) => { if (!p) return p; const s = path.resolve(SRC, p);
    if (!fs.existsSync(s)) { console.error('file not found: ' + s); process.exit(1); }
    if (s.startsWith(SRC + path.sep)) return path.relative(SRC, s).split(path.sep).join('/');
    const d = `${tag}${path.extname(s).toLowerCase()}`; fs.copyFileSync(s, path.join(JOB, d)); return d; };
  const pageJob = { ...job, previewBackground: bring(job.previewBackground, 'img-preview') };
  fs.writeFileSync(path.join(JOB, 'job.js'), 'window.JOB = ' + JSON.stringify(pageJob, null, 2) + ';');
  if (classic) {
    const c = { ...cfg, image: bring(cfg.image, 'img-main'), previewBackground: pageJob.previewBackground,
      logo: cfg.logo && cfg.logo.image ? { ...cfg.logo, image: bring(cfg.logo.image, 'img-logo') } : null };
    fs.writeFileSync(path.join(JOB, 'config.js'), 'window.CONFIG = ' + JSON.stringify(c, null, 2) + ';');
  }

  const TYPES = { '.html':'text/html; charset=utf-8', '.js':'text/javascript', '.css':'text/css', '.jpg':'image/jpeg', '.jpeg':'image/jpeg', '.png':'image/png', '.webp':'image/webp', '.svg':'image/svg+xml', '.otf':'font/otf', '.ttf':'font/ttf', '.woff2':'font/woff2', '.woff':'font/woff' };
  const srv = await new Promise(res => { const s = http.createServer((q, r) => {
    const f = path.join(JOB, decodeURIComponent(q.url.split('?')[0]));
    if (!f.startsWith(JOB)) { r.writeHead(403); return r.end(); }
    fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': TYPES[path.extname(f).toLowerCase()] || 'application/octet-stream' }); r.end(d); });
  }).listen(0, '127.0.0.1', () => res(s)); });
  const port = srv.address().port;

  const chromeArgs = ['--hide-scrollbars', '--force-color-profile=srgb', '--disable-dev-shm-usage'];
  if (!IS_WIN && !IS_MAC) chromeArgs.push('--no-sandbox', '--disable-gpu');          // containers / Cowork VM
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, protocolTimeout: 300000, args: chromeArgs });
  process.on('exit', () => { try { browser.process()?.kill('SIGKILL'); } catch {} });   // never leave Chrome running after a failure
  const pageErrors = [];
  async function open(mode) {
    const page = await browser.newPage();
    page.on('pageerror', e => pageErrors.push(e.message));
    page.on('requestfailed', r => { if (!/favicon/.test(r.url())) pageErrors.push('failed to load ' + r.url()); });
    page.on('response', r => { if (r.status() >= 400 && !/favicon/.test(r.url())) pageErrors.push(`HTTP ${r.status()} ${r.url()}`); });
    await page.setViewport({ width: 1080, height: 1920 });
    await page.goto(`http://127.0.0.1:${port}/overlay.html?render=${mode}`, { waitUntil: 'networkidle0', timeout: 90000 });
    await page.waitForFunction('window.RENDER && window.RENDER.ready', { timeout: 60000 })
      .catch(() => { console.error('overlay.html never set window.RENDER.ready — see references/contract.md\n' + pageErrors.join('\n')); process.exit(1); });
    await page.evaluate(() => { const st = document.getElementById('stage'); st.style.transform = 'none'; st.style.left = st.style.top = '0px'; window.fit = () => {}; });
    return page;
  }
  const seek = (page, t) => page.evaluate(t => { RENDER.seek(t); return new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); }, t);

  // ---- previews ----
  const pv = await open('preview');
  const tShow = job.previewAt ?? Math.min(DUR - 0.1, (REVEAL?.at ?? 3) + 2.2);
  await seek(pv, tShow);
  await pv.screenshot({ path: path.join(OUT, `${NAME}-preview.png`) });
  await pv.evaluate(() => { const p = document.getElementById('pv'); if (p) p.className = 'checker'; });
  await seek(pv, tShow);
  await pv.screenshot({ path: path.join(OUT, `${NAME}-preview-transparent.png`) });
  const overflow = await pv.evaluate(() => [...document.querySelectorAll('#stage *')].filter(e => {
    const cs = getComputedStyle(e); if (cs.display === 'inline' || cs.visibility === 'hidden' || e.closest('[data-overflow-ok]')) return false;
    const r = e.getBoundingClientRect(); return e.childElementCount === 0 && e.textContent.trim() && (e.scrollWidth > e.clientWidth + 2 || r.right > 1082 || r.left < -2);
  }).map(e => `"${e.textContent.trim().slice(0, 30)}"`).slice(0, 8));
  // top 2/7 + bottom 1/4 check over the whole clip (alpha only: drop backdrop + page background)
  await pv.evaluate(() => { const p = document.getElementById('pv'); if (p) p.remove(); document.documentElement.style.background = document.body.style.background = 'transparent'; });
  const pvZ = {};
  for (let t = 0; t < DUR; t += 0.5) { await seek(pv, t);
    worse(pvZ, zones(PNG.sync.read(Buffer.from(await pv.screenshot({ type: 'png', omitBackground: true })))), t); }
  log('preview: ' + path.join(OUT, `${NAME}-preview.png`));
  if (pvZ.top) log('WARN ' + topMsg(pvZ.top));
  if (pvZ.bot) log('WARN ' + botMsg(pvZ.bot));
  if (overflow.length) log('WARN text overflowing its box / the frame: ' + overflow.join(', '));
  if (pageErrors.length) log('WARN page errors:\n  ' + [...new Set(pageErrors)].join('\n  '));
  await pv.close();
  if (PREVIEW_ONLY) { await browser.close(); srv.close(); fs.rmSync(JOB, { recursive: true, force: true }); return; }

  // ---- encoders. Colours premultiplied + alpha<4 zeroed → no white fringe after CapCut export ----
  const page = await open('1');
  const base = `${NAME}-1080x1920-${DUR}s-alpha`;
  const mobile = path.join(OUT, `${base}-mobile.mov`), prores = path.join(OUT, `${base}-prores.mov`);
  const clean = "format=rgba,lut=a='if(lt(val\\,4)\\,0\\,val)',premultiply=inplace=1";
  const hevc = FF.vtAlpha && !process.env.PROMO_FORCE_X265
    ? ['-vf', clean + ',format=bgra', '-c:v', 'hevc_videotoolbox', '-alpha_quality', '0.95', '-q:v', '88']
    : ['-vf', clean + ',format=yuva420p', '-c:v', 'libx265', '-crf', '16', '-preset', 'medium', '-x265-params', 'log-level=error'];
  log(`encoder: ${hevc.includes('hevc_videotoolbox') ? 'Apple VideoToolbox HEVC+alpha' : 'x265 HEVC+alpha'}  (${FF.ff})`);
  const enc = extra => { const p = spawn(FF.ff, ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'png', '-i', '-', ...extra], { stdio: ['pipe', 'inherit', 'inherit'] });
    p.done = new Promise(r => p.on('close', c => { p.exited = true; p.code = c; r(c); }));
    p.stdin.on('error', () => {});                       // EPIPE if the encoder dies — handled below
    return p; };
  const feed = async (o, buf) => {                       // write one frame; fail fast if the encoder has died
    if (o.exited) throw new Error(`encoder exited early (code ${o.code}) — see the FFmpeg error above`);
    if (!o.stdin.write(buf)) await Promise.race([new Promise(r => o.stdin.once('drain', r)), o.done]);
    if (o.exited) throw new Error(`encoder exited early (code ${o.code}) — see the FFmpeg error above`);
  };
  const outs = [enc([...hevc, '-tag:v', 'hvc1', '-r', String(FPS), '-movflags', '+faststart', mobile])];
  if (PRORES) outs.push(enc(['-c:v', 'prores_ks', '-profile:v', '4444', '-pix_fmt', 'yuva444p10le', '-alpha_bits', '16', '-vendor', 'apl0', '-r', String(FPS), prores]));

  // ---- frame loop + source-level checks (on the exact pixels that go into the encoder) ----
  const frames = Math.round(DUR * FPS);
  const fBefore = REVEAL ? Math.floor(Math.max(0, REVEAL.at - 1) * FPS) : -1, fAfter = REVEAL ? Math.floor(Math.min(DUR - 0.1, REVEAL.at + 2.5) * FPS) : -1;
  let clearMax = 0, clearAt = 0, revBefore = -1, revAfter = -1; const Z = {};
  for (let i = 0; i < frames; i++) {
    await seek(page, i / FPS);
    const png = Buffer.from(await page.screenshot({ type: 'png', omitBackground: true }));
    for (const o of outs) await feed(o, png);
    if (i % FPS === 0 || i === fBefore || i === fAfter) {
      const im = PNG.sync.read(png), a = (x, y) => im.data[(y * im.width + x) * 4 + 3];
      for (let y = CLEAR.y; y < CLEAR.y + CLEAR.h; y += 6) for (let x = CLEAR.x; x < CLEAR.x + CLEAR.w; x += 6) { const v = a(x, y); if (v > clearMax) { clearMax = v; clearAt = i / FPS; } }
      worse(Z, zones(im), i / FPS);
      if (i === fBefore) revBefore = a(REVEAL.x, REVEAL.y);
      if (i === fAfter) revAfter = a(REVEAL.x, REVEAL.y);
    }
    if (i % FPS === 0) process.stdout.write(`\rrendering ${(100 * i / frames).toFixed(0)}%`);
  }
  outs.forEach(o => o.stdin.end());
  const codes = await Promise.all(outs.map(o => o.done));
  await browser.close(); srv.close(); fs.rmSync(JOB, { recursive: true, force: true });
  log(`\nmobile: ${mobile}` + (PRORES ? `\nprores: ${prores}` : ''));
  if (codes.some(c => c !== 0)) { console.error('FAIL encoder exited with ' + codes.join(',')); process.exit(1); }

  // ---- verification (every OS) ----
  const results = [];
  const pass = (ok, msg) => { results.push(ok); log((ok ? 'PASS ' : 'FAIL ') + msg); };
  log('--- checks (all platforms)');
  pass(clearMax <= 2, clearMax <= 2 ? 'clip area stays transparent' : `clip area not transparent (alpha ${clearMax} at ${clearAt.toFixed(1)}s)`);
  if (!job.sheet) { pass(!Z.top, Z.top ? topMsg(Z.top) : `top section within top 2/7 (y < ${TOP_LIMIT})`);
    pass(!Z.bot, Z.bot ? botMsg(Z.bot) : `bottom section within lowest 1/4 (y >= ${LIMIT})`); }
  if (REVEAL && DUR >= REVEAL.at + 1) { pass(revBefore === 0, `reveal point hidden before ${REVEAL.at}s (alpha ${revBefore})`); pass(revAfter > 200, `reveal point visible after ${REVEAL.at}s (alpha ${revAfter})`); }
  // container + bitstream: hvc1 HEVC with an alpha layer (nuh_layer_id 1) in every frame
  const probe = spawnSync(FF.ff, ['-hide_banner', '-i', mobile], { encoding: 'utf8' }).stderr || '';
  const m = probe.match(/Video: hevc[^\n]*\(hvc1[^\n]*?, (\d{2,5})x(\d{2,5})[,\s]/);
  pass(!!m && m[1] === '1080' && m[2] === '1920', `HEVC 'hvc1' 1080x1920 in .mov`);
  const annexb = spawnSync(FF.ff, ['-loglevel', 'error', '-i', mobile, '-map', '0:v', '-c', 'copy', '-bsf:v', 'hevc_mp4toannexb', '-f', 'hevc', '-'], { maxBuffer: 1 << 30 }).stdout || Buffer.alloc(0);
  let base0 = 0, alpha1 = 0;
  for (let i = 0; i + 5 < annexb.length; i++) if (annexb[i] === 0 && annexb[i + 1] === 0 && annexb[i + 2] === 1) {
    const h0 = annexb[i + 3], h1 = annexb[i + 4], type = (h0 >> 1) & 0x3f, layer = ((h0 & 1) << 5) | (h1 >> 3);
    if (type < 32 && (annexb[i + 5] & 0x80)) { if (layer === 0) base0++; else if (layer === 1) alpha1++; }   // first slice of each picture
    i += 2;
  }
  pass(base0 === frames && alpha1 === frames, `alpha layer present in every frame (${alpha1}/${base0} of ${frames})`);
  if (IS_MAC && spawnSync('swift', ['--version'], { stdio: 'ignore' }).status === 0) {
    log("--- Apple decoder (what iPhone uses)");
    const chk = spawnSync('swift', [path.join(__dirname, 'check_alpha.swift'), mobile, JSON.stringify({ clearZone: CLEAR, reveal: REVEAL })], { encoding: 'utf8' });
    const lines = (chk.stdout || '').trim().split('\n').filter(l => /^(PASS|FAIL|SKIP)/.test(l));
    lines.forEach(l => { log(l); if (l.startsWith('FAIL')) results.push(false); });
    if (!lines.length) log('SKIP Apple decoder check unavailable');
  }
  log(results.every(Boolean) ? 'ALL CHECKS PASSED' : 'SOME CHECKS FAILED — do not deliver');
  if (!results.every(Boolean)) process.exit(2);
}
