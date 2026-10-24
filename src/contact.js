const TELEGRAM_URL = 'https://t.me/linekoaiart';

const CONTACTS = [
  {id: 'discord', name: 'Discord', url: 'https://discord.gg/yH5AAdj5qY', preferred: true},
  {id: 'patreon', name: 'Patreon', url: 'https://www.patreon.com/c/linekoaiart447658', preferred: false},
  {id: 'x', name: 'X', url: 'https://x.com/lyht111222333', preferred: false},
  {id: 'telegram', name: 'Telegram', url: TELEGRAM_URL, preferred: false}
];

function contactHosts() {
  const hosts = [];
  for (const c of CONTACTS) {
    if (!c.url) continue;
    try { hosts.push(new URL(c.url).hostname.toLowerCase()); } catch (e) {}
  }
  return hosts;
}

module.exports = {TELEGRAM_URL, CONTACTS, contactHosts};
