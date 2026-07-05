# Decyzje dotyczące silnika

Ten plik służy do dokumentowania świadomych zmian w silniku commerce, backendzie, checkoutcie, modelu zamówień, płatnościach, adminie lub API.

## Zasada główna

Najpierw rozszerzamy Spree. Core modyfikujemy dopiero wtedy, gdy jest to naprawdę uzasadnione.

## Zasada pracy z agentami

Agent nie może zmieniać silnika commerce bez decyzji zapisanej w tym dokumencie.

Jeśli zmiana wpływa na Store API używane przez `KakaowySklepikFront`, musi to być opisane wprost: które endpointy, formaty danych albo nagłówki się zmieniają i jaki jest wpływ na adapter `lib/spree`.

Jeśli zmiana jest tylko konfiguracją albo rozszerzeniem, też trzeba opisać, dlaczego nie ruszano core Spree. Taka notatka ma ułatwić kolejnym agentom zrozumienie, że brak modyfikacji core był świadomą decyzją, a nie przypadkiem.

Decyzje mają być czytelne dla kolejnych agentów: krótki kontekst, jednoznaczna decyzja, uzasadnienie, wpływ na upstream i praktyczne notatki są ważniejsze niż długi opis.

Każda modyfikacja core powinna mieć krótki wpis w tym pliku, żeby po czasie było jasne:

- co zostało zmienione,
- dlaczego zostało zmienione,
- czy była rozważana alternatywa przez konfigurację lub rozszerzenie,
- jaki jest wpływ na aktualizacje upstreamowego Spree.

## Szablon wpisu

```md
## YYYY-MM-DD — Tytuł decyzji

### Status

Proponowana / zaakceptowana / wdrożona / wycofana

### Kontekst

Krótki opis problemu lub potrzeby.

### Decyzja

Co zmieniamy i gdzie.

### Uzasadnienie

Dlaczego ta decyzja jest lepsza niż alternatywy.

### Wpływ na upstream

Czy zmiana utrudnia aktualizację Spree? Jeśli tak, w jaki sposób.

### Notatki

Dodatkowe informacje, linki do PR, issue lub commitów.
```

## Log decyzji

Na ten moment brak własnych modyfikacji silnika.
