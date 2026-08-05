/*
 *
 * Browser-based RUM + APM load generator (multi-user, multi-browser).
 *
 * Each cycle:
 *   - opens a NEW window/context (= a new RUM session, good for Session Replay),
 *   - uses a DIFFERENT browser engine (Chrome / Edge / Firefox) combined with a
 *     different OS + device type,
 *   - LOGS IN as the next demo user, then reuses that same session to browse
 *     every page and check out,
 *   - closes the session; the next cycle rotates to a different user + combo.
 *
 * The signed-in username is rendered on every page at  //*[@id="rumUser"]  so
 * eG RUM can tag the session with it.
 *
 * ignoreHTTPSErrors:true lets egrum.js load from the self-signed collector.
 *
 * Env vars:
 *   BASE_URL     default http://localhost:8080   (start the tunnel first)
 *   CONCURRENCY  default 2      parallel virtual users
 *   ITERATIONS   default 0      cycles PER worker (0 = run forever)
 *   HEADED       default 0      set 1 to watch the windows (best for Session Replay demo)
 *   CHECKOUT_PCT default 80     % of sessions that complete a purchase
 */
const { chromium, firefox } = require('playwright');

const BASE = process.env.BASE_URL || 'http://localhost:8080';
const CONCURRENCY = parseInt(process.env.CONCURRENCY || '2', 10);
const ITERATIONS = parseInt(process.env.ITERATIONS || '0', 10);
const HEADED = process.env.HEADED === '1';
const CHECKOUT_PCT = parseInt(process.env.CHECKOUT_PCT || '80', 10);

const USERS = [
  'alice.chen@shopfast.io',
  'marcus.lee@shopfast.io',
  'priya.sharma@shopfast.io',
  'wei.zhang@shopfast.io',
  'john.tan@shopfast.io',
  'sara.ng@shopfast.io'
];

// Browser + OS + device combinations. engine maps to a launched browser below.
const PERSONAS = [
  { label: 'Chrome · Windows · Desktop',  engine: 'chrome',  isMobile: false,
    ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36',
    viewport: { width: 1366, height: 768 } },
  { label: 'Edge · Windows · Desktop',    engine: 'edge',    isMobile: false,
    ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36 Edg/150.0.0.0',
    viewport: { width: 1536, height: 864 } },
  { label: 'Firefox · Windows · Desktop', engine: 'firefox', isMobile: false,
    ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0',
    viewport: { width: 1440, height: 900 } },
  { label: 'Chrome · Android · Mobile',   engine: 'chrome',  isMobile: true,
    ua: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Mobile Safari/537.36',
    viewport: { width: 412, height: 915 } },
  { label: 'Chrome · macOS · Desktop',    engine: 'chrome',  isMobile: false,
    ua: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36',
    viewport: { width: 1512, height: 900 } },
  { label: 'Firefox · Linux · Desktop',   engine: 'firefox', isMobile: false,
    ua: 'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0',
    viewport: { width: 1600, height: 900 } }
];

const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PRODUCTS = ['h1', 'c1', 's1', 'k1', 'm1', 'b1'];

let seq = 0;
function nextCombo() {
  const i = seq++;
  return { user: USERS[i % USERS.length], persona: PERSONAS[i % PERSONAS.length], n: i + 1 };
}

async function launchBrowsers() {
  const b = {};
  try { b.chrome = await chromium.launch({ headless: !HEADED, channel: 'chrome' }); }
  catch (e) { b.chrome = await chromium.launch({ headless: !HEADED }); console.log('(chrome channel not found; using bundled Chromium)'); }
  try { b.edge = await chromium.launch({ headless: !HEADED, channel: 'msedge' }); }
  catch (e) { b.edge = b.chrome; console.log('(msedge channel not found; using Chromium for Edge)'); }
  try { b.firefox = await firefox.launch({ headless: !HEADED }); }
  catch (e) { b.firefox = b.chrome; console.log('(Firefox not installed; using Chromium instead)'); }
  return b;
}

async function cycle(browsers, combo) {
  const { user, persona, n } = combo;
  const browser = browsers[persona.engine] || browsers.chrome;

  const opts = { ignoreHTTPSErrors: true, userAgent: persona.ua, viewport: persona.viewport };
  if (persona.engine !== 'firefox') {          // isMobile/touch unsupported in Firefox
    opts.isMobile = persona.isMobile;
    opts.hasTouch = persona.isMobile;
    opts.deviceScaleFactor = persona.isMobile ? 3 : 1;
  }

  const context = await browser.newContext(opts);
  const page = await context.newPage();
  const tag = `#${n} ${user} [${persona.label}]`;
  try {
    // Log in — this page view + the form are captured in the RUM session
    await page.goto(BASE + '/login', { waitUntil: 'load', timeout: 40000 });
    await page.fill('#username', user);
    await page.fill('#password', 'demo');
    await page.click('#loginBtn', { timeout: 20000 });
    await page.waitForURL('**/index', { timeout: 40000 }).catch(() => {});

    // Home — wait out the ~10s catalog so the slow LCP is captured
    await sleep(rnd(11000, 13000));

    // Product — sit through the ~5s and ~10s layout shifts (CLS)
    await page.goto(BASE + '/product?id=' + pick(PRODUCTS), { waitUntil: 'load', timeout: 40000 });
    await sleep(rnd(11000, 13000));

    // Cart — slow quantity interactions (each blocks ~10s) for INP
    await page.goto(BASE + '/cart', { waitUntil: 'load', timeout: 40000 });
    for (let i = 0; i < 2; i++) {
      await page.click('.qty button:last-child', { timeout: 20000 }).catch(() => {});
      await sleep(rnd(1500, 3000));
    }
    await sleep(rnd(1200, 2200));

    if (Math.random() * 100 > CHECKOUT_PCT) {
      console.log(`${tag}: browsed (no checkout)`);
      return;
    }

    // Checkout — click Pay during the ~10s SDK freeze (FID), then wait out the Ajax
    await page.goto(BASE + '/checkout', { waitUntil: 'load', timeout: 40000 });
    await sleep(rnd(1500, 2500));
    await page.click('#payBtn', { timeout: 20000 }).catch(() => {});
    await page.waitForURL('**/confirmation**', { timeout: 40000 }).catch(() => {});
    await sleep(rnd(1500, 2500));
    console.log(`${tag}: completed checkout`);
  } catch (e) {
    console.log(`${tag}: error ${e.message}`);
  } finally {
    await context.close();   // ends this RUM session
  }
}

async function worker(browsers, wid) {
  let i = 0;
  while (ITERATIONS === 0 || i < ITERATIONS) {
    i++;
    await cycle(browsers, nextCombo());
    await sleep(rnd(500, 1500));
  }
}

(async () => {
  const browsers = await launchBrowsers();
  console.log(
    `RUM load generator -> base=${BASE} concurrency=${CONCURRENCY} ` +
    `iterations=${ITERATIONS || 'infinite'} checkout=${CHECKOUT_PCT}%`
  );
  console.log(`${USERS.length} users x ${PERSONAS.length} browser/OS/device combos. Ctrl+C to stop.`);
  const workers = [];
  for (let w = 1; w <= CONCURRENCY; w++) workers.push(worker(browsers, w));
  await Promise.all(workers);
  for (const k of Object.keys(browsers)) { try { await browsers[k].close(); } catch (e) {} }
})();
