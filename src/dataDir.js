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

module.exports={fixedDataDir,adoptExistingData};
