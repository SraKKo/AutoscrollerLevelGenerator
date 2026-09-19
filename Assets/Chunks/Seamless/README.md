# Chunki autoscroller

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
