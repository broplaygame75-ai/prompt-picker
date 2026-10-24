#!/usr/bin/env node
// Asks a running Prompt Picker (remote debugging) to open Prompt Log and
// checks the empty character panes are tall enough to show the empty sentence.
const http = require('http');
const crypto = require('crypto');
const net = require('net');

const port = Number(process.argv.includes('--port') ? process.argv[process.argv.indexOf('--port') + 1] : 9224);
const timeoutMs = Number(process.argv.includes('--timeout') ? process.argv[process.argv.indexOf('--timeout') + 1] : 30000);
const NEED = 'No characters yet. Copy a prompt with a Name - Source.';

function getJson(path) {
  return new Promise((resolve, reject) => {
    const req = http.get({host: '127.0.0.1', port, path, timeout: 2000}, res => {
      let d = '';
      res.on('data', c => { d += c; });
      res.on('end', () => {
        try { resolve(JSON.parse(d)); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('list timeout')); });
  });
}

function connect(wsUrl) {
  const u = new URL(wsUrl);
  return new Promise((resolve, reject) => {
    const key = crypto.randomBytes(16).toString('base64');
    const sock = net.connect({host: u.hostname, port: Number(u.port) || port});
    let buf = Buffer.alloc(0);
    let up = false;
    const frames = [];
    const waiters = [];
    function pushFrame(text) {
      if (waiters.length) waiters.shift()(text);
      else frames.push(text);
    }
    function nextFrame() {
      if (frames.length) return Promise.resolve(frames.shift());
      return new Promise(r => waiters.push(r));
    }
    function send(obj) {
      const data = Buffer.from(JSON.stringify(obj));
      const mask = crypto.randomBytes(4);
      let header;
      if (data.length < 126) header = Buffer.from([0x81, 0x80 | data.length]);
      else {
        header = Buffer.alloc(4);
        header[0] = 0x81;
        header[1] = 0x80 | 126;
        header.writeUInt16BE(data.length, 2);
      }
      const masked = Buffer.alloc(data.length);
      for (let i = 0; i < data.length; i++) masked[i] = data[i] ^ mask[i % 4];
      sock.write(Buffer.concat([header, mask, masked]));
    }
    function parse() {
      while (buf.length >= 2) {
        const b1 = buf[1];
        let len = b1 & 0x7f;
        let off = 2;
        if (len === 126) {
          if (buf.length < 4) return;
          len = buf.readUInt16BE(2);
          off = 4;
        } else if (len === 127) {
          if (buf.length < 10) return;
          len = Number(buf.readBigUInt64BE(2));
          off = 10;
        }
        if (buf.length < off + len) return;
        const op = buf[0] & 0x0f;
        const payload = buf.slice(off, off + len);
        buf = buf.slice(off + len);
        if (op === 1) pushFrame(payload.toString('utf8'));
      }
    }
    sock.on('data', chunk => {
      buf = Buffer.concat([buf, chunk]);
      if (!up) {
        const idx = buf.indexOf('\r\n\r\n');
        if (idx < 0) return;
        const head = buf.slice(0, idx).toString('utf8');
        if (!/^HTTP\/1\.1 101/.test(head)) {
          reject(new Error(head.split('\r\n')[0]));
          sock.destroy();
          return;
        }
        buf = buf.slice(idx + 4);
        up = true;
        resolve({send, nextFrame, close: () => sock.end()});
        parse();
        return;
      }
      parse();
    });
    sock.on('error', reject);
    sock.on('connect', () => {
      const p = u.pathname + u.search;
      sock.write(
        'GET ' + p + ' HTTP/1.1\r\n' +
        'Host: ' + u.host + '\r\n' +
        'Upgrade: websocket\r\n' +
        'Connection: Upgrade\r\n' +
        'Sec-WebSocket-Key: ' + key + '\r\n' +
        'Sec-WebSocket-Version: 13\r\n\r\n'
      );
    });
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const deadline = Date.now() + timeoutMs;
  let last = 'debugger not open';
  let page = null;
  while (Date.now() < deadline && !page) {
    try {
      const list = await getJson('/json');
      page = (Array.isArray(list) ? list : []).find(t => t && t.type === 'page' && t.webSocketDebuggerUrl);
      if (!page) last = 'no page target';
    } catch (e) { last = e.message; }
    if (!page) await sleep(400);
  }
  if (!page) throw new Error(last);
  const ws = await connect(page.webSocketDebuggerUrl);
  let id = 0;
  async function call(method, params) {
    const msgId = ++id;
    ws.send({id: msgId, method, params: params || {}});
    const until = Date.now() + 8000;
    while (Date.now() < until) {
      const raw = await Promise.race([
        ws.nextFrame(),
        sleep(8000).then(() => { throw new Error('cdp timeout ' + method); })
      ]);
      const msg = JSON.parse(raw);
      if (msg.id === msgId) {
        if (msg.error) throw new Error(method + ' ' + JSON.stringify(msg.error));
        return msg.result;
      }
    }
    throw new Error('cdp timeout ' + method);
  }
  await call('Runtime.enable');
  const expression = `(() => {
    const age = document.body && document.body.classList.contains('age-locked');
    if (age) { const b = document.querySelector('#ageyes'); if (b) b.click(); }
    const tour = document.querySelector('#tour');
    if (tour && tour.classList.contains('on')) { const s = document.querySelector('#tourskip'); if (s) s.click(); }
    const log = document.querySelector('#v-log');
    if (log && log.classList.contains('hid')) { const n = document.querySelector('nav button[data-v="log"]'); if (n) n.click(); }
    const chars = document.querySelector('#logchars');
    const entries = document.querySelector('#logentries');
    if (!chars || !entries || !log || log.classList.contains('hid') || (document.body && document.body.classList.contains('age-locked'))) return {ready:false};
    const need = ${JSON.stringify(NEED)};
    function info(el) {
      const r = el.getBoundingClientRect();
      const p = el.querySelector('p');
      const pr = p ? p.getBoundingClientRect() : null;
      return {h: r.height, client: el.clientHeight, text: String(el.textContent || '').replace(/\\s+/g, ' ').trim(), clipped: !pr || pr.top < r.top - 1 || pr.bottom > r.bottom + 1};
    }
    const a = info(chars), b = info(entries);
    return {ready: a.text.indexOf(need) >= 0 && b.text.indexOf(need) >= 0, chars: a, entries: b};
  })()`;
  let saw = null;
  while (Date.now() < deadline) {
    const result = await call('Runtime.evaluate', {expression, returnByValue: true});
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    saw = result.result && result.result.value;
    if (saw && saw.ready && saw.chars.h >= 120 && saw.entries.h >= 120 && !saw.chars.clipped && !saw.entries.clipped) {
      console.log(JSON.stringify(saw));
      ws.close();
      return;
    }
    await sleep(400);
  }
  ws.close();
  throw new Error('empty log panes were not visible: ' + JSON.stringify(saw));
}

main().catch(e => {
  console.error(e && e.stack || e);
  process.exit(1);
});
