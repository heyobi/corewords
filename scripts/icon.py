# Draws the Corewords icon (1024x1024, no alpha) and copies it into the asset catalog (AppIcon + Logo).
# A fanned stack of three flash cards on an indigo-to-teal gradient; the front card shows "Aa" and a small
# frequency bar chart (the most common words first).
# Usage: python scripts/icon.py
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import json, os

S = 1024
img = Image.new('RGB', (S, S))
d = ImageDraw.Draw(img)
top, bottom = (67, 56, 202), (13, 148, 136)
for y in range(S):
    t = y / (S - 1)
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))

glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([180, 160, 860, 840], fill=(255, 255, 255, 50))
glow = glow.filter(ImageFilter.GaussianBlur(120))
img.paste(glow, (0, 0), glow)


def card(color, angle, dx, dy, shadow=True):
    w, h = 520, 640
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    cx, cy = S // 2 + dx, S // 2 + dy
    box = [cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2]
    if shadow:
        sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([box[0] + 10, box[1] + 26, box[2] + 10, box[3] + 26], 64, fill=(10, 20, 60, 110))
        sh = sh.filter(ImageFilter.GaussianBlur(26)).rotate(angle, center=(cx, cy), resample=Image.BICUBIC)
        layer.alpha_composite(sh)
    c = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle(box, 64, fill=color)
    c = c.rotate(angle, center=(cx, cy), resample=Image.BICUBIC)
    layer.alpha_composite(c)
    return layer, box


base_img = img.convert('RGBA')
for color, angle, dx, dy in [((94, 234, 212, 255), -14, -70, 30), ((165, 180, 252, 255), 9, 60, 10)]:
    layer, _ = card(color, angle, dx, dy)
    base_img.alpha_composite(layer)
layer, box = card((255, 255, 255, 255), 0, 0, -10)
base_img.alpha_composite(layer)
img = base_img.convert('RGB')
d = ImageDraw.Draw(img)

font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 300)
text = 'Aa'
tw = d.textlength(text, font=font)
d.text((S / 2 - tw / 2, box[1] + 40), text, font=font, fill=(67, 56, 202))

# frequency bars: tall to short, like a word-frequency curve
bars = [1.0, 0.62, 0.44, 0.33, 0.26, 0.21]
bw, gap = 50, 22
total = len(bars) * bw + (len(bars) - 1) * gap
x0 = S / 2 - total / 2
base_y = box[3] - 70
for i, v in enumerate(bars):
    hgt = 190 * v
    x = x0 + i * (bw + gap)
    col = (13, 148, 136) if i < 3 else (153, 246, 228)
    d.rounded_rectangle([x, base_y - hgt, x + bw, base_y], 14, fill=col)

os.makedirs('assets', exist_ok=True)
img.save('assets/icon-1024.png')
base = 'Corewords/Assets.xcassets'
os.makedirs(f'{base}/AppIcon.appiconset', exist_ok=True)
os.makedirs(f'{base}/Logo.imageset', exist_ok=True)
img.save(f'{base}/AppIcon.appiconset/icon-1024.png')
img.resize((256, 256), Image.LANCZOS).save(f'{base}/Logo.imageset/logo.png')
json.dump({'images': [{'filename': 'icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
           'info': {'author': 'xcode', 'version': 1}}, open(f'{base}/AppIcon.appiconset/Contents.json', 'w'), indent=2)
json.dump({'images': [{'filename': 'logo.png', 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}},
          open(f'{base}/Logo.imageset/Contents.json', 'w'), indent=2)
json.dump({'info': {'author': 'xcode', 'version': 1}}, open(f'{base}/Contents.json', 'w'), indent=2)
os.makedirs(f'{base}/AccentColor.colorset', exist_ok=True)
json.dump({'colors': [
    {'color': {'color-space': 'srgb', 'components': {'red': '0.310', 'green': '0.275', 'blue': '0.898', 'alpha': '1.000'}}, 'idiom': 'universal'},
    {'appearances': [{'appearance': 'luminosity', 'value': 'dark'}],
     'color': {'color-space': 'srgb', 'components': {'red': '0.506', 'green': '0.549', 'blue': '0.973', 'alpha': '1.000'}}, 'idiom': 'universal'}],
    'info': {'author': 'xcode', 'version': 1}}, open(f'{base}/AccentColor.colorset/Contents.json', 'w'), indent=2)
print('icon written')
