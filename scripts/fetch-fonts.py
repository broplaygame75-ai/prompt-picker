#!/usr/bin/env python3
"""Download Lexend (Latin, including Vietnamese) and Noto Sans SC/KR subsets."""
import pathlib, urllib.parse, urllib.request
from fontTools.ttLib import TTFont
from fontTools.merge import Merger

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "src" / "fonts"
TTF = ROOT / "build" / "guide-fonts"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

def corpus():
    parts = [(ROOT / "src" / "index.html").read_text(), (ROOT / "README.md").read_text()]
    parts += [p.read_text() for p in (ROOT / "install-guide").glob("*.md")]
    parts += [p.read_text() for p in (ROOT / "release-notes").glob("*.md")]
    return "\n".join(parts)

def take(text, pred):
    chars = sorted({c for c in text if pred(c)})
    return "".join(chars)

def fetch_css(family, weight, text):
    url = (
        "https://fonts.googleapis.com/css2?family="
        + urllib.parse.quote(family)
        + f":wght@{weight}&display=swap&text="
        + urllib.parse.quote(text)
    )
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as res:
        css = res.read().decode("utf-8")
    urls = []
    for line in css.splitlines():
        if "url(" in line:
            urls.append(line.split("url(", 1)[1].split(")", 1)[0])
    if not urls:
        raise SystemExit("no font url for " + family + " " + str(weight))
    return urls

def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as res:
        dest.write_bytes(res.read())

def chunks(s, n):
    # Keep URL size modest.
    step = n
    for i in range(0, len(s), step):
        yield s[i:i + step]

def build(family, weight, text, dest_woff, dest_ttf):
    tmp = OUT / "_tmp"
    tmp.mkdir(exist_ok=True)
    files = []
    seen = set()
    piece = text if text else " "
    # ASCII plus the script, split so each request stays small.
    parts = list(chunks(piece, 120)) or [" "]
    for i, part in enumerate(parts):
        for url in fetch_css(family, weight, part):
            if url in seen:
                continue
            seen.add(url)
            raw = tmp / f"{family}-{weight}-{len(files)}.woff2"
            download(url, raw)
            files.append(raw)
            print(family, weight, "part", i, raw.stat().st_size)
    if len(files) == 1:
        ttf = files[0].with_suffix(".ttf")
        font = TTFont(files[0])
        font.flavor = None
        font.save(ttf)
        merged = ttf
    else:
        ttfs = []
        for f in files:
            ttf = f.with_suffix(".ttf")
            font = TTFont(f)
            font.flavor = None
            font.save(ttf)
            ttfs.append(str(ttf))
        merged = tmp / f"{family}-{weight}-merged.ttf"
        Merger().merge(ttfs).save(merged)
    TTF.mkdir(parents=True, exist_ok=True)
    final = TTFont(merged)
    final.flavor = None
    final.save(dest_ttf)
    woff = TTFont(merged)
    woff.flavor = "woff2"
    woff.save(dest_woff)
    print("wrote", dest_woff.name, dest_woff.stat().st_size)

def main():
    text = corpus()
    ascii_set = "".join(chr(i) for i in range(32, 127))
    cjk = take(text, lambda c: "\u3400" <= c <= "\u9fff" or "\u3000" <= c <= "\u303f" or "\uff00" <= c <= "\uffef")
    hang = take(text, lambda c: "\uac00" <= c <= "\ud7af" or "\u1100" <= c <= "\u11ff" or "\u3130" <= c <= "\u318f")
    viet_alpha = "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ"
    viet = "".join(sorted(set(take(text, lambda c: "\u00c0" <= c <= "\u024f" or c in "…—–“”‘’") + viet_alpha)))
    print("cjk", len(cjk), "hangul", len(hang), "latin-ext", len(viet))
    latin = ascii_set + viet
    build("Lexend", 400, latin, OUT / "Lexend-Regular.woff2", TTF / "Lexend-Regular.ttf")
    build("Lexend", 600, latin, OUT / "Lexend-SemiBold.woff2", TTF / "Lexend-SemiBold.ttf")
    build("Noto Sans SC", 400, ascii_set + cjk, OUT / "NotoSansSC-Regular.woff2", TTF / "NotoSansSC-Regular.ttf")
    build("Noto Sans SC", 600, ascii_set + cjk, OUT / "NotoSansSC-SemiBold.woff2", TTF / "NotoSansSC-SemiBold.ttf")
    build("Noto Sans KR", 400, ascii_set + hang, OUT / "NotoSansKR-Regular.woff2", TTF / "NotoSansKR-Regular.ttf")
    build("Noto Sans KR", 600, ascii_set + hang, OUT / "NotoSansKR-SemiBold.woff2", TTF / "NotoSansKR-SemiBold.ttf")
    # The app ships woff2. The ttf files are only for the illustration generator.
    import shutil
    shutil.rmtree(OUT / "_tmp", ignore_errors=True)
    print("done")

if __name__ == "__main__":
    main()
