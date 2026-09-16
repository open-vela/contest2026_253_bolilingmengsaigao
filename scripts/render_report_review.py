"""Create a four-screen evidence figure and a contact sheet for report review."""
from pathlib import Path
import subprocess
import shutil
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 27)
names = [
    ("focusloop-goldfish-dashboard.png", "学习首页"),
    ("focusloop-goldfish-focus.png", "专注计时"),
    ("focusloop-goldfish-quiz.png", "三选一答题"),
    ("focusloop-goldfish-quiz-result.png", "结果与下一次复习"),
]
strip = Image.new("RGB", (1960, 540), "#f0f5f6")
draw = ImageDraw.Draw(strip)
for index, (name, caption) in enumerate(names):
    shot = Image.open(root / "docs/screenshots" / name).convert("RGB")
    shot.thumbnail((440, 440))
    strip.paste(shot, (index * 490 + 25, 20))
    draw.text((index * 490 + 245, 490), caption, font=font, fill="#163b48", anchor="mm")
strip.save(root / "docs/report/goldfish-flow.png")

if "--pdf" in __import__("sys").argv:
    out = root / "docs/report/rendered"
    out.mkdir(exist_ok=True)
    prefix = out / "template"
    subprocess.run([shutil.which("pdftoppm"), "-scale-to", "1000", "-png",
                    str(root / "docs/FocusLoop_Project_Report.pdf"), str(prefix)], check=True)
    from pypdf import PdfReader
    count = len(PdfReader(root / "docs/FocusLoop_Project_Report.pdf").pages)
    pages = sorted(out.glob("template-*.png"))[:count]
    contact = Image.new("RGB", (1200, ((len(pages)+2)//3)*570), "#d6dfe1")
    for i, p in enumerate(pages):
        im = Image.open(p).convert("RGB")
        im.thumbnail((380, 535))
        contact.paste(im, ((i % 3)*400 + 10, (i // 3)*570 + 10))
    contact.save(out / "contact.png")
    print(out / "contact.png")
