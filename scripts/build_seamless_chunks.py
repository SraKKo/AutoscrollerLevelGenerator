"""Deterministic geometry export: no dependencies beyond Pillow and numpy."""
from pathlib import Path
import json
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Assets/Chunks/Seamless'
OUT.mkdir(parents=True, exist_ok=True)
W, H, HALF = 1088, 816, 64
U, M, L = 136, 408, 680
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

def groups(*lanes):
    return [[f'L:{y}', f'R:{y}'] for y in lanes]

# All branches share the same spacious port positions and corridor width.
add('BranchUpper', [path(M,U),path(M,M)], [M], [U,M])
add('BranchLower', [path(M,M),path(M,L)], [M], [M,L])
add('TripleSplit', [path(M,U),path(M,M),path(M,L)], [M], [U,M,L])
add('SplitFromUpper', [path(U,U),path(U,M)], [U], [U,M])
add('SplitFromLower', [path(L,M),path(L,L)], [L], [M,L])
add('UpperMiddleStraight', [path(U,U),path(M,M)], [U,M], [U,M], groups(U,M))
add('MiddleLowerStraight', [path(M,M),path(L,L)], [M,L], [M,L], groups(M,L))
add('TripleStraight', [path(U,U),path(M,M),path(L,L)], [U,M,L], [U,M,L], groups(U,M,L))
# Split one corridor while a separate branch continues through the same chunk.
add('SplitUpperKeepLower', [path(U,U),path(U,M),path(L,L)], [U,L], [U,M,L],
    [[f'L:{U}',f'R:{U}',f'R:{M}'],[f'L:{L}',f'R:{L}']])
add('SplitLowerKeepUpper', [path(U,U),path(L,M),path(L,L)], [U,L], [U,M,L],
    [[f'L:{U}',f'R:{U}'],[f'L:{L}',f'R:{M}',f'R:{L}']])
add('BranchDownKeepUpper', [path(U,U),path(M,M),path(M,L)], [U,M], [U,M,L],
    [[f'L:{U}',f'R:{U}'],[f'L:{M}',f'R:{M}',f'R:{L}']])
add('BranchUpKeepLower', [path(M,U),path(M,M),path(L,L)], [M,L], [U,M,L],
    [[f'L:{M}',f'R:{U}',f'R:{M}'],[f'L:{L}',f'R:{L}']])

def prune(name, lanes, keep):
    add(name, [path(y,y) if y in keep else [(-16,y),(600+80*lanes.index(y),y)] for y in lanes],
        lanes, keep, [[f'L:{y}']+([f'R:{y}'] if y in keep else []) for y in lanes])

prune('CloseUpperKeepMiddle', [U,M], [M])
prune('CloseMiddleKeepUpper', [U,M], [U])
prune('CloseLowerKeepMiddle', [M,L], [M])
prune('CloseMiddleKeepLower', [M,L], [L])
prune('TripleCloseUpper', [U,M,L], [M,L])
prune('TripleCloseMiddle', [U,M,L], [U,L])
prune('TripleCloseLower', [U,M,L], [U,M])
prune('TripleKeepUpper', [U,M,L], [U])
prune('TripleKeepMiddle', [U,M,L], [M])
prune('TripleKeepLower', [U,M,L], [L])

