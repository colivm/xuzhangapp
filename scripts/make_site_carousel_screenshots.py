"""Prepare website carousel and App Store preview screenshots.

Source captures live outside the repo at ``E:\\叙账截图``. Only the slides
the user ordered are processed; unused originals in that folder are left
untouched. The system status strip and Dynamic Island are filled with the
app background so the UI stays pixel-for-pixel. Outputs are 6.7-inch
``1290×2796`` RGB PNGs (website + App Store) and a 6.5-inch
``1284×2778`` set for later App Store Connect upload.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"E:\叙账截图")
SITE = ROOT / "site" / "screenshots"
OUT = ROOT / "output" / "app-store-screenshots-v5"
UPLOAD = OUT / "upload-ready"
UPLOAD_65 = OUT / "upload-ready-6.5-inch"
PREVIEW = OUT / "preview-contact-sheet.png"
WIDTH, HEIGHT = 1290, 2796
SIZE_65 = (1284, 2778)
STATUS_H = 154
BAND_H = 18
FONT_BOLD = "C:/Windows/Fonts/msyhbd.ttc"

# User-specified carousel order. Chat duplicates of 127/128 are collapsed.
# Unused originals in the source folder are intentionally omitted.
SLIDES = (
    ("微信图片_20260902142214_56_2.png", "01-home-empty.png", "今日空态"),
    ("微信图片_20260902142214_58_2.png", "02-record-amount.png", "先记金额"),
    ("微信图片_20260910104111_125_2.png", "03-record-preview.png", "确认入账"),
    ("微信图片_20260902142214_57_2.png", "04-home-first.png", "第一笔记录"),
    ("微信图片_20260910104107_124_2.png", "05-home-today.png", "今日多笔"),
    ("微信图片_20260910104123_127_2.png", "06-scene-packs.png", "换个角度"),
    ("微信图片_20260910104127_128_2.png", "07-trace-week.png", "本周痕迹"),
    ("微信图片_20260910104133_129_2.png", "08-review.png", "复盘"),
    ("微信图片_20260910104230_132_2.png", "09-clues.png", "生活线索"),
    ("微信图片_20260910104134_130_2.png", "10-ai-console.png", "AI 指令台"),
    ("微信图片_20260910104227_131_2.png", "11-me.png", "我的"),
    ("微信图片_20260910104232_133_2.png", "12-appearance.png", "外观"),
)

STALE_SITE_NAMES = (
    "01-stats-slice.png",
    "02-week-playback.png",
    "03-life-mix.png",
    "04-today-playback.png",
)


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD, size)


def clean_rgb(image: Image.Image) -> Image.Image:
    output = Image.new("RGB", image.size)
    output.paste(image.convert("RGB"))
    output.info.clear()
    return output


def remove_status_bar(image: Image.Image) -> Image.Image:
    image = clean_rgb(image)
    if image.size != (WIDTH, HEIGHT):
        image = image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    band = image.crop((0, STATUS_H, WIDTH, STATUS_H + BAND_H)).resize(
        (WIDTH, STATUS_H), Image.Resampling.BILINEAR
    )
    image.paste(band, (0, 0))
    return image


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clean_rgb(image).save(path, format="PNG", optimize=True)


def make_contact_sheet(paths: list[Path]) -> None:
    thumb_w, thumb_h = 322, 698
    margin, label_h = 20, 52
    cols = 4
    rows = (len(paths) + cols - 1) // cols
    canvas = Image.new(
        "RGB",
        (thumb_w * cols + margin * (cols + 1), (thumb_h + label_h) * rows + margin * (rows + 1)),
        (238, 240, 244),
    )
    draw = ImageDraw.Draw(canvas)
    label_font = font(22)
    for index, path in enumerate(paths):
        image = Image.open(path).convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        col, row = index % cols, index // cols
        x = margin + col * (thumb_w + margin)
        y = margin + row * (thumb_h + label_h + margin)
        canvas.paste(image, (x, y))
        draw.text((x, y + thumb_h + 12), path.stem, font=label_font, fill=(37, 48, 65))
    save_png(canvas, PREVIEW)


def assert_status_bar_gone(image: Image.Image, name: str) -> None:
    center = image.getpixel((WIDTH // 2, 90))
    if center[0] < 40 and center[1] < 40 and center[2] < 40:
        raise RuntimeError(f"Dynamic Island still visible in {name}")


def main() -> None:
    SITE.mkdir(parents=True, exist_ok=True)
    UPLOAD.mkdir(parents=True, exist_ok=True)
    UPLOAD_65.mkdir(parents=True, exist_ok=True)

    for stale in STALE_SITE_NAMES:
        path = SITE / stale
        if path.exists():
            path.unlink()

    site_paths: list[Path] = []
    for source_name, output_name, _label in SLIDES:
        source = SOURCE / source_name
        if not source.is_file():
            raise FileNotFoundError(source)
        image = remove_status_bar(Image.open(source))
        assert_status_bar_gone(image, output_name)
        site_path = SITE / output_name
        upload_path = UPLOAD / output_name
        save_png(image, site_path)
        save_png(image, upload_path)
        save_png(image.resize(SIZE_65, Image.Resampling.LANCZOS), UPLOAD_65 / output_name)
        site_paths.append(site_path)
        print(f"{output_name}: {image.size[0]}x{image.size[1]} from {source_name}")

    make_contact_sheet(site_paths)
    print(f"Preview: {PREVIEW}")


if __name__ == "__main__":
    main()
