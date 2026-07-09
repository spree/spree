# Deployment backendu na Oracle Cloud

Opis decyzji i docelowego kierunku migracji backendu/API z Rendera na Oracle Cloud. Ten plik nie oznacza jeszcze, że produkcja działa na Oracle — do czasu cutoveru źródłem prawdy dla żywego backendu pozostaje [`deployment-render.md`](deployment-render.md).

## Dlaczego migrujemy z Rendera

Render free/starter okazał się za mały dla backendu Rails/Spree:

- backend dwa razy padł przez OOM przy realnym ruchu API,
- problemem jest głównie RAM: free/starter daje za mały limit dla Rails + Spree,
- Render Starter za ~$7/mo nie rozwiązuje OOM, bo nadal ma ten sam limit pamięci,
- realna naprawa na Renderze oznaczałaby co najmniej większy web plan oraz osobny worker Sidekiq, czyli koszt w okolicach pełnopłatnego PaaS.

Decyzja właściciela: nie budować dalej na minimalnym Renderze, który prawie działa i potrafi paść pod ruchem, tylko przenieść backend na VPS w Oracle Cloud. Priorytetem jest sklep działający stabilniej niż Render free/starter, z drogą rozbudowy do płatnej, ale nadal rozsądnej kosztowo infrastruktury.

## Zakres migracji

Migruje się tylko backend/API:

- Rails backend / Spree fork z repo `pawelekbyra/sklepik`,
- PostgreSQL,
- Redis,
- Sidekiq worker,
- Nginx jako reverse proxy,
- SSL przez Let's Encrypt/certbot,
- deploy z GitHuba.

Nie migrują się:

- storefront `pawelekbyra/sklepikFront` — zostaje na Vercelu,
- panel admina `packages/dashboard` — zostaje na Vercelu,
- Cloudflare R2 media — zostaje zewnętrznym storage dla Active Storage, dopóki nie zapadnie osobna decyzja.

## Stan przygotowania Oracle na 2026-07-08

Konto Oracle Cloud zostało założone w regionie:

```text
France Central / Paris
```

To jest akceptowalny europejski region dla sklepu planowanego na Europę. Frankfurt byłby preferowany dla Polski, ale Paris jest wystarczająco blisko i nie blokuje migracji.

Utworzono osobną sieć przez VCN Wizard z internet connectivity:

```text
VCN: sklepik-vcn
Public subnet: public subnet-sklepik-vcn, 10.0.0.0/24
Private subnet: private subnet-sklepik-vcn, 10.0.1.0/24
Internet Gateway: podpięty do public subnet
NAT Gateway + Service Gateway: dla private subnet
```

W kreatorze VM poprawnym wyborem sieci jest:

```text
Select existing virtual cloud network
VCN: sklepik-vcn
Subnet: public subnet-sklepik-vcn
Automatically assign public IPv4 address: ON
IPv6: OFF
```

Wygenerowano parę kluczy SSH w Oracle. Prywatny klucz ma pozostać wyłącznie lokalnie u właściciela — nie wolno go commitować, wklejać do chatu ani przekazywać agentom.

## Decyzja o shape VM

Pierwotny plan zakładał darmowy Oracle Always Free Ampere A1:

```text
VM.Standard.A1.Flex
4 OCPU
24 GB RAM
```

To nadal jest bardzo atrakcyjny docelowy wariant darmowy, ale w regionie Paris wystąpił `Out of capacity` nawet dla minimalnego Ampere `1 OCPU / 6 GB`. Nie był to błąd konfiguracji — to ograniczenie dostępności darmowych zasobów.

Żeby nie blokować migracji i faktycznie postawić działający sklep, właściciel zaakceptował płatny, ale rozsądny start:

```text
Shape: VM.Standard.E4.Flex
OCPU: 1
Memory: 8 GB
Image: Ubuntu 22.04 LTS
```

To jest celowo wybrane jako lepsze środowisko niż Render free/starter, ale nadal mały, kontrolowany koszt. E4 Flex daje też ścieżkę rozbudowy: można później zwiększać OCPU/RAM albo wrócić do polowania na Ampere A1, jeśli darmowa pojemność się zwolni.

## Ważne zasady dla kolejnych agentów

