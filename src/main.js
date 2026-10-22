const {app,BrowserWindow,ipcMain,dialog,shell}=require('electron');
const path=require('path'),fs=require('fs');
const {autoUpdater}=require('electron-updater');
const cfgPath=()=>path.join(app.getPath('userData'),'config.json');
function cfg(){try{return JSON.parse(fs.readFileSync(cfgPath()))}catch(e){return{}}}
function dataDir(){const d=cfg().dataDir||path.join(app.getPath('userData'),'data');fs.mkdirSync(path.join(d,'images'),{recursive:true});return d;}
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
ipcMain.handle('dir-change',async()=>{const r=await dialog.showOpenDialog(win,{title:'Chọn thư mục dữ liệu',properties:['openDirectory','createDirectory']});if(r.canceled)return null;
  const old=dataDir(),nd=path.join(r.filePaths[0],'PromptPickerData');fs.mkdirSync(path.join(nd,'images'),{recursive:true});
  if(!fs.existsSync(path.join(nd,'prompts.json'))&&fs.existsSync(path.join(old,'prompts.json'))){fs.cpSync(old,nd,{recursive:true});}
  const c=cfg();c.dataDir=nd;fs.writeFileSync(cfgPath(),JSON.stringify(c));return nd;});
ipcMain.handle('save-file',async(e,name,text)=>{const r=await dialog.showSaveDialog(win,{defaultPath:name,filters:[{name:'JSON',extensions:['json']}]});if(r.canceled)return false;fs.writeFileSync(r.filePath,text);return true});
// updates
autoUpdater.autoDownload=false;
const send=(...a)=>win&&win.webContents.send('upd',...a);
autoUpdater.on('update-available',i=>send('available',{version:i.version,notes:typeof i.releaseNotes==='string'?i.releaseNotes:(i.releaseNotes||[]).map(n=>n.note).join('\n')}));
autoUpdater.on('update-not-available',()=>send('none'));
autoUpdater.on('download-progress',p=>send('progress',p.percent));
autoUpdater.on('update-downloaded',()=>autoUpdater.quitAndInstall(false,true));
autoUpdater.on('error',e=>send('error',String(e&&e.message||e)));
ipcMain.handle('upd-check',()=>app.isPackaged?autoUpdater.checkForUpdates().then(()=>true).catch(e=>{send('error',String(e.message));return false}):(send('error','Bản chạy thử (chưa cài) không kiểm tra cập nhật'),false));
ipcMain.handle('upd-download',()=>autoUpdater.downloadUpdate());
app.whenReady().then(()=>{create();if(app.isPackaged){setTimeout(()=>autoUpdater.checkForUpdates().catch(()=>{}),5000);setInterval(()=>autoUpdater.checkForUpdates().catch(()=>{}),4*36e5);}});
app.on('window-all-closed',()=>app.quit());
