"""Deterministic geometry export: no dependencies beyond Pillow and numpy."""
from pathlib import Path
import json
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets/Chunks/Seamless'
OUT.mkdir(parents=True, exist_ok=True)
W, H, HALF = 1088, 544, 64
U, M, L = 136, 272, 408
BLUE = (0, 166, 224)
definitions = {}

def path(a, b):
    return [(-16, a), (272, a), (816, b), (1104, b)]

def add(name, paths, left, right, groups=None):
    definitions[name] = dict(paths=paths, left=left, right=right, groups=groups)

add('Start', [[(136,M),(1104,M)]], [], [M])
add('Finish', [[(-16,M),(952,M)]], [M], [])
for name,y in [('StraightRoom',M),('StraightUpper',U),('StraightLower',L)]:
    add(name,[path(y,y)],[y],[y])
for name,a,b in [('GoingUp',L,U),('GoingDown',U,L),('RiseToUpper',M,U),('DropToLower',M,L),('UpperToMiddle',U,M),('LowerToMiddle',L,M)]:
    add(name,[path(a,b)],[a],[b])
add('SplitRoom',[path(M,U),path(M,L)],[M],[U,L])
add('DoubleStraight',[path(U,U),path(L,L)],[U,L],[U,L],[[f'L:{U}',f'R:{U}'],[f'L:{L}',f'R:{L}']])
add('KeepUpper',[path(U,U),[(-16,L),(680,L)]],[U,L],[U],[[f'L:{U}',f'R:{U}'],[f'L:{L}']])
add('KeepLower',[path(L,L),[(-16,U),(680,U)]],[U,L],[L],[[f'L:{L}',f'R:{L}'],[f'L:{U}']])
for name,y in [('DeadEnd',M),('DeadEndUpper',U),('DeadEndLower',L)]:
    add(name,[[(-16,y),(816,y)]],[y],[])

images = {}
metadata = {}
for name, d in definitions.items():
    # Pad on every side so open ports have no spurious vertical end caps.
    p = 24
    mask = Image.new('L',(W+2*p,H+2*p))
    draw = ImageDraw.Draw(mask)
    polygons=[]
    for points in d['paths']:
        poly=[(x,y-HALF) for x,y in points]+[(x,y+HALF) for x,y in reversed(points)]
        polygons.append(poly)
        draw.polygon([(x+p,y+p) for x,y in poly],fill=255)
    eroded=mask.filter(ImageFilter.MinFilter(5))
    dilated=mask.filter(ImageFilter.MaxFilter(5))
    edge=np.asarray(dilated)!=np.asarray(eroded)
    rgb=np.full((H+2*p,W+2*p,3),255,dtype=np.uint8)
    rgb[edge]=BLUE
    img=Image.fromarray(rgb[p:p+H,p:p+W])
    img.save(OUT / (name+'.png'))
    images[name]=img
    metadata[name]={
        'file':name+'.png',
        'ports': {'left':[{'center_y':y,'top':y-HALF,'bottom':y+HALF} for y in d['left']],
                  'right':[{'center_y':y,'top':y-HALF,'bottom':y+HALF} for y in d['right']]},
        'connected_port_groups':d['groups'] or [[f'L:{y}' for y in d['left']]+[f'R:{y}' for y in d['right']]],
        'walkable_polygons_union':polygons,
    }

# Check all compatible seams, including closed wall pixels and every open port.
checked=0
for an,a in definitions.items():
    for bn,b in definitions.items():
        if a['right'] and a['right']==b['left']:
            assert np.array_equal(np.asarray(images[an])[:,-1],np.asarray(images[bn])[:,0]),(an,bn)
            checked+=1
for img in images.values():
    assert img.size==(W,H)

example=['Start','SplitRoom','DoubleStraight','KeepUpper','GoingDown','LowerToMiddle','StraightRoom','Finish']
for a,b in zip(example,example[1:]):
    assert definitions[a]['right']==definitions[b]['left']

# Count directed paths at component level, preserving the two separate corridors.
counts={M:1}
for name in example[1:-1]:
    next_counts={}
    for group in metadata[name]['connected_port_groups']:
        total=sum(counts.get(int(port[2:]),0) for port in group if port.startswith('L:'))
        for port in group:
            if port.startswith('R:'):
                next_counts[int(port[2:])]=total
    counts=next_counts
assert counts=={M:1},counts

