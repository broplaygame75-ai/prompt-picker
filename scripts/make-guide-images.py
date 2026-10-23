#!/usr/bin/env python3
"""Draw illustrative install-guide pictures. They are not screenshots."""
import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
GUIDE = ROOT / "install-guide"
W, H = 1100, 680

FONTS = {
    "en": ("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf", "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"),
    "vi": (str(ROOT / "build/guide-fonts/Lexend-Regular.ttf"), str(ROOT / "build/guide-fonts/Lexend-SemiBold.ttf")),
    "zh": (str(ROOT / "build/guide-fonts/NotoSansSC-Regular.ttf"), str(ROOT / "build/guide-fonts/NotoSansSC-SemiBold.ttf")),
    "ko": (str(ROOT / "build/guide-fonts/NotoSansKR-Regular.ttf"), str(ROOT / "build/guide-fonts/NotoSansKR-SemiBold.ttf")),
}

COPY = {
    "en": {
        "ribbon": "Illustration",
        "download_title": "1. Download",
        "download_body": "On the releases page, download the Setup file or the Windows zip.",
        "file": "PromptPicker-Setup.exe",
        "download": "Download",
        "ss_title": "Windows protected your PC",
        "ss_body": "Microsoft Defender SmartScreen prevented an unrecognized app from starting. Running this app might put your PC at risk.",
        "ss_app": "App: PromptPicker-Setup.exe",
        "ss_pub": "Publisher: Unknown publisher",
        "dont": "Don't run",
        "more": "More info",
        "anyway": "Run anyway",
        "ss_note": "2. Click More info, then Run anyway. The app is unsigned.",
        "setup": "Prompt Picker Setup",
        "welcome": "This installs Prompt Picker over the current copy.",
        "keep": "Prompts already on this PC are kept.",
        "install": "Install",
        "inst_note": "3. Install",
        "age": "Are you 18 or older?",
        "yes": "Yes",
        "no": "No",
        "first": "4. First launch",
        "app": "Prompt Picker",
    },
    "vi": {
        "ribbon": "Minh hoạ",
        "download_title": "1. Tải về",
        "download_body": "Ở trang releases, tải file Setup hoặc gói zip Windows.",
        "file": "PromptPicker-Setup.exe",
        "download": "Tải về",
        "ss_title": "Windows đã bảo vệ PC của bạn",
        "ss_body": "Microsoft Defender SmartScreen đã chặn một ứng dụng chưa được nhận diện. Chạy ứng dụng này có thể gây rủi ro cho PC.",
        "ss_app": "Ứng dụng: PromptPicker-Setup.exe",
        "ss_pub": "Nhà phát hành: Không rõ",
        "dont": "Không chạy",
        "more": "Thông tin thêm",
        "anyway": "Vẫn chạy",
        "ss_note": "2. Bấm Thông tin thêm, rồi Vẫn chạy. App chưa ký số.",
        "setup": "Cài đặt Prompt Picker",
        "welcome": "Bộ cài ghi đè bản Prompt Picker đang có.",
        "keep": "Prompt đã có trên máy được giữ nguyên.",
        "install": "Cài đặt",
        "inst_note": "3. Cài đặt",
        "age": "Bạn đã đủ 18 tuổi chưa?",
        "yes": "Có",
        "no": "Không",
        "first": "4. Mở lần đầu",
        "app": "Prompt Picker",
    },
    "zh": {
        "ribbon": "示意图",
        "download_title": "1. 下载",
        "download_body": "在发布页下载安装程序，或下载 Windows 压缩包。",
        "file": "PromptPicker-Setup.exe",
        "download": "下载",
        "ss_title": "Windows 已保护你的电脑",
        "ss_body": "Microsoft Defender SmartScreen 已阻止一个无法识别的应用启动。运行此应用可能会让电脑面临风险。",
        "ss_app": "应用：PromptPicker-Setup.exe",
        "ss_pub": "发布者：未知发布者",
        "dont": "不运行",
        "more": "更多信息",
        "anyway": "仍要运行",
        "ss_note": "2. 点击更多信息，然后仍要运行。应用未签名。",
        "setup": "Prompt Picker 安装",
        "welcome": "这将覆盖当前的 Prompt Picker。",
        "keep": "这台电脑上的提示词会保留。",
        "install": "安装",
        "inst_note": "3. 安装",
        "age": "你已年满 18 岁吗？",
        "yes": "是",
        "no": "否",
        "first": "4. 第一次打开",
        "app": "Prompt Picker",
    },
    "ko": {
        "ribbon": "예시",
        "download_title": "1. 다운로드",
        "download_body": "릴리스 페이지에서 설치 파일 또는 Windows zip을 받습니다.",
        "file": "PromptPicker-Setup.exe",
        "download": "다운로드",
        "ss_title": "Windows가 PC를 보호했습니다",
        "ss_body": "Microsoft Defender SmartScreen이 인식되지 않은 앱의 시작을 막았습니다. 이 앱을 실행하면 PC가 위험해질 수 있습니다.",
        "ss_app": "앱: PromptPicker-Setup.exe",
        "ss_pub": "게시자: 알 수 없는 게시자",
        "dont": "실행 안 함",
        "more": "추가 정보",
        "anyway": "실행",
        "ss_note": "2. 추가 정보를 누른 다음 실행을 누릅니다. 앱은 서명되지 않았습니다.",
        "setup": "Prompt Picker 설치",
        "welcome": "현재 Prompt Picker 위에 설치합니다.",
        "keep": "이 PC의 프롬프트는 그대로 둡니다.",
        "install": "설치",
        "inst_note": "3. 설치",
        "age": "18세 이상입니까?",
        "yes": "예",
        "no": "아니오",
        "first": "4. 처음 실행",
        "app": "Prompt Picker",
    },
}