1. Nie zakładaj, że właściciel chce najtańszy możliwy hosting za wszelką cenę. Chce stabilniejszy backend niż Render free/starter i jest gotów płacić niewielką kwotę, jeśli to daje działający sklep i ścieżkę rozbudowy.
2. Nie wracaj automatycznie do Render Starter — Starter nie rozwiązuje problemu OOM.
3. Nie wybieraj `VM.Standard.E2.1.Micro` jako produkcyjnego hostingu Rails/Spree. Jest za małe; nadaje się co najwyżej do nauki SSH.
4. Jeśli Ampere A1 dalej pokazuje `Out of capacity`, nie blokuj migracji. Płatny `VM.Standard.E4.Flex 1 OCPU / 8 GB` jest zaakceptowanym fallbackiem.
5. Nie commituj żadnych sekretów: prywatnego SSH key, `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, haseł bazy, tokenów R2, GitHuba ani Oracle.
6. Backend musi używać gemów z tego forka przez `SPREE_PATH`, tak jak obecny Render flow. Nie wolno przez przypadek odpalić czystego `spree-starter` na gemach z RubyGems.

## Docelowy stack na VPS

Docelowo Oracle VPS ma uruchamiać:

```text
Nginx + certbot/Let's Encrypt
Rails/Puma backend
Sidekiq worker
PostgreSQL
Redis
Docker + Docker Compose
```

Panel admina i storefront zostają na Vercelu, więc po cutoverze trzeba zaktualizować ich konfigurację tak, aby wskazywały na nowy backend/API zamiast Rendera.

## SSL Certificate — Tymczasowe vs. docelowe

**Tymczasowe (2026-07-09 — teraz):**
- Self-signed certificate (OpenSSL) do wewnętrznych testów
- API dostępna po HTTPS (self-signed, niezaufany)
- Vercel storefront/admin korzystają z HTTP zamiast HTTPS dla zgodności z build timerem (self-signed cert odrzucane przez Node.js)
- `SPREE_API_URL=http://141.253.103.172` (bez SSL dla development/testing)

**Docelowe (po setup domeny):**
- Kupić/przydzielić domenę (np. `api.kakaowy-sklepik.com` lub `backend.kakaowy-sklepik.pl`)
- Wskazać domenę DNS na IP `141.253.103.172`
- Uruchomić `certbot` na Oracle VM z Let's Encrypt:
  ```bash
  sudo certbot certonly --standalone -d api.kakaowy-sklepik.pl
  ```
- Zaktualizować Nginx aby używał certyfikatu Let's Encrypt
- Zmienić na Vercelu:
  ```
  SPREE_API_URL=https://api.kakaowy-sklepik.pl
  ```

Na razie HTTP jest OK dla testów, ale trzeba przejść na HTTPS + Let's Encrypt do produkcji.

## Render flow, który trzeba odtworzyć lub świadomie zastąpić

Obecny Render deployment robi kilka istotnych rzeczy:

- klonuje świeży `spree/spree-starter` do `server/`,
- wymusza Ruby `3.4.4`,
- zapisuje `SPREE_PATH`, żeby bundler brał lokalne gemy `spree/core`, `spree/api`, itd. z tego forka,
- prekompiluje assety,
- w release kopiuje migracje silnika (`spree:install:migrations`),
- wykonuje `db:prepare`, `db:migrate`, `spree:role_users:backfill_store_ids`,
- startuje Puma przez `cd server && bundle exec puma -C config/puma.rb`.

Na Oracle można ten model odtworzyć w Docker Compose albo świadomie przejść na trwalszy katalog `server/`. Jeśli `server/` nadal będzie efemeryczny, zostaje ryzyko timestampów migracji opisane w [`deployment-render.md`](deployment-render.md): nowe migracje w engine muszą być idempotentne.

## Następne kroki po utworzeniu VM

Po utworzeniu instancji i potwierdzeniu publicznego IP:

1. Przenieść prywatny klucz SSH do bezpiecznego lokalnego miejsca u właściciela, np. poza repo.
2. Sprawdzić logowanie:

   ```bash
   ssh -i /sciezka/do/klucza.key ubuntu@PUBLIC_IP
   ```

3. Zaktualizować system i zainstalować Docker/Docker Compose.
4. Przygotować katalog aplikacji, np. `/opt/kakaowy-sklepik`.
5. Sklonować repo `pawelekbyra/sklepik`.
6. Przygotować produkcyjny `docker-compose.yml` lub równoważny runbook.
7. Skonfigurować Postgres, Redis, Rails/Puma, Sidekiq, Nginx i SSL.
8. Przenieść/odtworzyć zmienne środowiskowe z Rendera bez commitowania sekretów.
9. Przetestować `/up`, Store API, Admin API, logowanie panelu, webhooki storefrontu i media R2.
10. Dopiero po testach przełączyć Vercel/storefront/admin na nowy backend i zaplanować wyłączenie Rendera.

## Cutover checklist

Przed uznaniem migracji za zakończoną:

- `GET /up` działa po HTTPS na nowym hostingu,
- Store API odpowiada z danymi produktów,
- Admin API działa z panelem Vercel,
- Sidekiq worker działa i ma dostęp do Redis/Postgres,
- Active Storage/R2 nadal generuje poprawne publiczne URL-e,
- webhooki do storefrontu działają,
- Vercel `sklepik_front` ma poprawne `SPREE_API_URL` i `SPREE_PUBLISHABLE_KEY`,
- `packages/dashboard/vercel.json` albo konfiguracja Vercel panelu wskazuje na nowy backend,
- logi i restart po reboot serwera są sprawdzone,
- jest plan backupu Postgresa,
- `docs/architektura.md` opisuje Oracle jako produkcyjny backend dopiero po faktycznym cutoverze.
