# bento

Zestaw narzędzi do macOS w jednej aplikacji z paska menu. Pierwszy moduł to kafelkowy menedżer okien w stylu Hyprlanda: układ dwindle, 10 pulpitów, gradientowe ramki, wyspa z pulpitami pod paskiem menu, animacje i konfiguracja w składni Hyprlanda przeładowywana po zapisie.

## Wymagania

- macOS 26 na Apple Silicon
- Command Line Tools ze Swift 6.2 (`xcode-select --install`); Xcode nie jest potrzebny
- jeden pulpit macOS (Space) na każdy ekran

## Pierwsze uruchomienie

1. **Certyfikat do podpisu (raz).** Pęk kluczy → Asystent certyfikatów → Utwórz certyfikat…
   Nazwa `bento-dev`, typ tożsamości *Self Signed Root*, typ certyfikatu *Code Signing*.
   Bez niego macOS po każdej przebudowie pyta o uprawnienia od nowa.
2. **Wyłącz inne menedżery okien:** zamknij OmniWM i Rectangle (Rectangle też używa ctrl-alt + strzałek).
3. **Zbuduj aplikację:**

   ```bash
   scripts/build-app.sh
   ```

4. **Uruchom ją:**

   ```bash
   open build/bento.app
   ```

5. **Nadaj uprawnienia** w Ustawienia systemowe → Prywatność i ochrona:
   - **Dostępność** (wymagana) — kafelkowanie startuje kilka sekund po nadaniu.
   - **Nagrywanie ekranu** (opcjonalne) — bez niego wszystko działa, tylko bez animacji. Po nadaniu zamknij bento z jego menu i uruchom ponownie.

W pasku menu pojawia się ikona siatki. Jej menu ma: przeładowanie i otwarcie konfiguracji, błędy konfiguracji, pauzę, uruchamianie przy logowaniu i wyjście.

## Skróty (mod = ctrl-alt)

| Skrót | Działanie |
|---|---|
| mod + ←/→ / h l | fokus na okno obok; za ostatnim oknem — poprzedni/następny pulpit z oknami na tym ekranie (nigdy drugi ekran) |
| mod + ↑/↓ / k j | fokus na okno nad/pod; na krawędzi — poprzedni/następny ekran (od lewej, z zawijaniem) |
| mod + shift + ←/→ / h l | zamień okno z sąsiadem; za ostatnim oknem — przenieś je na poprzedni/następny pulpit tego ekranu (także pusty, bez zawijania) i przejdź tam z nim |
| mod + shift + ↑/↓ / k j | zamień okno z sąsiadem nad/pod; na krawędzi — przenieś je na poprzedni/następny ekran (od lewej, z zawijaniem) |
| mod + 1…9 | pulpit 1–9 |
| mod + 0 | pulpit 0 — ekran MacBooka (tylko przy podłączonym monitorze) |
| mod + shift + 1…9 / 0 | wyślij okno na pulpit 1–9 / 0 |
| mod + shift + Tab | przenieś pulpit na drugi ekran (tylko bez ekranu wbudowanego, np. dwa monitory zewnętrzne) |
| mod + minus / equal | zmniejsz / powiększ okno |
| mod + T | zmień podział (obok siebie / jedno pod drugim) |
| mod + F | wypełnij ekran |
| mod + V | okno pływające / kafelkowe |
| mod + Q | zamknij okno |
| mod + przeciągnij / prawy przycisk | przesuń / zmień rozmiar myszką |
| mod + Return | otwórz Ghostty |
| F3 (Mission Control) / ctrl + ↑ | podgląd okien wszystkich pulpitów na każdym ekranie; strzałki — zaznacz okno (także na drugim ekranie), Return / spacja / klik — przejdź do okna, Esc / F3 / klik w tło — zamknij. W starszym `bento.conf` dopisz `bind = , mission_control, overview` i `bind = CTRL, up, overview` |
| shift + cmd + C | historia schowka (200 ostatnich wpisów + przypięte): teksty ze stylami, obrazki, pliki z Findera; w wierszu ikonka aplikacji i „5m temu”, po prawej podgląd z aplikacją, pierwszą i ostatnią kopią i liczbą kopii. Pisanie filtruje (też po nazwie aplikacji), ↑/↓ zaznacza, Return / klik wkleja do aplikacji, w której byłeś, shift+Return wkleja jako czysty tekst, ⌘1–⌘9 wkleja n-ty wpis, ⌥P przypina, ⌥⌫ usuwa, Esc zamyka. Hasła z menedżerów haseł i tokeny (`sk-…`, `ghp_…`, JWT, klucze prywatne) są widoczne jako `••••••••` i nie trafiają na dysk. „Clear Clipboard History” w menu czyści wszystko poza przypiętymi. Działa, gdy kafelkowanie nie jest zapauzowane. W starszym `bento.conf` dopisz `bind = SUPER SHIFT, c, clipboard` |

## Keep Awake

