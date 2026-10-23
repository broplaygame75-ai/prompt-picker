const path=require('path');
const fs=require('fs');

// Fixed store: %APPDATA%\Prompt Picker\data on Windows. Reuse it when it
// already has prompts; otherwise create it. Never delete a source folder.
function fixedDataDir(appData){return path.join(appData,'Prompt Picker','data');}

function adoptExistingData(dest,sources){
  const images=path.join(dest,'images');
  fs.mkdirSync(images,{recursive:true});
  if(fs.existsSync(path.join(dest,'prompts.json')))return dest;
  const seen=new Set();
  const destAbs=path.resolve(dest);
  for(const src of sources||[]){
    if(!src||typeof src!=='string')continue;
    const abs=path.resolve(src);
    if(abs===destAbs||seen.has(abs))continue;
    seen.add(abs);
    if(!fs.existsSync(path.join(src,'prompts.json')))continue;
    fs.cpSync(src,dest,{recursive:true,force:false});
    break;
  }
  fs.mkdirSync(images,{recursive:true});
  return dest;
}

// electron-builder's per-user install key: UUID v5 of appId com.lineko.promptpicker.
const INSTALL_GUID='05ae8bdf-b478-52b5-acc4-ac809166ef4d';
const DATA_REG_KEY='HKCU\\Software\\Prompt Picker';
const INSTALL_REG_KEY='HKCU\\Software\\'+INSTALL_GUID;
const APP_ID='com.lineko.promptpicker';
const MARKER_NAME='prompt-picker.install.json';

function normalizeDataPath(dir){
  const s=String(dir||'').trim();
  if(/^[A-Za-z]:[\\/]/.test(s)||s.startsWith('\\\\'))return s.replace(/\//g,'\\').replace(/\\+$/,'');
  return path.resolve(s);
}

function withActiveDataDir(config,dir){
  const rest=Object.assign({},config||{});
  delete rest.activeDataDir;
  return Object.assign({activeDataDir:normalizeDataPath(dir)},rest);
}

function markerFromText(text){
  try{
    const j=JSON.parse(String(text||''));
    if(!j||j.appId!==APP_ID)return null;
    const installDir=typeof j.installDir==='string'?normalizeDataPath(j.installDir):'';
    if(!installDir)return null;
    const dataPath=typeof j.dataPath==='string'&&j.dataPath.trim()?normalizeDataPath(j.dataPath):'';
    return {appId:APP_ID,version:String(j.version||''),installDir,dataPath};
  }catch(e){return null;}
}

function isWinPath(s){return /^[A-Za-z]:[\\/]/.test(s)||String(s||'').startsWith('\\\\');}

function joinDir(base,name){
  if(isWinPath(base))return String(base).replace(/[\\/]+$/,'')+'\\'+name;
  return path.join(base,name);
}

function sameDir(a,b){
  if(!a||!b)return false;
  const na=normalizeDataPath(a),nb=normalizeDataPath(b);
  if(isWinPath(na)||isWinPath(nb))return na.toLowerCase()===nb.toLowerCase();
  return na===nb;
}

// Data folders to adopt only when this executable is running inside the
// verified install folder. A marker for some other folder is ignored.
function sourcesFromMarker(marker,exeDir){
  if(!marker||!exeDir||!sameDir(marker.installDir,exeDir))return [];
  const sources=[];
  if(marker.dataPath)sources.push(marker.dataPath);
  sources.push(joinDir(marker.installDir,'PromptPickerData'));
  sources.push(joinDir(marker.installDir,'data'));
  return sources;
}

function reuseSources(exeDir,pointerText,installMarkerText){
  const sources=[],seen=new Set();
  for(const marker of [markerFromText(installMarkerText),markerFromText(pointerText)]){
    for(const s of sourcesFromMarker(marker,exeDir)){
      const key=s.toLowerCase();
      if(seen.has(key))continue;
      seen.add(key);
      sources.push(s);
    }
  }
  return sources;
}

function windowsRememberCommands(dir,installDir){
  const data=normalizeDataPath(dir);
  const cmds=[
    ['add',DATA_REG_KEY,'/v','DataDir','/t','REG_SZ','/d',data,'/f'],
    ['add',INSTALL_REG_KEY,'/v','DataDir','/t','REG_SZ','/d',data,'/f']
  ];
  if(installDir){
    const loc=normalizeDataPath(installDir);
    cmds.push(['add',DATA_REG_KEY,'/v','InstallLocation','/t','REG_SZ','/d',loc,'/f']);
    cmds.push(['add',INSTALL_REG_KEY,'/v','InstallLocation','/t','REG_SZ','/d',loc,'/f']);
  }
  return cmds;
}

module.exports={fixedDataDir,adoptExistingData,INSTALL_GUID,DATA_REG_KEY,INSTALL_REG_KEY,APP_ID,MARKER_NAME,normalizeDataPath,withActiveDataDir,windowsRememberCommands,markerFromText,sourcesFromMarker,reuseSources};
