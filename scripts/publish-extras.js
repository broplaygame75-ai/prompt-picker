#!/usr/bin/env node
/**
 * After electron-builder publishes the exe and latest.yml, pack the install
 * guide zip, upload it, refresh release notes, and update the public
 * releases-repo README. Old 0.1.3/0.1.4 note edits are best-effort.
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const {execFileSync} = require('child_process');

const root = path.join(__dirname, '..');
const version = require(path.join(root, 'package.json')).version;
const token = process.env.GH_TOKEN || '';
const owner = 'broplaygame75-ai';
const repo = 'prompt-picker-releases';
const stage = path.join(root, 'dist', 'guide-stage');
const report = {version, zip: false, notes: {}, readme: false};

function fill(s) { return String(s).split('{{version}}').join(version); }
function rootize(md) {
  return md.replace(/\]\(HOW-TO-INSTALL/g, '](guide/HOW-TO-INSTALL').replace(/\]\(([a-z]{2}\/[^)]+)\)/g, '](guide/$1)');
}

function stageGuide() {
  fs.rmSync(stage, {recursive: true, force: true});
  fs.mkdirSync(stage, {recursive: true});
  const guide = path.join(root, 'install-guide');
  for (const name of fs.readdirSync(guide)) {
    const src = path.join(guide, name);
    if (fs.statSync(src).isDirectory()) {
      const dest = path.join(stage, name);
      fs.mkdirSync(dest, {recursive: true});
      for (const file of fs.readdirSync(src)) {
        if (file.endsWith('.png')) fs.copyFileSync(path.join(src, file), path.join(dest, file));
      }
    } else if (name.endsWith('.md')) {
      fs.writeFileSync(path.join(stage, name), fill(fs.readFileSync(src, 'utf8')));
    }
  }
  const exeName = `PromptPicker-Setup-${version}.exe`;
  const exe = path.join(root, 'dist', exeName);
  if (!fs.existsSync(exe)) {
    console.error('Missing installer: ' + exe);
    process.exit(1);
  }
  fs.copyFileSync(exe, path.join(stage, exeName));
  const zip = path.join(root, 'dist', `PromptPicker-${version}-Windows.zip`);
  if (fs.existsSync(zip)) fs.unlinkSync(zip);
  execFileSync('tar', ['-a', '-c', '-f', zip, '-C', stage, '.'], {stdio: 'inherit'});
  console.log('zip bytes', fs.statSync(zip).size);
  report.zip = true;
  return zip;
}

function request(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request({
      method, hostname: u.hostname, path: u.pathname + u.search, headers
    }, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        const text = buf.toString('utf8');
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({status: res.statusCode, text, json: text ? safeJson(text) : null, headers: res.headers});
        } else {
          const err = new Error('HTTP ' + res.statusCode);
          err.status = res.statusCode;
          err.body = text.slice(0, 500);
          reject(err);
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}
function safeJson(text) { try { return JSON.parse(text); } catch (e) { return null; } }
function api(method, p, body) {
  const headers = {Authorization: 'Bearer ' + token, 'User-Agent': 'PromptPicker', Accept: 'application/vnd.github+json'};
  let data;
  if (body != null) { data = Buffer.from(JSON.stringify(body)); headers['Content-Type'] = 'application/json'; headers['Content-Length'] = data.length; }
  return request(method, 'https://api.github.com' + p, headers, data);
}

async function releaseByTag(tag) {
  return (await api('GET', `/repos/${owner}/${repo}/releases/tags/${encodeURIComponent(tag)}`)).json;
}

async function uploadZip(rel, zip) {
  const name = path.basename(zip);
  const existing = (rel.assets || []).find(a => a.name === name);
  if (existing) await api('DELETE', `/repos/${owner}/${repo}/releases/assets/${existing.id}`);
  const buf = fs.readFileSync(zip);
  const headers = {
    Authorization: 'Bearer ' + token,
    'User-Agent': 'PromptPicker',
    Accept: 'application/vnd.github+json',
    'Content-Type': 'application/zip',
    'Content-Length': buf.length
  };
  await request('POST', `https://uploads.github.com/repos/${owner}/${repo}/releases/${rel.id}/assets?name=${encodeURIComponent(name)}`, headers, buf);
  console.log('uploaded', name);
}

function notesFor(ver) {
  const file = path.join(root, 'release-notes', ver + '.md');
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8').trim() : '';
}

function guideBody() {
  const langs = ['en', 'vi', 'zh', 'ko'];
  return langs.map(code => {
    const file = path.join(stage, `HOW-TO-INSTALL.${code}.md`);
    const text = fs.readFileSync(file, 'utf8');
    return text.replace(/\]\(([a-z]{2}\/[^)]+)\)/g, '](https://github.com/' + owner + '/' + repo + '/raw/main/guide/$1)');
  }).join('\n\n');
}

function gitEnv() {
  return Object.assign({}, process.env, {
    GIT_TERMINAL_PROMPT: '0',
    GIT_CONFIG_COUNT: '1',
    GIT_CONFIG_KEY_0: 'http.extraheader',
    GIT_CONFIG_VALUE_0: 'AUTHORIZATION: bearer ' + token
  });
}

function pushReadme() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pprel-'));
  const url = `https://github.com/${owner}/${repo}.git`;
  try {
    execFileSync('git', ['clone', '--depth', '1', url, dir], {env: gitEnv(), stdio: ['ignore', 'pipe', 'pipe']});
  } catch (e) {
    console.error('clone releases repo failed', e.status || '');
    return false;
  }
  const guideDir = path.join(dir, 'guide');
  fs.rmSync(guideDir, {recursive: true, force: true});
  fs.mkdirSync(guideDir, {recursive: true});
  for (const name of fs.readdirSync(stage)) {
    const src = path.join(stage, name);
    if (name.endsWith('.exe')) continue;
    const dest = path.join(guideDir, name);
    if (fs.statSync(src).isDirectory()) {
      fs.mkdirSync(dest, {recursive: true});
      for (const file of fs.readdirSync(src)) fs.copyFileSync(path.join(src, file), path.join(dest, file));
    } else fs.copyFileSync(src, dest);
  }
  const readme = [
    '# Prompt Picker',
    '',
    '**18+.** Prompt Picker is for adults.',
    '',
    'Downloads are on the [releases](https://github.com/' + owner + '/' + repo + '/releases) page.',
    '',
    'Auto-update uses `PromptPicker-Setup-' + version + '.exe` and `latest.yml`. Leave those file names as they are.',
    '',
    '`PromptPicker-' + version + '-Windows.zip` contains the Setup exe, the install guide, and the pictures.',
    '',
    'Windows may say "Windows protected your PC" because the app is not code-signed. Click **More info**, then **Run anyway**. Do not turn off SmartScreen or Defender. The pictures are illustrations.',
    '',
    rootize(fs.readFileSync(path.join(guideDir, 'HOW-TO-INSTALL.md'), 'utf8').trim()),
    '',
    rootize(fs.readFileSync(path.join(guideDir, 'HOW-TO-INSTALL.en.md'), 'utf8').trim()),
    '',
    rootize(fs.readFileSync(path.join(guideDir, 'HOW-TO-INSTALL.vi.md'), 'utf8').trim()),
    '',
    rootize(fs.readFileSync(path.join(guideDir, 'HOW-TO-INSTALL.zh.md'), 'utf8').trim()),
    '',
    rootize(fs.readFileSync(path.join(guideDir, 'HOW-TO-INSTALL.ko.md'), 'utf8').trim()),
    ''
  ].join('\n');
  fs.writeFileSync(path.join(dir, 'README.md'), readme);
  execFileSync('git', ['-C', dir, 'config', 'user.email', 'cursoragent@cursor.com']);
  execFileSync('git', ['-C', dir, 'config', 'user.name', 'Cursor Agent']);
  execFileSync('git', ['-C', dir, 'add', 'README.md', 'guide'], {env: gitEnv()});
  const status = execFileSync('git', ['-C', dir, 'status', '--porcelain'], {encoding: 'utf8'});
  if (!status.trim()) { console.log('releases README unchanged'); return true; }
  execFileSync('git', ['-C', dir, 'commit', '-m', 'Update the Prompt Picker ' + version + ' install guide'], {env: gitEnv()});
  try {
    execFileSync('git', ['-C', dir, 'push', 'origin', 'HEAD:main'], {env: gitEnv(), stdio: ['ignore', 'pipe', 'pipe']});
  } catch (e) {
    console.error('push releases README failed', e.status || '');
    return false;
  }
  console.log('updated releases README');
  return true;
}

async function setNotes(tag, body) {
  try {
    const rel = await releaseByTag(tag);
    await api('PATCH', `/repos/${owner}/${repo}/releases/${rel.id}`, {body});
    report.notes[tag] = 'updated';
    console.log('notes', tag);
    return rel;
  } catch (e) {
    report.notes[tag] = 'failed ' + (e.status || e.message);
    console.error('notes', tag, report.notes[tag]);
    return null;
  }
}

async function main() {
  const zip = stageGuide();
  if (!token) {
    console.log('GH_TOKEN is not set. Zip is staged only.');
    fs.writeFileSync(path.join(root, 'dist', 'publish-report.json'), JSON.stringify(report, null, 2));
    return;
  }
  report.readme = pushReadme();
  const current = await setNotes('v' + version, notesFor(version) + '\n\n' + guideBody());
  if (!current) {
    fs.writeFileSync(path.join(root, 'dist', 'publish-report.json'), JSON.stringify(report, null, 2));
    process.exit(1);
  }
  await uploadZip(current, zip);
  for (const old of ['0.1.3', '0.1.4']) {
    if (old === version) continue;
    const body = notesFor(old);
    if (body) await setNotes('v' + old, body);
  }
  fs.writeFileSync(path.join(root, 'dist', 'publish-report.json'), JSON.stringify(report, null, 2));
  if (!report.readme) process.exit(1);
  const failedOld = Object.entries(report.notes).filter(([tag, state]) => tag !== 'v' + version && String(state).startsWith('failed'));
  if (failedOld.length) {
    console.error('Old release notes were not all updated. The 0.1.6 release itself is published.');
  }
}

main().catch(e => {
  console.error(e.status || '', e.message || e);
  process.exit(1);
});
