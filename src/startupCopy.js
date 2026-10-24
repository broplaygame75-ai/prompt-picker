const COPY = {
  en: {
    repairTitle: 'Prompt Picker needs a repair',
    repairBody: 'Prompt Picker hit a startup error. Repair downloads the latest installer and opens it. You do not need to find the program yourself.',
    repairBtn: 'Repair',
    repairClose: 'Close'
  },
  vi: {
    repairTitle: 'Prompt Picker cần được sửa',
    repairBody: 'Prompt Picker gặp lỗi khi mở. Sửa sẽ tải bộ cài mới nhất và mở nó. Bạn không cần tự tìm file chương trình.',
    repairBtn: 'Sửa',
    repairClose: 'Đóng'
  },
  zh: {
    repairTitle: 'Prompt Picker 需要修复',
    repairBody: 'Prompt Picker 启动时出错。修复会下载最新安装包并打开它。你不需要自己查找程序文件。',
    repairBtn: '修复',
    repairClose: '关闭'
  },
  ko: {
    repairTitle: 'Prompt Picker를 복구해야 합니다',
    repairBody: 'Prompt Picker가 시작 중 오류가 났습니다. 복구는 최신 설치 파일을 받아 엽니다. 프로그램 파일을 직접 찾을 필요가 없습니다.',
    repairBtn: '복구',
    repairClose: '닫기'
  }
};

function startupCopy(lang) {
  return COPY[lang] || COPY.en;
}

module.exports = {COPY, startupCopy};
