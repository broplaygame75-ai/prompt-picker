const {app,BrowserWindow,ipcMain,dialog,shell}=require('electron');
const path=require('path'),fs=require('fs'),https=require('https');
const {autoUpdater}=require('electron-updater');
const {fixedDataDir,adoptExistingData}=require('./dataDir');
const cfgPath=()=>path.join(app.getPath('userData'),'config.json');
function cfg(){try{return JSON.parse(fs.readFileSync(cfgPath()))}catch(e){return{}}}
function dataSources(){const sources=[];try{const userData=app.getPath('userData');sources.push(path.join(userData,'data'));const custom=cfg().dataDir;if(typeof custom==='string'&&custom.trim())sources.push(custom.trim())}catch(e){}return sources}
function dataDir(){return adoptExistingData(fixedDataDir(app.getPath('appData')),dataSources())}
const dataFile=()=>path.join(dataDir(),'prompts.json');
function writeAtomic(f,s){fs.writeFileSync(f+'.tmp',s);fs.renameSync(f+'.tmp',f);}
let win,settingsWin;
const winOpts=()=>({backgroundColor:'#0f0d14',icon:path.join(__dirname,'../build/icon.png'),autoHideMenuBar:true,webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true}});
function create(){win=new BrowserWindow(Object.assign(winOpts(),{width:1500,height:950,minWidth:360,title:'Prompt Picker'}));win.loadFile(path.join(__dirname,'index.html'));win.on('closed',()=>{win=null;if(settingsWin&&!settingsWin.isDestroyed())settingsWin.close()});}
function openSettings(tab){const token=typeof tab==='string'?tab:'';if(settingsWin&&!settingsWin.isDestroyed()){if(settingsWin.isMinimized())settingsWin.restore();settingsWin.focus();settingsWin.webContents.send('settings-tab',token);return}settingsWin=new BrowserWindow(Object.assign(winOpts(),{width:960,height:780,minWidth:560,minHeight:480,title:'Settings'}));settingsWin.loadFile(path.join(__dirname,'index.html'),{query:{view:'settings',tab:token}});settingsWin.on('closed',()=>{settingsWin=null});}
function otherWindows(sender){return BrowserWindow.getAllWindows().filter(w=>!w.isDestroyed()&&w.webContents!==sender)}
ipcMain.handle('version',()=>app.getVersion());
ipcMain.handle('load',()=>{try{return JSON.parse(fs.readFileSync(dataFile(),'utf8'))}catch(e){return null}});
ipcMain.handle('save',(e,s)=>{writeAtomic(dataFile(),s);return true});
ipcMain.handle('settings-open',(e,tab)=>{openSettings(tab);return true});
ipcMain.on('update-request',(e,version)=>{const sender=BrowserWindow.fromWebContents(e.sender);if(settingsWin&&!settingsWin.isDestroyed()&&sender===settingsWin)settingsWin.close();if(win&&!win.isDestroyed()){if(win.isMinimized())win.restore();win.show();win.focus();win.webContents.send('update-request',typeof version==='string'?version:'')}});
ipcMain.on('state-push',(e,text)=>{if(typeof text!=='string'||text.length>20000000)return;otherWindows(e.sender).forEach(w=>w.webContents.send('state-push',text))});
ipcMain.on('theme-preview',(e,colors)=>{if(!colors||typeof colors!=='object')return;otherWindows(e.sender).forEach(w=>w.webContents.send('theme-preview',colors))});
const FONT_STEPS=[0.9,1,1.15,1.3,1.5];
ipcMain.on('font-scale',(e,scale)=>{const x=Number(scale);const n=FONT_STEPS.reduce((best,s)=>Math.abs(s-x)<Math.abs(best-x)?s:best,1);BrowserWindow.getAllWindows().forEach(w=>{if(!w.isDestroyed())w.webContents.setZoomFactor(Number.isFinite(x)?n:1)})});
ipcMain.handle('img-save',(e,id,dataUrl)=>{const b=Buffer.from(dataUrl.split(',')[1],'base64');fs.writeFileSync(path.join(dataDir(),'images',id+'.webp'),b);return true});
ipcMain.handle('img-read',(e,id)=>{try{return 'data:image/webp;base64,'+fs.readFileSync(path.join(dataDir(),'images',id+'.webp')).toString('base64')}catch(x){return null}});
ipcMain.handle('img-del',(e,id)=>{try{fs.unlinkSync(path.join(dataDir(),'images',id+'.webp'))}catch(x){}return true});
ipcMain.handle('dir-get',()=>dataDir());
ipcMain.handle('dir-open',()=>shell.openPath(dataDir()));
function uiLang(){try{const s=JSON.parse(fs.readFileSync(dataFile(),'utf8'));if(s.langChosen===true&&['en','vi','zh','ko'].includes(s.lang))return s.lang}catch(e){}return 'en'}
ipcMain.handle('dir-change',()=>dataDir());
ipcMain.handle('save-file',async(e,name,text,title)=>{const fallback={en:'Save backup',vi:'Lưu file sao lưu',zh:'保存备份',ko:'백업 저장'}[uiLang()]||'Save backup';const parent=BrowserWindow.fromWebContents(e.sender)||win;const r=await dialog.showSaveDialog(parent,{title:typeof title==='string'&&title.trim()?title.trim():fallback,defaultPath:name,filters:[{name:'JSON',extensions:['json']}]});if(r.canceled)return false;fs.writeFileSync(r.filePath,text);return true});
// updates
autoUpdater.autoDownload=false;
autoUpdater.autoInstallOnAppQuit=false;
function parseVer(v){return String(v||'').replace(/^v/i,'').split('.').map(n=>parseInt(n,10)||0)}
function isNewerVersion(next,current){const a=parseVer(next),b=parseVer(current),n=Math.max(a.length,b.length);for(let i=0;i<n;i++){const d=(a[i]||0)-(b[i]||0);if(d)return d>0}return false}
const send=msg=>{BrowserWindow.getAllWindows().forEach(w=>{if(!w.isDestroyed())w.webContents.send('upd',msg)})};
autoUpdater.on('update-available',i=>{const version=i&&i.version;if(!version||!isNewerVersion(version,app.getVersion()))return;send({type:'available',version})});
autoUpdater.on('update-not-available',()=>send({type:'none'}));
autoUpdater.on('download-progress',p=>send({type:'progress',percent:p&&p.percent||0}));
autoUpdater.on('update-downloaded',()=>{send({type:'progress',percent:100});if(app.isPackaged)autoUpdater.installDirectory=path.dirname(process.execPath);autoUpdater.quitAndInstall(true,true)});
autoUpdater.on('error',e=>send({type:'error',message:String(e&&e.message||e)}));
ipcMain.handle('upd-check',()=>app.isPackaged?autoUpdater.checkForUpdates().then(()=>true).catch(e=>{send({type:'error',message:String(e.message)});return false}):(send({type:'error',code:'unpackaged-check'}),false));
ipcMain.handle('upd-download',async()=>{if(!app.isPackaged){send({type:'error',code:'unpackaged-download'});return false}try{await autoUpdater.downloadUpdate();return true}catch(e){send({type:'error',message:String(e&&e.message||e)});return false}});
function fetchJson(url){return new Promise((resolve,reject)=>{const req=https.get(url,{headers:{'User-Agent':'PromptPicker','Accept':'application/vnd.github+json'}},res=>{let d='';res.on('data',c=>{d+=c;if(d.length>2000000)req.destroy()});res.on('end',()=>{const code=res.statusCode||0;if(code>=300&&code<400&&res.headers.location)return fetchJson(res.headers.location).then(resolve,reject);if(code!==200)return reject(new Error('HTTP '+code));try{resolve(JSON.parse(d))}catch(e){reject(e)}})});req.on('error',reject);req.setTimeout(20000,()=>{req.destroy();reject(new Error('timeout'))})})}
ipcMain.handle('releases',async()=>{const list=await fetchJson('https://api.github.com/repos/broplaygame75-ai/prompt-picker-releases/releases?per_page=20');if(!Array.isArray(list))return [];return list.filter(r=>r&&!r.draft&&!r.prerelease).slice(0,20).map(r=>({version:String(r.tag_name||r.name||'').replace(/^v/i,''),body:String(r.body||''),published:r.published_at||''}))});
ipcMain.handle('quit',()=>{app.quit();return true});
app.whenReady().then(()=>{if(app.isPackaged)autoUpdater.installDirectory=path.dirname(process.execPath);create();if(app.isPackaged){setTimeout(()=>autoUpdater.checkForUpdates().catch(()=>{}),5000);setInterval(()=>autoUpdater.checkForUpdates().catch(()=>{}),30*60*1000);}});
app.on('window-all-closed',()=>app.quit());
