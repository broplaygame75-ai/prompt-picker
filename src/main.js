const {app,BrowserWindow,ipcMain,dialog,shell}=require('electron');
const path=require('path'),fs=require('fs');
const {autoUpdater}=require('electron-updater');
const {fixedDataDir,adoptExistingData}=require('./dataDir');
const cfgPath=()=>path.join(app.getPath('userData'),'config.json');
function cfg(){try{return JSON.parse(fs.readFileSync(cfgPath()))}catch(e){return{}}}
function dataSources(){const sources=[];try{const userData=app.getPath('userData');sources.push(path.join(userData,'data'));const custom=cfg().dataDir;if(typeof custom==='string'&&custom.trim())sources.push(custom.trim())}catch(e){}return sources}
function dataDir(){return adoptExistingData(fixedDataDir(app.getPath('appData')),dataSources())}
const dataFile=()=>path.join(dataDir(),'prompts.json');
function writeAtomic(f,s){fs.writeFileSync(f+'.tmp',s);fs.renameSync(f+'.tmp',f);}
let win;
function create(){win=new BrowserWindow({width:1500,height:950,minWidth:1000,backgroundColor:'#0f0d14',title:'Prompt Picker',icon:path.join(__dirname,'../build/icon.png'),autoHideMenuBar:true,webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true}});win.loadFile(path.join(__dirname,'index.html'));}
ipcMain.handle('version',()=>app.getVersion());
ipcMain.handle('load',()=>{try{return JSON.parse(fs.readFileSync(dataFile(),'utf8'))}catch(e){return null}});
ipcMain.handle('save',(e,s)=>{writeAtomic(dataFile(),s);return true});
ipcMain.handle('img-save',(e,id,dataUrl)=>{const b=Buffer.from(dataUrl.split(',')[1],'base64');fs.writeFileSync(path.join(dataDir(),'images',id+'.webp'),b);return true});
ipcMain.handle('img-read',(e,id)=>{try{return 'data:image/webp;base64,'+fs.readFileSync(path.join(dataDir(),'images',id+'.webp')).toString('base64')}catch(x){return null}});
ipcMain.handle('img-del',(e,id)=>{try{fs.unlinkSync(path.join(dataDir(),'images',id+'.webp'))}catch(x){}return true});
ipcMain.handle('dir-get',()=>dataDir());
ipcMain.handle('dir-open',()=>shell.openPath(dataDir()));
function uiLang(){try{const s=JSON.parse(fs.readFileSync(dataFile(),'utf8'));return s.lang==='en'?'en':'vi'}catch(e){return 'vi'}}
ipcMain.handle('dir-change',()=>dataDir());
ipcMain.handle('save-file',async(e,name,text,title)=>{const fallback=uiLang()==='en'?'Save backup':'Lưu file sao lưu';const r=await dialog.showSaveDialog(win,{title:typeof title==='string'&&title.trim()?title.trim():fallback,defaultPath:name,filters:[{name:'JSON',extensions:['json']}]});if(r.canceled)return false;fs.writeFileSync(r.filePath,text);return true});
// updates
autoUpdater.autoDownload=false;
autoUpdater.autoInstallOnAppQuit=false;
function parseVer(v){return String(v||'').replace(/^v/i,'').split('.').map(n=>parseInt(n,10)||0)}
function isNewerVersion(next,current){const a=parseVer(next),b=parseVer(current),n=Math.max(a.length,b.length);for(let i=0;i<n;i++){const d=(a[i]||0)-(b[i]||0);if(d)return d>0}return false}
const send=msg=>{if(win&&!win.isDestroyed())win.webContents.send('upd',msg)};
autoUpdater.on('update-available',i=>{const version=i&&i.version;if(!version||!isNewerVersion(version,app.getVersion()))return;send({type:'available',version})});
autoUpdater.on('update-not-available',()=>send({type:'none'}));
autoUpdater.on('download-progress',p=>send({type:'progress',percent:p&&p.percent||0}));
autoUpdater.on('update-downloaded',()=>{send({type:'progress',percent:100});if(app.isPackaged)autoUpdater.installDirectory=path.dirname(process.execPath);autoUpdater.quitAndInstall(true,true)});
autoUpdater.on('error',e=>send({type:'error',message:String(e&&e.message||e)}));
ipcMain.handle('upd-check',()=>app.isPackaged?autoUpdater.checkForUpdates().then(()=>true).catch(e=>{send({type:'error',message:String(e.message)});return false}):(send({type:'error',code:'unpackaged-check'}),false));
ipcMain.handle('upd-download',async()=>{if(!app.isPackaged){send({type:'error',code:'unpackaged-download'});return false}try{await autoUpdater.downloadUpdate();return true}catch(e){send({type:'error',message:String(e&&e.message||e)});return false}});
app.whenReady().then(()=>{if(app.isPackaged)autoUpdater.installDirectory=path.dirname(process.execPath);create();if(app.isPackaged){setTimeout(()=>autoUpdater.checkForUpdates().catch(()=>{}),5000);setInterval(()=>autoUpdater.checkForUpdates().catch(()=>{}),4*36e5);}});
app.on('window-all-closed',()=>app.quit());