def font(lang, bold, size):
    path = FONTS[lang][1 if bold else 0]
    return ImageFont.truetype(path, size)

def wrap(draw, text, fnt, width):
    lines = []
    for para in text.split("\n"):
        tokens = []
        buf = ""
        for ch in para:
            if ch == " ":
                if buf:
                    tokens.append(buf)
                    buf = ""
                tokens.append(" ")
            elif ord(ch) > 127:
                if buf:
                    tokens.append(buf)
                    buf = ""
                tokens.append(ch)
            else:
                buf += ch
        if buf:
            tokens.append(buf)
        cur = ""
        for token in tokens:
            trial = cur + token
            if not cur or draw.textlength(trial, font=fnt) <= width:
                cur = trial
            else:
                if cur.strip():
                    lines.append(cur.rstrip())
                cur = "" if token == " " else token
        if cur.strip():
            lines.append(cur.rstrip())
    return lines

def base(lang, title):
    im = Image.new("RGB", (W, H), "#241c30")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((36, 36, W - 36, H - 36), 22, fill="#f6f1e8")
    d.rounded_rectangle((36, 36, W - 36, 92), 22, fill="#2a2236")
    d.rectangle((36, 70, W - 36, 92), fill="#2a2236")
    d.text((58, 48), title, font=font(lang, True, 26), fill="#f6f1e8")
    ribbon = COPY[lang]["ribbon"]
    rf = font(lang, True, 16)
    rw = d.textlength(ribbon, font=rf) + 28
    d.rounded_rectangle((W - 56 - rw, 48, W - 56, 78), 8, fill="#e2648f")
    d.text((W - 42 - rw, 52), ribbon, font=rf, fill="#fff")
    return im, d

def button(d, box, label, lang, on):
    fill = "#e2648f" if on else "#e7e0d6"
    ink = "#fff" if on else "#2a2236"
    d.rounded_rectangle(box, 10, fill=fill, outline="#2a2236", width=2)
    f = font(lang, True, 20)
    tw = d.textlength(label, font=f)
    x = box[0] + (box[2] - box[0] - tw) / 2
    d.text((x, box[1] + 12), label, font=f, fill=ink)

def draw_download(lang):
    c = COPY[lang]
    im, d = base(lang, c["download_title"])
    y = 120
    for line in wrap(d, c["download_body"], font(lang, False, 24), 900):
        d.text((70, y), line, font=font(lang, False, 24), fill="#2a2236")
        y += 36
    d.rounded_rectangle((70, y + 24, 1030, y + 110), 12, fill="#fff", outline="#c9bfb2", width=2)
    d.text((92, y + 50), c["file"], font=font(lang, True, 26), fill="#2a2236")
    button(d, (760, y + 40, 990, y + 94), c["download"], lang, True)
    im.save(GUIDE / lang / "01-download.png")

def draw_smart(lang):
    c = COPY[lang]
    im, d = base(lang, c["ss_note"])
    d.rounded_rectangle((90, 130, 1010, 560), 16, fill="#fff", outline="#d0d5dd", width=2)
    d.rectangle((90, 130, 1010, 188), fill="#0078d4")
    d.text((114, 146), c["ss_title"], font=font(lang, True, 22), fill="#fff")
    y = 210
    for line in wrap(d, c["ss_body"], font(lang, False, 20), 860):
        d.text((114, y), line, font=font(lang, False, 20), fill="#201a28")
        y += 30
    d.text((114, y + 8), c["ss_app"], font=font(lang, False, 18), fill="#5c6570")
    d.text((114, y + 36), c["ss_pub"], font=font(lang, False, 18), fill="#5c6570")
    button(d, (114, 470, 320, 522), c["dont"], lang, False)
    button(d, (340, 470, 560, 522), c["more"], lang, True)
    button(d, (700, 470, 960, 522), c["anyway"], lang, True)
    im.save(GUIDE / lang / "02-smartscreen.png")

def draw_install(lang):
    c = COPY[lang]
    im, d = base(lang, c["inst_note"])
    d.text((80, 130), c["setup"], font=font(lang, True, 32), fill="#2a2236")
    y = 190
    for line in wrap(d, c["welcome"], font(lang, False, 24), 900):
        d.text((80, y), line, font=font(lang, False, 24), fill="#2a2236")
        y += 36
    for line in wrap(d, c["keep"], font(lang, False, 24), 900):
        d.text((80, y), line, font=font(lang, False, 24), fill="#2a2236")
        y += 36
    button(d, (80, 470, 320, 530), c["install"], lang, True)
    im.save(GUIDE / lang / "03-installer.png")

def draw_first(lang):
    c = COPY[lang]
    im, d = base(lang, c["first"])
    d.rounded_rectangle((220, 160, 880, 430), 18, fill="#fff", outline="#e2648f", width=3)
    question = c["age"]
    qf = font(lang, True, 28)
    qw = d.textlength(question, font=qf)
    d.text(((W - qw) / 2, 210), question, font=qf, fill="#2a2236")
    button(d, (300, 300, 500, 360), c["yes"], lang, True)
    button(d, (540, 300, 740, 360), c["no"], lang, False)
    d.rounded_rectangle((220, 470, 880, 560), 12, fill="#2a2236")
    d.text((246, 498), "✦  " + c["app"], font=font(lang, True, 24), fill="#f6f1e8")
    im.save(GUIDE / lang / "04-first-launch.png")

def main():
    for lang in COPY:
        (GUIDE / lang).mkdir(parents=True, exist_ok=True)
        draw_download(lang)
        draw_smart(lang)
        draw_install(lang)
        draw_first(lang)
        print(lang, "ok")

if __name__ == "__main__":
    main()