(OUT/'connections.json').write_text(json.dumps({'size':[W,H],'corridor_height':128,'outline_width':4,'coordinate_origin':'top-left','direction':'left-to-right','chunks':metadata,'example':example},indent=2),encoding='utf-8')

fontpath=Path('C:/Windows/Fonts/arial.ttf')
font=ImageFont.truetype(str(fontpath),20)
sheet=Image.new('RGB',(1128,6*222+50),(241,246,249))
sd=ImageDraw.Draw(sheet)
sd.text((20,12),'AUTOSCROLLER / 18 CHUNKS / 1088 x 544',fill=(25,45,60),font=font)
for i,(name,img) in enumerate(images.items()):
    x=18+(i%3)*370; y=50+(i//3)*222
    sd.text((x,y),name,fill=(25,45,60),font=font)
    sheet.paste(img.resize((352,176),Image.Resampling.LANCZOS),(x,y+30))
sheet.save(OUT/'Preview.png')
level=Image.new('RGB',(W*len(example),H),'white')
for i,name in enumerate(example): level.paste(images[name],(W*i,0))
level.save(OUT/'ExampleLevel.png')

(OUT/'README.md').write_text('''# Chunki autoscroller

18 oddzielnych PNG RGB, każdy 1088 × 544 px. Białe tło, niebieski kontur 4 px, bez etykiet w teksturach. Wnętrze korytarza i obszar poza nim są białe, zgodnie ze szkicem. Kontur oznacza ściany; obszary ruchu opisuje JSON.

## Łączenie

Kierunek gry: w prawo. Lewy górny róg to (0,0), Y rośnie w dół. Trzy środki portów: Upper=136, Middle=272, Lower=408. Wysokość korytarza: 128 px. Sąsiadujące chunki ustawiaj co 1088 px w X, bez odstępów, na tej samej wysokości Y. Pełny zestaw prawych portów musi odpowiadać pełnemu zestawowi lewych portów następnego chunka. GoingUp łączy Lower → Upper, GoingDown Upper → Lower. Krótsze przejścia łączą poziom środkowy z górnym lub dolnym. Góra i dół obrazka nie mają portów.

Start ma zamkniętą lewą ścianę, Finish zamkniętą prawą. SplitRoom rozdziela środkowy korytarz na dwa. DoubleStraight prowadzi dwa niezależne korytarze. KeepUpper zamyka dolny, KeepLower zamyka górny. DeadEnd i jego warianty zamykają pojedynczy korytarz.

## Jedna poprawna trasa

Przykład w ExampleLevel.png: Start → SplitRoom → DoubleStraight → KeepUpper → GoingDown → LowerToMiddle → StraightRoom → Finish. Dolna odnoga kończy się ślepą ścianą, górna prowadzi do mety. Wariant: KeepLower → GoingUp → UpperToMiddle.

Generator powinien budować główną trasę i kończyć alternatywne odnogi, bez ich ponownego scalania. W JSON connected_port_groups opisuje połączenia WEWNĄTRZ chunka: nie traktuj DoubleStraight jako jednego wspólnego węzła. Sprawdź liczbę skierowanych ścieżek Start→Finish: musi wynosić 1. To gwarancja topologiczna; grywalność zależy jeszcze od wymiarów postaci, prędkości scrollowania i mechaniki ruchu.

## Dane i import

connections.json zawiera porty i sumę polygonów przejezdnego korytarza (walkable_polygons_union). Współrzędne X celowo wystają do -16 i 1104, aby raster nie zamykał portów; przy tworzeniu geometrii przytnij je do obszaru chunka. Białego tła nie używaj jako maski kolizji. Kolizje wymagają osobnej geometrii ścian.

W Godot ustaw pozycje bez ułamków, skalę 1:1 i wyłącz mipmapy, jeśli pojawią się szwy. Zestaw jest niezależnym eksportem: nie podmieniono istniejących assetów ani kodu generatora.

Preview.png to zbiorczy podgląd, ExampleLevel.png to połączony przykład; te dwa pliki nie są chunkami.
''',encoding='utf-8')
archive=OUT.parent/'SeamlessChunks.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for f in sorted(OUT.iterdir()):
        if f.is_file() and f.suffix in ('.png','.json','.md'): z.write(f,'Seamless/'+f.name)
print(f'{len(images)} chunks; {checked} compatible seams verified; example has one route; {archive}')
