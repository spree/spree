# MVP: Kakao Sklepik

## Cel MVP

Celem pierwszego etapu jest przekształcenie działającego fundamentu Spree/Next.js w roboczy sklep internetowy dla produktów kakao.

Na tym etapie nie budujemy jeszcze pełnego „kakao imperium”. Budujemy stabilną, działającą wersję sklepu, którą można pokazać, przetestować i dalej rozwijać.

## Nazwa robocza

**Kakao Sklepik**

Nazwa może zostać zmieniona później. Na tym etapie służy jako roboczy punkt odniesienia dla agentów, treści i brandingu.

## Zakres MVP

### 1. Fundament techniczny

- backend działa lokalnie,
- admin działa lokalnie,
- storefront działa lokalnie,
- produkty testowe się ładują,
- koszyk działa,
- checkout flow jest możliwy do przejścia w środowisku testowym.

### 2. Branding podstawowy

- zmiana tekstów z generycznego Spree/demo na Kakao Sklepik,
- podstawowy ton marki: premium, naturalnie, spokojnie, edukacyjnie,
- unikanie przesadnego „marketplace vibe”; sklep ma wyglądać jak marka, nie jak losowy template.

### 3. Produkty testowe

Pierwsze produkty robocze:

1. Kakao ceremonialne klasyczne
2. Kakao ceremonialne intensywne
3. Zestaw degustacyjny kakao
4. Kakao z przyprawami
5. Akcesoria do przygotowania kakao

Produkty mogą być fikcyjne na etapie MVP, ale mają wyglądać realistycznie.

### 4. Strony podstawowe

- Strona główna
- Katalog produktów
- Strona produktu
- Koszyk
- Checkout
- O nas
- Dostawa
- Zwroty
- Kontakt

### 5. Doświadczenie klienta

MVP ma odpowiedzieć na pytania klienta:

- czym jest kakao ceremonialne,
- dlaczego warto kupić właśnie tutaj,
- czym różnią się produkty,
- jak przygotować kakao,
- jak działa dostawa i zwroty.

## Poza zakresem MVP

Na razie nie robimy:

- gry w sklepie,
- VOD,
- subskrypcji,
- programu lojalnościowego,
- AI doradcy,
- zaawansowanego quizu,
- rozbudowanego systemu treści,
- dużych zmian w core silnika.

Te elementy są przewidziane później, po ustabilizowaniu podstawowego sklepu.

## Zasady dla agentów przy MVP

1. Najpierw utrzymać działający sklep.
2. Nie mieszać eksperymentalnych modułów z checkoutem.
3. Zmiany brandingu robić głównie w storefrontcie.
4. Nie modyfikować core Spree bez decyzji w `docs/engine-decisions.md`.
5. Każdy etap powinien być możliwy do przetestowania lokalnie.
6. Jeśli agent nie wie, gdzie coś zmienić, ma najpierw sprawdzić `AGENTS.md` i `docs/kierunek-projektu.md`.

## Pierwszy techniczny milestone

Zidentyfikować strukturę storefrontu i znaleźć pliki odpowiedzialne za:

- nazwę sklepu,
- homepage,
- layout/header/footer,
- katalog produktów,
- stronę produktu,
- konfigurację połączenia ze Spree API.

Po tym można zacząć pierwsze zmiany brandingowe.
