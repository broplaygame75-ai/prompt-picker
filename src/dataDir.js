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

module.exports={fixedDataDir,adoptExistingData,INSTALL_GUID,DATA_REG_KEY,INSTALL_REG_KEY,normalizeDataPath,withActiveDataDir,windowsRememberCommands};
