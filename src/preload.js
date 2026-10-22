const {contextBridge,ipcRenderer}=require('electron');
const i=(c)=>(...a)=>ipcRenderer.invoke(c,...a);
contextBridge.exposeInMainWorld('api',{version:i('version'),load:i('load'),save:i('save'),imgSave:i('img-save'),imgRead:i('img-read'),imgDel:i('img-del'),dirGet:i('dir-get'),dirOpen:i('dir-open'),dirChange:i('dir-change'),saveFile:i('save-file'),updCheck:i('upd-check'),updDownload:i('upd-download'),onUpd:f=>ipcRenderer.on('upd',(e,...a)=>f(...a))});
