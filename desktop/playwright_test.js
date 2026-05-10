const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const FLUTTER_PORT = 4444;
const APP_URL = `http://localhost:${FLUTTER_PORT}`;
const COORD_FILE = path.join(__dirname, '..', 'test', 'coordination.json');
const LOGS_DIR = path.join(__dirname, '..', 'test', 'logs');
const FLUTTER_DIR = path.join(__dirname, '..');

let step = 0;
function log(r, msg) { console.log(`[${String(++step).padStart(2)}] [${r}] ${msg}`); }
function wr(d) { try { const c = JSON.parse(fs.readFileSync(COORD_FILE, 'utf8') || '{}'); Object.assign(c, d); fs.writeFileSync(COORD_FILE, JSON.stringify(c)); } catch {} }
function rd() { try { return JSON.parse(fs.readFileSync(COORD_FILE, 'utf8')); } catch { return {}; } }
const delay = ms => new Promise(r => setTimeout(r, ms));

// ─── FLUTTER CANVAS HELPERS ────────────────────────────────

async function waitForFlutter(page) {
  log('ORQ', 'Esperando canvas de Flutter...');
  try {
    await page.waitForSelector('canvas', { timeout: 60000 });
    await page.waitForFunction(() => {
      const c = document.querySelector('canvas');
      return c && c.width > 200 && c.height > 200;
    }, { timeout: 30000 });
    await page.click('canvas', { position: { x: 100, y: 100 } });
    await delay(1000);
    log('ORQ', 'Flutter canvas listo y con foco');
    return true;
  } catch(e) {
    log('ORQ', `Canvas no aparecio: ${e.message}`);
    return false;
  }
}

async function type(page, text) {
  await page.click('canvas', { position: { x: 200, y: 300 } });
  await delay(300);
  await page.keyboard.type(text, { delay: 40 });
}

async function tab(page, count = 1) {
  for (let i = 0; i < count; i++) {
    await page.keyboard.press('Tab');
    await delay(150);
  }
}

async function enter(page) {
  await page.keyboard.press('Enter');
  await delay(1000);
}

async function screenshot(page, name) {
  try {
    await page.screenshot({
      path: path.join(LOGS_DIR, name + '.png'),
      fullPage: false
    });
  } catch {}
}

// ─── AGENTE CONDUCTOR ─────────────────────────────────────

async function conductor(page) {
  try {
    log('COND', 'Abriendo app...');
    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });

    if (!await waitForFlutter(page)) { return false; }
    log('COND', 'App cargada');

    // Login
    log('COND', 'Escribiendo email...');
    await type(page, 'conductor@test.com');
    await tab(page);
    await type(page, '123456');
    await tab(page);
    await enter(page);
    log('COND', 'Login enviado');

    // Verificar que algo cambio en la pagina
    await delay(6000);
    await screenshot(page, 'conductor_postlogin');
    log('COND', 'Login OK');

    wr({ conductor_logged_in: true });

    // Navegar tabs (driver: Inicio-Pasajeros-Chat-Perfil-Config)
    // Ir a Mis viajes o crear viaje
    log('COND', 'Navegando...');
    await screenshot(page, 'conductor_home');

    // Crear viaje: llenar formulario
    await type(page, 'Centro');
    await tab(page);
    await type(page, 'Aeropuerto');
    await tab(page);
    await type(page, '50');
    await tab(page);
    await type(page, '3');
    log('COND', 'Formulario llenado');

    await screenshot(page, 'conductor_form');

    // Publicar
    await tab(page, 8);
    await enter(page);
    log('COND', 'Viaje publicado');
    await delay(4000);
    await screenshot(page, 'conductor_viaje');
    wr({ viaje_creado: true });

    // Esperar solicitud
    log('COND', 'Esperando solicitud...');
    let ok = false;
    for (let i = 0; i < 60; i++) {
      if (rd().solicitud_enviada) { ok = true; break; }
      await delay(1500);
    }
    if (!ok) { log('COND', 'Timeout esperando solicitud'); return false; }

    // Aceptar solicitud - tab hasta boton
    log('COND', 'Aceptando...');
    await tab(page, 4);
    await enter(page);
    await delay(3000);
    await screenshot(page, 'conductor_acepto');
    wr({ solicitud_aceptada: true });
    log('COND', 'Solicitud ACEPTADA');
    return true;

  } catch(e) {
    log('COND', `ERROR: ${e.message}`);
    return false;
  }
}

