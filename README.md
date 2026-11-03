# hyprmac

Kafelkowy menedżer okien dla macOS w stylu Hyprlanda: układ dwindle, 10 pulpitów, gradientowe ramki, wyspa z pulpitami pod paskiem menu, animacje i konfiguracja w składni Hyprlanda przeładowywana po zapisie.

## Wymagania

- macOS 26 na Apple Silicon
- Command Line Tools ze Swift 6.2 (`xcode-select --install`); Xcode nie jest potrzebny
- jeden pulpit macOS (Space) na każdy ekran

## Pierwsze uruchomienie

1. **Certyfikat do podpisu (raz).** Pęk kluczy → Asystent certyfikatów → Utwórz certyfikat…
   Nazwa `hyprmac-dev`, typ tożsamości *Self Signed Root*, typ certyfikatu *Code Signing*.
   Bez niego macOS po każdej przebudowie pyta o uprawnienia od nowa.
2. **Wyłącz inne menedżery okien:** zamknij OmniWM i Rectangle (Rectangle też używa ctrl-alt + strzałek).
3. **Zbuduj aplikację:**

   ```bash
   scripts/build-app.sh
   ```

4. **Uruchom ją:**

   ```bash
   open build/hyprmac.app
   ```

5. **Nadaj uprawnienia** w Ustawienia systemowe → Prywatność i ochrona:
   - **Dostępność** (wymagana) — kafelkowanie startuje kilka sekund po nadaniu.
   - **Nagrywanie ekranu** (opcjonalne) — bez niego wszystko działa, tylko bez animacji. Po nadaniu zamknij hyprmac z jego menu i uruchom ponownie.

W pasku menu pojawia się ikona siatki. Jej menu ma: przeładowanie i otwarcie konfiguracji, błędy konfiguracji, pauzę, uruchamianie przy logowaniu i wyjście.

## Skróty (mod = ctrl-alt)

| Skrót | Działanie |
|---|---|
| mod + strzałki / h j k l | przenieś fokus; gdy w lewo/prawo nie ma już okna ani ekranu — poprzedni/następny pulpit z oknami na tym ekranie |
| mod + shift + strzałki / h j k l | przesuń okno |
| mod + 1…0 | pulpit 1–10 |
| mod + shift + 1…0 | wyślij okno na pulpit 1–10 |
| mod + shift + Tab | przenieś pulpit na drugi ekran (tylko bez ekranu wbudowanego, np. dwa monitory zewnętrzne) |
| mod + minus / equal | zmniejsz / powiększ okno |
| mod + T | zmień podział (obok siebie / jedno pod drugim) |
| mod + F | wypełnij ekran |
| mod + V | okno pływające / kafelkowe |
| mod + Q | zamknij okno |
| mod + przeciągnij / prawy przycisk | przesuń / zmień rozmiar myszką |
| mod + Return | otwórz Ghostty |

## Dwa ekrany

Gdy do MacBooka podłączony jest monitor zewnętrzny, ekran wbudowany ma na stałe jeden pulpit (1), a pulpity 2–10 zawsze otwierają się na monitorze zewnętrznym — niezależnie od tego, na którym ekranie jest fokus. ctrl-alt-1 przenosi fokus na ekran wbudowany. Wyspa wbudowanego pokazuje tylko 1, wyspa zewnętrznego 2–10. Numer pulpitu wbudowanego bierze się z linii `workspace = 1, monitor:builtin, default:true` w konfiguracji. Przy samym laptopie wszystkie 10 pulpitów jest na jego ekranie.

## Konfiguracja

Plik `~/.config/hyprmac/hyprmac.conf` powstaje przy pierwszym uruchomieniu. Zmiany działają w sekundę po zapisie; błąd składni z numerem linii pokazuje się w menu i jako „!” na wyspie.

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

decoration {
    rounding = 16                 # zaokrąglenie ramki
}

bar {
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
- [docs/superpowers/specs/2026-11-02-hyprmac-design.md](docs/superpowers/specs/2026-11-02-hyprmac-design.md) — projekt