Pozycja „Keep Awake” w menu bento nie pozwala uśpić ekranu ani systemu (jak `caffeinate -d`), aż ją wyłączysz albo zamkniesz bento (albo od startu: `clipboard:keep_awake_on_launch = true`). Gdy jest włączona, ikonka w pasku menu zmienia się na filiżankę.

## Dwa ekrany

Gdy do MacBooka podłączony jest monitor zewnętrzny, ekran MacBooka ma na stałe pulpit 0 (ctrl-alt-0), a monitor zewnętrzny pulpity 1–9 (ctrl-alt-1…9) — niezależnie od tego, na którym ekranie jest fokus. Wyspa MacBooka pokazuje tylko 0, wyspa monitora 1–9. Bez monitora MacBook ma pulpity 1–9, a ctrl-alt-0 nic nie robi. Po odłączeniu monitora okna z pulpitu 0 trafiają na najniższy pusty pulpit 1–9, a MacBook pokazuje pulpit, który był na monitorze.

## Okna dialogowe

Okna pomocnicze aplikacji — ustawienia, „O programie”, okna modalne, okna o stałym rozmiarze i okna bez przycisku pełnego ekranu — nie wchodzą do kafelków: pływają i pojawiają się wyśrodkowane nad ostatnio aktywnym oknem tej samej aplikacji, na jego pulpicie. Zwykłe kolejne okno aplikacji dalej idzie do kafelków. Okno, które ma pływać, a nie jest rozpoznane, dopiszesz regułą `windowrule = float, app:…` w konfiguracji.

## Konfiguracja

Plik `~/.config/bento/bento.conf` powstaje przy pierwszym uruchomieniu. Zmiany działają w sekundę po zapisie; błąd składni z numerem linii pokazuje się w menu i jako „!” na wyspie.

Menu bento → **Settings…** (⌘,) otwiera okno ustawień z zakładkami Appearance (odstępy, ramki, wyspa, przezroczystość wyspy), Behavior (fokus za myszą, kursor, animacje, start z systemem), Shortcuts (nagrywanie skrótów, akcje, `$mod`) i Clipboard (rozmiar historii, Keep Awake przy starcie). Okno zapisuje zmiany prosto do `bento.conf` — zmienia tylko dotkniętą linię, komentarze i ręczne zmiany zostają. Reguły okien (`windowrule`), skróty myszy (`bindm`) i animacje szczegółowo ustawia się dalej w pliku.

```
clipboard {
    history_size = 200            # 10–2000 wpisów, przypięte się nie liczą
    keep_awake_on_launch = false  # Keep Awake włączone od startu bento
}
```

Skrót do aplikacji (przełącza na nią, a jeśli nie działa — uruchamia):

```
bind = $mod, b, focusorlaunch, Safari
```

### Wygląd

```
general {
    gaps_in = 10                  # szczelina między oknami
    gaps_out = 20 12 12 12        # marginesy od krawędzi ekranu: 1–4 liczby jak w CSS (góra prawo dół lewo)
    border_size = 2
    border_size_inactive = 1      # ramka okien bez fokusu; brak = border_size, 0 = bez ramki
    col.active_border = rgba(f5c2e7ff) rgba(89b4faff) 135deg
    col.inactive_border = rgba(585b70aa)   # ostatnia para cyfr to przezroczystość
}

bar {
    icons = true                  # ikonki aplikacji obok numeru pulpitu; false = same numery
    height = 30
    font_size = 13
    margin_top = 4                # odstęp wyspy od paska menu
    margin_bottom = 4             # odstęp wyspy od okien
    padding = 15                  # odstęp numerów od brzegu wyspy; domyślnie połowa height
    rounding = 15                 # zaokrąglenie wyspy; domyślnie połowa height
    col.background = rgba(1e1e2e80)        # zabarwienie szkła; rgba(00000000) = bez
    col.active = rgba(f5c2e7ff)            # bieżący pulpit
    col.other_monitor = rgba(cba6f7ff)     # obrys pulpitu widocznego na drugim ekranie
    col.text = rgba(cdd6f4ff)
    col.text_active = rgba(1e1e2eff)
    col.text_empty = rgba(6c7086ff)
    col.error = rgba(f38ba8ff)
}
```

Kolory zapisuje się tylko jako `rgba(RRGGBBAA)` albo `rgb(RRGGBB)` — `#` zaczyna komentarz.

## Wyjście i bezpieczeństwo okien

Okna z ukrytych pulpitów są „zaparkowane” poza ekranem. Przy wyjściu, pauzie i `kill -TERM` wracają na ekran; po awarii (`kill -9`) wracają przy następnym uruchomieniu.

## Testy

```bash
scripts/test.sh
```

(`swift test` sam nie znajdzie frameworka Testing bez Xcode.)

## Więcej

- [docs/SETUP.md](docs/SETUP.md) — szczegóły konfiguracji systemu
- [docs/MANUAL-CHECKS.md](docs/MANUAL-CHECKS.md) — lista ręcznych testów; zacznij od sekcji „Anti-goal checks”
- [docs/superpowers/specs/2026-11-02-bento-design.md](docs/superpowers/specs/2026-11-02-bento-design.md) — projekt