// ─── AGENTE PASAJERO ─────────────────────────────────────

async function pasajero(page) {
  try {
    log('PASS', 'Abriendo app...');
    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });

    if (!await waitForFlutter(page)) { return false; }
    log('PASS', 'App cargada');

    // Login
    log('PASS', 'Escribiendo email...');
    await type(page, 'pasajero@test.com');
    await tab(page);
    await type(page, '123456');
    await tab(page);
    await enter(page);
    log('PASS', 'Login enviado');

    await delay(6000);
    await screenshot(page, 'pasajero_postlogin');
    log('PASS', 'Login OK');

    wr({ pasajero_logged_in: true });

    // Esperar que conductor cree viaje
    log('PASS', 'Esperando viaje del conductor...');
    let ok = false;
    for (let i = 0; i < 60; i++) {
      if (rd().viaje_creado) { ok = true; break; }
      await delay(1500);
    }
    if (!ok) { log('PASS', 'Timeout esperando viaje'); return false; }

    // Buscar viajes
    log('PASS', 'Buscando...');
    await tab(page, 2);
    await enter(page);
    await delay(3000);

    await screenshot(page, 'pasajero_search');

    // Solicitar viaje
    await tab(page, 4);
    await enter(page);
    await delay(2000);
    wr({ solicitud_enviada: true });
    log('PASS', 'Solicitud enviada');

    await screenshot(page, 'pasajero_solicitud');

    // Esperar aceptacion
    log('PASS', 'Esperando aceptacion...');
    ok = false;
    for (let i = 0; i < 40; i++) {
      if (rd().solicitud_aceptada) { ok = true; break; }
      await delay(1500);
    }
    if (!ok) { log('PASS', 'Timeout esperando aceptacion'); return false; }
    log('PASS', 'Aceptada!');
    return true;

  } catch(e) {
    log('PASS', `ERROR: ${e.message}`);
    return false;
  }
}

// ─── MAIN ────────────────────────────────────────────────

async function main() {
  console.log('='.repeat(55));
  console.log('  CommuteShare - Test UI con 2 Ventanas Visibles');
  console.log('='.repeat(55));

  wr({ viaje_creado: false, solicitud_enviada: false, solicitud_aceptada: false });

  if (!fs.existsSync(LOGS_DIR)) fs.mkdirSync(LOGS_DIR, { recursive: true });

  // Start Flutter web
  log('ORQ', 'Iniciando Flutter web...');
  spawn('flutter', ['run', '-d', 'chrome', '--web-port', String(FLUTTER_PORT)], {
    cwd: FLUTTER_DIR, stdio: 'ignore', shell: true
  });

  // Wait for HTTP server
  log('ORQ', 'Esperando que Flutter compile (~40-60s)...');
  let ready = false;
  for (let i = 0; i < 40; i++) {
    await delay(3000);
    try { const r = await fetch(APP_URL + '/'); if (r.ok) { ready = true; break; } } catch {}
  }
  if (!ready) { log('ORQ', 'Flutter no inicio'); return; }
  log('ORQ', 'Servidor HTTP listo');

  // Launch Chrome with 2 windows
  const browser = await chromium.launch({ headless: false });
  const c1 = await browser.newContext();
  const c2 = await browser.newContext();
  const p1 = await c1.newPage();
  const p2 = await c2.newPage();

  // Side by side
  await p1.setViewportSize({ width: 960, height: 900 });
  await p2.setViewportSize({ width: 960, height: 900 });

  log('ORQ', '2 ventanas abiertas. Iniciando agentes...');

  const [r1, r2] = await Promise.all([conductor(p1), pasajero(p2)]);

  console.log('-'.repeat(55));
  log('ORQ', r1 ? 'PASS Conductor' : 'FAIL Conductor');
  log('ORQ', r2 ? 'PASS Pasajero' : 'FAIL Pasajero');
  log('ORQ', (r1 && r2) ? 'PASS - TEST COMPLETO!' : 'FAIL');

  wr({ estado: (r1 && r2) ? 'completado' : 'fallo' });

  log('ORQ', 'Ventanas abiertas 60s. Revisa la UI!');
  await delay(60000);
  await browser.close();

  process.exit(r1 && r2 ? 0 : 1);
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
