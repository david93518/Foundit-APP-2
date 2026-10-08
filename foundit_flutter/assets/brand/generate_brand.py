"""Rebuild FOUND !T vector masters and launcher assets without font dependencies."""
from pathlib import Path
import json
import math
import re
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'brand'
INK = '#282B30'
ORANGE = '#C64B30'
ACCENT = '#EF7958'
CREAM = '#FCFAF7'
PEACH = '#FFF1E8'

# Original outlined geometry: chamfered O and D echo the discovery corners.
GLYPHS = [
    (37, [[(0,0),(11,0),(11,3),(3.3,3),(3.3,7),(10,7),(10,10),(3.3,10),(3.3,16),(0,16)]]),
    (51, [[(3,0),(10,0),(13,3),(13,13),(10,16),(3,16),(0,13),(0,3)],
          [(4.3,3),(8.7,3),(9.7,4),(9.7,12),(8.7,13),(4.3,13),(3.3,12),(3.3,4)]]),
    (67, [[(0,0),(3.3,0),(3.3,11.8),(4.6,13),(8.4,13),(9.7,11.8),(9.7,0),(13,0),(13,13.1),(10.2,16),(2.8,16),(0,13.1)]]),
    (83, [[(0,16),(0,0),(3.1,0),(10,10.7),(10,0),(13.2,0),(13.2,16),(10.1,16),(3.2,5.3),(3.2,16)]]),
    (99, [[(0,0),(8.7,0),(13,4.3),(13,11.7),(8.7,16),(0,16)],
          [(3.3,3.1),(7.3,3.1),(9.7,5.5),(9.7,10.5),(7.3,12.9),(3.3,12.9)]]),
    (125, [[(0,0),(13,0),(13,3.2),(8.2,3.2),(8.2,16),(4.8,16),(4.8,3.2),(0,3.2)]]),
]

def polygon_path(points, x=0, y=0):
    values = [f'{px+x:g} {py+y:g}' for px, py in points]
    return 'M' + 'L'.join(values) + 'Z'

def symbol_svg(ink=INK, accent=ORANGE):
    return f'<path d="M12 4H4V12M20 28H28V20" fill="none" stroke="{ink}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.5 5.5H18.5L17.8 19H14.2Z" fill="{accent}"/><circle cx="16" cy="24" r="2.5" fill="{accent}"/>'

def letters_svg(ink=INK, accent=ORANGE):
    paths = []
    for x, contours in GLYPHS:
        d = ''.join(polygon_path(points, x, 8) for points in contours)
        paths.append(f'<path d="{d}" fill="{ink}" fill-rule="evenodd"/>')
    paths.append(f'<path d="M117 8H121L120.5 19H117.5Z" fill="{accent}"/><circle cx="119" cy="22.4" r="1.9" fill="{accent}"/>')
    return ''.join(paths)

def svg(body, view='0 0 142 32', title='FOUND !T'):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" role="img" aria-label="FOUND IT"><title>{title}</title>{body}</svg>\n'

def write(name, content):
    (OUT / name).write_text(content, encoding='utf-8')

for mode, ink, accent in [('light', INK, ORANGE), ('dark', CREAM, ACCENT)]:
    write(f'found-it-lockup-{mode}.svg', svg(symbol_svg(ink, accent) + letters_svg(ink, accent)))
    write(f'found-it-wordmark-{mode}.svg', svg(letters_svg(ink, accent), '34 0 108 32'))
    write(f'found-it-symbol-{mode}.svg', svg(symbol_svg(ink, accent), '0 0 32 32'))
    background = CREAM if mode == 'light' else INK
    body = f'<rect width="128" height="128" fill="{background}"/><g transform="translate(24 24) scale(2.5)">{symbol_svg(ink, accent)}</g>'
    write(f'found-it-app-icon-{mode}.svg', svg(body, '0 0 128 128'))

