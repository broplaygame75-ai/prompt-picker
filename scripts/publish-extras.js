#!/usr/bin/env node
/**
 * After electron-builder publishes the exe and latest.yml, pack the install
 * guide zip, upload it, refresh release notes, and update the public
 * releases-repo README. Old 0.1.3/0.1.4 note edits are best-effort.
 */
const fs = require('fs');
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
function writeZip(stageDir, zipFile) {
  const zipRel = path.relative(root, zipFile).split(path.sep).join('/');
  const stageRel = path.relative(root, stageDir).split(path.sep).join('/');
  try {
    execFileSync('tar', ['--force-local', '-a', '-c', '-f', zipRel, '-C', stageRel, '.'], {cwd: root, stdio: 'inherit'});
    return;
  } catch (e) {
    if (process.platform !== 'win32') throw e;
    console.log('tar could not write the zip, using Compress-Archive');
    if (fs.existsSync(zipFile)) fs.unlinkSync(zipFile);
    const q = s => "'" + String(s).replace(/'/g, "''") + "'";
    execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', `Compress-Archive -Path ${q(stageDir + '\\*')} -DestinationPath ${q(zipFile)} -Force`], {stdio: 'inherit'});
  }
}
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
  writeZip(stage, zip);
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
    const text = fs.readFileSync(file, 'utf8').trim();
    const body = text.replace(/\]\(([a-z]{2}\/[^)]+)\)/g, '](https://github.com/' + owner + '/' + repo + '/raw/main/guide/$1)');
    return '<!-- lang:' + code + ' -->\n' + body + '\n<!-- /lang:' + code + ' -->';
  }).join('\n\n');
}

async function putFile(repoPath, buf, message) {
  const urlPath = '/repos/' + owner + '/' + repo + '/contents/' + repoPath.split('/').map(encodeURIComponent).join('/');
  let sha = null;
  try {
    const cur = await api('GET', urlPath + '?ref=main');
    sha = cur.json && cur.json.sha;
  } catch (e) {
    if (e.status !== 404) throw e;
  }
  const body = {message, content: buf.toString('base64'), branch: 'main'};
  if (sha) body.sha = sha;
  await api('PUT', urlPath, body);
  console.log('wrote', repoPath);
}

async function pushReadme() {
  const files = [];
  function walk(dir, prefix) {
    for (const name of fs.readdirSync(dir)) {
      if (name.endsWith('.exe')) continue;
      const src = path.join(dir, name);
      const rel = prefix ? prefix + '/' + name : name;
      if (fs.statSync(src).isDirectory()) walk(src, rel);
      else files.push({rel: 'guide/' + rel, buf: fs.readFileSync(src)});
    }
  }
  walk(stage, '');
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
    rootize(fs.readFileSync(path.join(stage, 'HOW-TO-INSTALL.md'), 'utf8').trim()),
    '',
    'The pictures in each guide use paths next to that file, so they display on this site and inside the app for the language you selected.',
    ''
  ].join('\n');
  files.push({rel: 'README.md', buf: Buffer.from(readme, 'utf8')});
  for (const file of files) await putFile(file.rel, file.buf, 'Update ' + file.rel + ' for Prompt Picker ' + version);
  return true;
}

async function setNotes(tag, body) {
  try {
    const rel = await releaseByTag(tag);
    const patch = {body};
    if (tag === 'v0.1.9') patch.name = 'v0.1.9 (0.1.8.1 fixes)';
    await api('PATCH', `/repos/${owner}/${repo}/releases/${rel.id}`, patch);
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
  report.readme = await pushReadme();
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
