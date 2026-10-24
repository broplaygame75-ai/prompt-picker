const {app,BrowserWindow,ipcMain,dialog,shell}=require('electron');
const path=require('path'),fs=require('fs'),https=require('https');
const {autoUpdater}=require('electron-updater');
const {execFile,spawn}=require('child_process');
const {fixedDataDir,adoptExistingData,withActiveDataDir,windowsRememberCommands,APP_ID,MARKER_NAME,normalizeDataPath,reuseSources}=require('./dataDir');
const {planShortcutRepair,shortcutLocations}=require('./shortcuts');
const {startupCopy}=require('./startupCopy');
const {installerUrl,versionFromRelease}=require('./repair');
const cfgPath=()=>path.join(app.getPath('userData'),'config.json');
function cfg(){try{return JSON.parse(fs.readFileSync(cfgPath()))}catch(e){return{}}}
function readText(f){try{return fs.readFileSync(f,'utf8')}catch(e){return ''}}
function dataSources(){
  const sources=[];
  try{
    const userData=app.getPath('userData');
    sources.push(path.join(userData,'data'));
    const custom=cfg().dataDir;
    if(typeof custom==='string'&&custom.trim())sources.push(custom.trim());
    const exeDir=app.isPackaged?path.dirname(process.execPath):'';
    const pointer=readText(path.join(app.getPath('appData'),'Prompt Picker',MARKER_NAME));
    const local=exeDir?readText(path.join(exeDir,MARKER_NAME)):'';
    for(const s of reuseSources(exeDir,pointer,local))sources.push(s);
  }catch(e){}
  return sources;
}
function dataDir(){return adoptExistingData(fixedDataDir(app.getPath('appData')),dataSources())}
const dataFile=()=>path.join(dataDir(),'prompts.json');
function writeAtomic(f,s){fs.writeFileSync(f+'.tmp',s);fs.renameSync(f+'.tmp',f);}
let win,settingsWin;
const winOpts=()=>({backgroundColor:'#0f0d14',icon:path.join(__dirname,'../build/icon.png'),autoHideMenuBar:true,webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true}});
function watchWindow(w){
  if(!w||w.isDestroyed())return;
  w.webContents.on('render-process-gone',(e,details)=>{
    logCrash('render-process-gone',details);
    if(!details||details.reason==='clean-exit')return;
    offerRepair(details);
  });
  w.webContents.on('did-fail-load',(e,code,desc,url,isMainFrame)=>{
    if(!isMainFrame||code===0||code===-3)return;
    logCrash('did-fail-load',code+' '+desc+' '+url);
    offerRepair(desc||code);
  });
}
function create(){win=new BrowserWindow(Object.assign(winOpts(),{width:1500,height:950,minWidth:360,title:'Prompt Picker'}));guardExternal(win);watchWindow(win);win.loadFile(path.join(__dirname,'index.html'));win.on('closed',()=>{win=null;if(settingsWin&&!settingsWin.isDestroyed())settingsWin.close()});}
function openSettings(tab){const token=typeof tab==='string'?tab:'';if(settingsWin&&!settingsWin.isDestroyed()){if(settingsWin.isMinimized())settingsWin.restore();settingsWin.focus();settingsWin.webContents.send('settings-tab',token);return}settingsWin=new BrowserWindow(Object.assign(winOpts(),{width:960,height:780,minWidth:560,minHeight:480,title:'Settings'}));guardExternal(settingsWin);watchWindow(settingsWin);settingsWin.loadFile(path.join(__dirname,'index.html'),{query:{view:'settings',tab:token}});settingsWin.on('closed',()=>{settingsWin=null});}
function otherWindows(sender){return BrowserWindow.getAllWindows().filter(w=>!w.isDestroyed()&&w.webContents!==sender)}
ipcMain.handle('version',()=>app.getVersion());
ipcMain.handle('load',()=>{try{return JSON.parse(fs.readFileSync(dataFile(),'utf8'))}catch(e){return null}});
ipcMain.handle('save',(e,s)=>{writeAtomic(dataFile(),s);return true});
ipcMain.on('save-sync',(e,s)=>{if(typeof s==='string'&&s.length<20000000)writeAtomic(dataFile(),s);e.returnValue=true});
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
function externalOk(url){try{const u=new URL(String(url));if(u.protocol!=='https:')return false;const host=u.hostname.toLowerCase();return host==='x.com'||host==='www.x.com'||host==='patreon.com'||host==='www.patreon.com'||host==='discord.gg'||host==='github.com'||host==='www.github.com'}catch(e){return false}}
function guardExternal(w){if(!w||w.isDestroyed())return;w.webContents.setWindowOpenHandler(({url})=>{if(externalOk(url))shell.openExternal(url);return{action:'deny'}});w.webContents.on('will-navigate',(e,url)=>{if(String(url).startsWith('file:'))return;e.preventDefault();if(externalOk(url))shell.openExternal(url)})}
ipcMain.handle('open-external',(e,url)=>externalOk(url)?shell.openExternal(String(url)).then(()=>true).catch(()=>false):false);
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
autoUpdater.on('update-downloaded',info=>{const version=info&&info.version;send({type:'downloaded',version:version?String(version).replace(/^v/i,''):''})});
autoUpdater.on('error',e=>{logCrash('updater',e);send({type:'error',message:String(e&&e.message||e)})});
function checkUpdates(){
  if(!app.isPackaged)return;
  try{
    const pending=autoUpdater.checkForUpdates();
    if(pending&&typeof pending.catch==='function')pending.catch(e=>logCrash('update-check',e));
  }catch(e){logCrash('update-check',e)}
}
ipcMain.handle('upd-check',()=>app.isPackaged?autoUpdater.checkForUpdates().then(()=>true).catch(e=>{send({type:'error',message:String(e.message)});return false}):(send({type:'error',code:'unpackaged-check'}),false));
ipcMain.handle('upd-download',async()=>{if(!app.isPackaged){send({type:'error',code:'unpackaged-download'});return false}try{await autoUpdater.downloadUpdate();return true}catch(e){send({type:'error',message:String(e&&e.message||e)});return false}});
ipcMain.handle('upd-install',()=>{
  if(!app.isPackaged){send({type:'error',code:'unpackaged-download'});return false}
  // NSIS only honors /D= as the last argument, and it must be unquoted.
  // electron-updater puts /D= before --package-file, and "Prompt Picker" has a
  // space, so the quoted /D= makes a silent install miss the shortcut's folder.
  // Leave installDirectory unset and let the per-user registry path stand.
  autoUpdater.installDirectory=undefined;
  autoUpdater.autoInstallOnAppQuit=false;
  autoUpdater.autoRunAppAfterInstall=true;
  if(autoUpdater.quitAndInstallCalled)autoUpdater.quitAndInstallCalled=false;
  autoUpdater.quitAndInstall(true,true);
  return true;
});
function fetchJson(url){return new Promise((resolve,reject)=>{const req=https.get(url,{headers:{'User-Agent':'PromptPicker','Accept':'application/vnd.github+json'}},res=>{let d='';res.on('data',c=>{d+=c;if(d.length>2000000)req.destroy()});res.on('end',()=>{const code=res.statusCode||0;if(code>=300&&code<400&&res.headers.location)return fetchJson(res.headers.location).then(resolve,reject);if(code!==200)return reject(new Error('HTTP '+code));try{resolve(JSON.parse(d))}catch(e){reject(e)}})});req.on('error',reject);req.setTimeout(20000,()=>{req.destroy();reject(new Error('timeout'))})})}
ipcMain.handle('releases',async()=>{const list=await fetchJson('https://api.github.com/repos/broplaygame75-ai/prompt-picker-releases/releases?per_page=20');if(!Array.isArray(list))return [];return list.filter(r=>r&&!r.draft&&!r.prerelease).slice(0,20).map(r=>({version:String(r.tag_name||r.name||'').replace(/^v/i,''),body:String(r.body||''),published:r.published_at||''}))});
ipcMain.handle('quit',()=>{app.quit();return true});
function writeInstallMarker(installDir,dataPath){
  const body=JSON.stringify({appId:APP_ID,version:app.getVersion(),installDir:normalizeDataPath(installDir),dataPath:normalizeDataPath(dataPath)});
  try{fs.writeFileSync(path.join(installDir,MARKER_NAME),body);}catch(e){}
  try{
    const parent=path.join(app.getPath('appData'),'Prompt Picker');
    fs.mkdirSync(parent,{recursive:true});
    fs.writeFileSync(path.join(parent,MARKER_NAME),body);
  }catch(e){}
}
function rememberDataLocation(dir){
  const next=withActiveDataDir(cfg(),dir);
  try{if(JSON.stringify(cfg())!==JSON.stringify(next))writeAtomic(cfgPath(),JSON.stringify(next));}catch(e){}
  try{fs.writeFileSync(path.join(path.dirname(cfgPath()),'data.path'),next.activeDataDir+'\n');}catch(e){}
  if(process.platform!=='win32')return;
  const installDir=app.isPackaged?path.dirname(process.execPath):'';
  const installOk=!!(installDir&&fs.existsSync(installDir)&&fs.existsSync(process.execPath));
  if(installOk)writeInstallMarker(installDir,next.activeDataDir);
  for(const args of windowsRememberCommands(dir,installOk?installDir:''))execFile('reg',args,{windowsHide:true},()=>{});
}
function crashFile(){
  try{return path.join(app.getPath('userData'),'crash.log')}
  catch(e){return path.join(process.env.APPDATA||require('os').tmpdir(),'Prompt Picker','crash.log')}
}
function logCrash(kind,err){
  const text=err&&err.stack?err.stack:(typeof err==='string'?err:(()=>{try{return JSON.stringify(err)}catch(e){return String(err)}} )());
  const line=new Date().toISOString()+' '+kind+' '+text+'\n';
  try{const f=crashFile();fs.mkdirSync(path.dirname(f),{recursive:true});fs.appendFileSync(f,line);}catch(e){}
}
function downloadTo(url,dest,hops){
  return new Promise((resolve,reject)=>{
    if((hops||0)>5)return reject(new Error('redirect'));
    const req=https.get(url,{headers:{'User-Agent':'PromptPicker'}},res=>{
      const code=res.statusCode||0;
      if(code>=300&&code<400&&res.headers.location){res.resume();const next=new URL(res.headers.location,url).href;return downloadTo(next,dest,(hops||0)+1).then(resolve,reject)}
      if(code!==200){res.resume();return reject(new Error('HTTP '+code))}
      fs.mkdirSync(path.dirname(dest),{recursive:true});
      const file=fs.createWriteStream(dest);
      res.pipe(file);
      file.on('finish',()=>file.close(()=>resolve(dest)));
      file.on('error',reject);
    });
    req.on('error',reject);
    req.setTimeout(120000,()=>{req.destroy();reject(new Error('timeout'))});
  });
}
async function downloadAndLaunchInstaller(){
  const info=await fetchJson('https://api.github.com/repos/broplaygame75-ai/prompt-picker-releases/releases/latest');
  const version=versionFromRelease(info);
  const url=installerUrl(version);
  if(!version){await shell.openExternal(url);return}
  const dest=path.join(app.getPath('temp'),'PromptPicker-Setup-'+version+'.exe');
  await downloadTo(url,dest);
  const child=spawn(dest,[],{detached:true,stdio:'ignore'});
  child.unref();
}
let repairShown=false,repairQueued=false;
function offerRepair(err){
  logCrash('startup',err);
  repairQueued=true;
  if(!app.isReady()||repairShown)return;
  repairShown=true;
  repairQueued=false;
  const copy=startupCopy(uiLang());
  dialog.showMessageBox({type:'error',title:copy.repairTitle,message:copy.repairTitle,detail:copy.repairBody,buttons:[copy.repairBtn,copy.repairClose],defaultId:0,cancelId:1,noLink:true}).then(async r=>{
    if(r.response!==0){repairShown=false;if(!BrowserWindow.getAllWindows().some(w=>!w.isDestroyed()))app.quit();return}
    try{await downloadAndLaunchInstaller()}
    catch(e){logCrash('repair',e);try{await shell.openExternal(installerUrl(''))}catch(x){logCrash('repair-open',x)}}
    app.quit();
  }).catch(e=>{logCrash('repair-dialog',e);repairShown=false});
}
function repairShortcuts(){
  if(process.platform!=='win32'||!app.isPackaged)return;
  const locs=shortcutLocations(app.getPath('appData'),app.getPath('desktop'));
  for(const file of [locs.startMenu,locs.desktop]){
    let existing=null;
    const exists=fs.existsSync(file);
    if(exists){try{existing=shell.readShortcutLink(file)}catch(e){existing=null}}
    const plan=planShortcutRepair(existing,process.execPath,exists);
    if(!plan)continue;
    try{
      fs.mkdirSync(path.dirname(file),{recursive:true});
      const ok=shell.writeShortcutLink(file,plan.operation,plan.options);
      if(!ok)logCrash('shortcut','write failed '+file);
    }catch(e){logCrash('shortcut',e)}
  }
}
process.on('uncaughtException',err=>offerRepair(err));
process.on('unhandledRejection',err=>logCrash('unhandledRejection',err));
app.on('render-process-gone',(e,wc,details)=>{logCrash('render-process-gone',details);if(details&&details.reason!=='clean-exit')offerRepair(details)});
app.on('child-process-gone',(e,details)=>logCrash('child-process-gone',details));
app.whenReady().then(()=>{
  if(repairQueued)offerRepair('queued');
  try{rememberDataLocation(dataDir())}catch(e){logCrash('data',e)}
  try{repairShortcuts()}catch(e){logCrash('shortcut',e)}
  try{create()}catch(e){logCrash('window',e);offerRepair(e)}
  if(app.isPackaged){setTimeout(checkUpdates,5000);setInterval(checkUpdates,30*60*1000)}
}).catch(e=>{logCrash('ready',e);offerRepair(e)});
app.on('window-all-closed',()=>{if(!repairShown)app.quit()});