# Pillow rasterizes the exact vector coordinates at 4x, then Lanczos downsamples.
def draw_symbol(draw, transform, ink, accent):
    def xy(point):
        return transform(point)
    scale = xy((1,0))[0] - xy((0,0))[0]
    width = 3.2 * scale
    for points in [[(12,4),(4,4),(4,12)], [(20,28),(28,28),(28,20)]]:
        draw.line([xy(p) for p in points], fill=ink, width=round(width), joint='curve')
        for point in points:
            x,y=xy(point)
            draw.ellipse((x-width/2,y-width/2,x+width/2,y+width/2),fill=ink)
    draw.polygon([xy(p) for p in [(13.5,5.5),(18.5,5.5),(17.8,19),(14.2,19)]], fill=accent)
    x,y=xy((16,24)); r=2.5*scale
    draw.ellipse((x-r,y-r,x+r,y+r), fill=accent)

def app_icon(size, dark=True, symbol_scale=2.5):
    scale = size * 4 / 128
    background, ink, accent = (INK, CREAM, ACCENT) if dark else (CREAM, INK, ORANGE)
    image = Image.new('RGB', (size*4,size*4), background)
    offset = 64 - 16 * symbol_scale
    draw_symbol(ImageDraw.Draw(image), lambda p: ((offset+p[0]*symbol_scale)*scale,(offset+p[1]*symbol_scale)*scale), ink, accent)
    return image.resize((size,size), Image.Resampling.LANCZOS)

def lockup_png(scale=6, dark=False):
    background,ink,accent = (INK,CREAM,ACCENT) if dark else (CREAM,INK,ORANGE)
    image=Image.new('RGB',(142*scale,32*scale), background)
    draw=ImageDraw.Draw(image)
    draw_symbol(draw, lambda p: (p[0]*scale,p[1]*scale), ink,accent)
    for x,contours in GLYPHS:
        for i,points in enumerate(contours):
            draw.polygon([((px+x)*scale,(py+8)*scale) for px,py in points], fill=ink if i==0 else background)
    draw.polygon([(117*scale,8*scale),(121*scale,8*scale),(120.5*scale,19*scale),(117.5*scale,19*scale)],fill=accent)
    x,y,r=119*scale,22.4*scale,1.9*scale
    draw.ellipse((x-r,y-r,x+r,y+r),fill=accent)
    return image

for dark in (False, True):
    mode='dark' if dark else 'light'
    app_icon(1024,dark).save(OUT/f'found-it-app-icon-{mode}-1024.png')
    lockup_png(dark=dark).save(OUT/f'found-it-lockup-{mode}-preview.png')

# Existing public web filenames and native icon catalogs remain stable.
web=ROOT/'web'
for filename, size in [('Icon-192.png',192),('Icon-512.png',512),('Icon-maskable-192.png',192),('Icon-maskable-512.png',512)]:
    app_icon(size).save(web/'icons'/filename)
app_icon(32, symbol_scale=3.5).save(web/'favicon.png')
(web/'favicon.svg').write_text(svg(f'<rect width="128" height="128" fill="{INK}"/><g transform="translate(8 8) scale(3.5)">{symbol_svg(CREAM, ACCENT)}</g>', '0 0 128 128'), encoding='utf-8')
for folder,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    app_icon(size).save(ROOT/'android'/'app'/'src'/'main'/'res'/f'mipmap-{folder}'/'ic_launcher.png')
ios=ROOT/'ios'/'Runner'/'Assets.xcassets'/'AppIcon.appiconset'
for icon in json.loads((ios/'Contents.json').read_text())['images']:
    size=round(float(icon['size'].split('x')[0])*int(icon['scale'][0]))
    app_icon(size).save(ios/icon['filename'])

# A deterministic proof sheet shows both contrast variants and smallest sizes.
proof=Image.new('RGB',(1000,430),CREAM)
proof.paste(lockup_png(scale=6),(52,34))
proof.paste(lockup_png(scale=6,dark=True),(52,230))
proof.save(OUT/'brand-proof.png')
print('Generated vector masters, proof images, 5 Android, 15 unique iOS, 5 web PNGs.')