# Real intersections: the union opens the centre, so every arm is connected.
add('CrossX', [path(U,L),path(L,U)], [U,L], [U,L])
add('CrossUpperMiddle', [path(U,M),path(M,U)], [U,M], [U,M])
add('CrossMiddleLower', [path(M,L),path(L,M)], [M,L], [M,L])
add('CrossTriple', [path(U,L),path(M,M),path(L,U)], [U,M,L], [U,M,L])
add('MergeRoom', [path(U,M),path(L,M)], [U,L], [M])
add('MergeUpperMiddle', [path(U,M),path(M,M)], [U,M], [M])
add('MergeMiddleLower', [path(M,M),path(L,M)], [M,L], [M])
# Same boundary ports as StraightRoom, but a solid barrier prevents a straight shortcut.
add('ZigZagUp', [[(-16,M),(136,M),(408,U),(680,U),(952,M),(1104,M)]], [M], [M])
add('ZigZagDown', [[(-16,M),(136,M),(408,L),(680,L),(952,M),(1104,M)]], [M], [M])

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
    # Verify actual raster connectivity, independently of the declared groups.
    walkable = np.asarray(mask.crop((p,p,p+W,p+H))) > 0
    port_pixels = {f'L:{y}':(0,y) for y in d['left']}
    port_pixels.update({f'R:{y}':(W-1,y) for y in d['right']})
    declared = d['groups'] or [list(port_pixels)]
    from collections import deque
    unseen = set(port_pixels)
    actual = []
    while unseen:
        first = next(iter(unseen))
        x,y = port_pixels[first]
        visited = np.zeros((H,W),dtype=bool)
        visited[y,x] = True
        queue = deque([(x,y)])
        while queue:
            x,y=queue.popleft()
            for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if 0<=nx<W and 0<=ny<H and walkable[ny,nx] and not visited[ny,nx]:
                    visited[ny,nx]=True
                    queue.append((nx,ny))
        connected = {key for key,(px,py) in port_pixels.items() if visited[py,px]}
        actual.append(connected)
        unseen -= connected
    assert {frozenset(g) for g in actual} == {frozenset(g) for g in declared}, name
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

example=['Start','SplitRoom','DoubleStraight','SplitUpperKeepLower',
         'TripleStraight','TripleCloseMiddle','DoubleStraight','KeepLower',
         'GoingUp','UpperToMiddle','BranchLower','MiddleLowerStraight',
         'BranchUpKeepLower','TripleStraight','TripleCloseLower','UpperMiddleStraight',
         'CloseUpperKeepMiddle','BranchUpper','UpperMiddleStraight','CloseMiddleKeepUpper',
         'GoingDown','LowerToMiddle','StraightRoom','Finish']
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

crossing_example=['Start','SplitRoom','CrossX','KeepUpper',
    'GoingDown','SplitFromLower','CrossMiddleLower','CloseMiddleKeepLower',
    'GoingUp','SplitFromUpper','CrossUpperMiddle','CloseMiddleKeepUpper',
    'GoingDown','LowerToMiddle','ZigZagUp','Finish']
cross_counts={M:1}
for a,b in zip(crossing_example,crossing_example[1:]):
    assert definitions[a]['right']==definitions[b]['left']
for name in crossing_example[1:-1]:
    next_counts={}
    for group in metadata[name]['connected_port_groups']:
        total=sum(cross_counts.get(int(port[2:]),0) for port in group if port.startswith('L:'))
        for port in group:
            if port.startswith('R:'): next_counts[int(port[2:])]=total
    cross_counts=next_counts
assert cross_counts=={M:8},cross_counts

(OUT/'connections.json').write_text(json.dumps({'size':[W,H],'corridor_height':128,'outline_width':4,'coordinate_origin':'top-left','direction':'left-to-right','chunks':metadata,'example':example,'crossing_example':crossing_example,'crossing_example_port_routes':8},indent=2),encoding='utf-8')

fontpath=Path('C:/Windows/Fonts/arial.ttf')
font=ImageFont.truetype(str(fontpath),20)
sheet=Image.new('RGB',(1128,((len(images)+2)//3)*310+50),(241,246,249))
sd=ImageDraw.Draw(sheet)
sd.text((20,12),f'AUTOSCROLLER / {len(images)} CHUNKS / {W} x {H}',fill=(25,45,60),font=font)
for i,(name,img) in enumerate(images.items()):
    x=18+(i%3)*370; y=50+(i//3)*310
    sd.text((x,y),name,fill=(25,45,60),font=font)
    sheet.paste(img.resize((352,264),Image.Resampling.LANCZOS),(x,y+30))
sheet.save(OUT/'Preview.png')
level=Image.new('RGB',(W*len(example),H),'white')
for i,name in enumerate(example): level.paste(images[name],(W*i,0))
level.save(OUT/'ExampleLevel.png')

# Readable overview of the long continuous level, split into labelled strips.
overview=Image.new('RGB',(1440,6*318+60),(241,246,249))
od=ImageDraw.Draw(overview)
od.text((16,14),'ROZGALEZIONY POZIOM / 24 CHUNKI / 1 TRASA DO METY',font=font,fill=(25,45,60))
smallfont=ImageFont.truetype(str(fontpath),16)
for row in range(6):
    for col in range(4):
        index=row*4+col
        name=example[index]
        x=16+col*352; y=60+row*318
        od.text((x,y),f'{index+1:02d}  {name}',font=smallfont,fill=(25,45,60))
        overview.paste(images[name].resize((352,264),Image.Resampling.LANCZOS),(x,y+28))
overview.save(OUT/'BranchingPreview.png')

cross_level=Image.new('RGB',(W*len(crossing_example),H),'white')
cross_preview=Image.new('RGB',(1440,4*318+60),(241,246,249))
cd=ImageDraw.Draw(cross_preview)
cd.text((16,14),'SKRZYZOWANIA / WYMUSZONE ZMIANY WYSOKOSCI / 16 CHUNKOW',font=font,fill=(25,45,60))
for i,name in enumerate(crossing_example):
    cross_level.paste(images[name],(i*W,0))
    x=16+(i%4)*352; y=60+(i//4)*318
    cd.text((x,y),f'{i+1:02d}  {name}',font=smallfont,fill=(25,45,60))
    cross_preview.paste(images[name].resize((352,264),Image.Resampling.LANCZOS),(x,y+28))
cross_level.save(OUT/'CrossingLevel.png')
cross_preview.save(OUT/'CrossingPreview.png')

(OUT/'README.md').write_text('''# Chunki autoscroller

49 oddzielnych PNG RGB, każdy 1088 × 816 px. Białe tło, niebieski kontur 4 px, bez etykiet w teksturach. Wnętrze korytarza i obszar poza nim są białe, zgodnie ze szkicem. Kontur oznacza ściany; obszary ruchu opisuje JSON. Zachowano 40 poprzednich wariantów i dodano 9 chunków ze skrzyżowaniami, scaleniami i zakrętami.

## Łączenie

Kierunek gry: w prawo. Lewy górny róg to (0,0), Y rośnie w dół. Trzy środki portów: Upper=136, Middle=408, Lower=680. Wysokość korytarza: 128 px. Sąsiadujące chunki ustawiaj co 1088 px w X, bez odstępów, na tej samej wysokości Y. Pełny zestaw prawych portów musi odpowiadać pełnemu zestawowi lewych portów następnego chunka. GoingUp łączy Lower → Upper, GoingDown Upper → Lower. Krótsze przejścia łączą poziom środkowy z górnym lub dolnym. Góra i dół obrazka nie mają portów.

Start ma zamkniętą lewą ścianę, Finish zamkniętą prawą. SplitRoom rozdziela środkowy korytarz na dwa. DoubleStraight prowadzi dwa niezależne korytarze. KeepUpper zamyka dolny, KeepLower zamyka górny. DeadEnd i jego warianty zamykają pojedynczy korytarz.

## Jedna poprawna trasa

ExampleLevel.png zawiera 24 połączone chunki, 5 rozwidleń, 5 ślepych zakończeń i dokładnie jedną trasę do mety. BranchingPreview.png pokazuje ten sam poziom w sześciu kolejnych pasach po cztery chunki (kolejny pas jest kontynuacją poprzedniego, a nie pokojem poniżej). Pełna sekwencja jest w polu example w connections.json.

BranchUpper / BranchLower dodają boczną odnogę obok prostej trasy. TripleSplit ma trzy wyjścia. SplitUpperKeepLower / SplitLowerKeepUpper rozdzielają jedną z dwóch istniejących odnóg, zachowując drugą. BranchDownKeepUpper / BranchUpKeepLower umożliwiają dalsze rozgałęzienie dwóch sąsiednich korytarzy. TripleStraight przedłuża trzy niezależne odnogi. Chunki Close oraz TripleKeep zamykają wybrane korytarze bez scalania dróg. Sąsiednie korytarze mają 144 px odstępu między granicami obszarów ruchu: nie rozszerzaj ich polygonów, bo mogłyby się połączyć.

Jeśli wymagasz dokładnie jednej drogi do mety, generator powinien kończyć alternatywne odnogi przed ich ponownym scaleniem i sprawdzać liczbę skierowanych ścieżek Start→Finish. W JSON connected_port_groups opisuje połączenia WEWNĄTRZ chunka: nie traktuj DoubleStraight jako jednego wspólnego węzła. Wspólne skrzyżowania mogą tworzyć wiele poprawnych tras. Sam BFS znajduje osiągalność i trasę o najmniejszej liczbie krawędzi, nie dowodzi jej unikalności ani najmniejszej długości geometrycznej. Grywalność zależy też od wymiarów postaci, prędkości scrollowania i mechaniki ruchu.

## Skrzyżowania i wymuszone zakręty

CrossX łączy przekątne Upper→Lower oraz Lower→Upper we wspólnym środku. CrossUpperMiddle i CrossMiddleLower to wersje dla sąsiednich poziomów. CrossTriple łączy wszystkie trzy poziomy. Na przecięciu można zmienić odnogę: nie jest to most ani tunel z niezależnymi kolizjami. MergeRoom i jego warianty scalają dwie odnogi. ZigZagUp i ZigZagDown mają porty Middle→Middle, ale wymagają objazdu górą albo dołem, więc nie da się przejechać poziomo przez środek.

CrossingLevel.png pokazuje 16 chunków ze skrzyżowaniami i wymuszonymi zmianami wysokości; CrossingPreview.png dzieli go na cztery kolejne pasy. Ten przykład ma 8 skierowanych tras na poziomie portów, a nie jedną. Zamknięcia i przejścia GoingUp / GoingDown wymuszają zmianę wysokości na każdej z nich. Poprzedni ExampleLevel.png nadal pokazuje jedną trasę do mety. Aby wyznaczać najkrótszą trasę geometryczną, w generatorze potrzebny jest graf punktów wewnątrz korytarzy z wagami długości i algorytm Dijkstry lub A*; sam identyfikator chunka nie wystarczy.

## Dane i import

connections.json zawiera porty i sumę polygonów przejezdnego korytarza (walkable_polygons_union). Współrzędne X celowo wystają do -16 i 1104, aby raster nie zamykał portów; przy tworzeniu geometrii przytnij je do obszaru chunka. Białego tła nie używaj jako maski kolizji. Kolizje wymagają osobnej geometrii ścian.

W Godot ustaw pozycje bez ułamków, skalę 1:1 i wyłącz mipmapy, jeśli pojawią się szwy. Zaktualizowano zestaw Seamless i jego metadane; kod generatora Godot pozostaje bez zmian. Nowe porty nie pasują do starszych chunków 1088 × 544 — używaj całego nowego zestawu.

Preview.png, ExampleLevel.png, BranchingPreview.png, CrossingLevel.png i CrossingPreview.png są podglądami, a nie chunkami. Nowe grafiki i metadane nie zmieniają działającej sceny Godot: podłączenie zestawu wymaga użycia tych portów w generatorze.
''',encoding='utf-8')
archive=OUT.parent/'SeamlessChunks.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for f in sorted(OUT.iterdir()):
        if f.is_file() and f.suffix in ('.png','.json','.md'): z.write(f,'Seamless/'+f.name)
print(f'{len(images)} chunks; {checked} compatible seams verified; example has one route; {archive}')
