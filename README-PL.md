# Instalator PiPhi Network dla SenseCAP M1 z balenaOS
[🇬🇧 English](README.md) | [🇵🇱 Polski](README-PL.md)


## Przegląd
To repozytorium zawiera w pełni zautomatyzowany skrypt Bash do instalacji PiPhi Network na urządzeniach SenseCAP M1 działających pod kontrolą balenaOS, z obsługą odbiornika GPS (przetestowano z U-Blox 7). Instalacja uruchamia PiPhi obok istniejącego Helium Minera, używając kontenera Ubuntu do obsługi Dockera, GPS i wszystkich usług (PiPhi, PostgreSQL, Watchtower, Grafana). Skrypt zapewnia automatyczny start kontenera i usług po restarcie systemu.

Na podstawie:
- Dokumentacja PiPhi Network: [docs.piphi.network/Installation](https://docs.piphi.network/Installation)
- docker-compose.yml: [chibisafe.piphi.network/m2JmK11Z7tor.yml](https://chibisafe.piphi.network/m2JmK11Z7tor.yml)
- Inspiracja: [WantClue/Sensecap](https://github.com/WantClue/Sensecap)

**Przetestowano na**: balenaOS 2.80.3+rev1, SenseCAP M1 (Raspberry Pi 4, 4GB RAM, arm64), GPS U-Blox 7.

**Główne funkcje**:
- Równoległa praca z Helium Miner (np. kontenery `pktfwd_`, `miner_`).
- Obsługa GPS przez moduł `cdc-acm` (host) i `gpsd` (kontener).
- Wykorzystanie `/mnt/data` jako przestrzeni zapisu.
- Automatyczna instalacja wszystkich zależności (`curl`, `iputils-ping`, `docker-ce`, `gpsd`, `yq`, itp.).
- Niekonfigurowalne interakcyjnie ustawienie strefy czasowej (domyślnie: `Europe/Warsaw`, możliwość zmiany).
- Mapowanie portów dla PiPhi (31415), PostgreSQL (5432) i Grafana (3000).
- Automatyczne uruchamianie kontenera `ubuntu-piphi`, demona Dockera i wszystkich usług po restarcie.
- Przydział zasobów (2 rdzenie CPU, 2GB RAM) dla stabilności.
- Stała konfiguracja wolumenu Grafana i GPS.

## Wymagania
- SenseCAP M1 z balenaOS (dostęp przez SSH jako root).
- Odbiornik GPS (U-Blox 7) podłączony do portu USB.
- Stabilne połączenie sieciowe (pobieranie obrazów i plików).
- Minimum 4GB RAM (standard dla SenseCAP M1).
- Kopia zapasowa karty SD (instalacja modyfikuje system).

**Ostrzeżenia**:
- Może unieważnić gwarancję lub wpłynąć na wydajność Helium Mining.
- Potencjalne konflikty zasobów (CPU/RAM); monitoruj `balena top`.
- Brak oficjalnego wsparcia ze strony PiPhi lub SenseCAP – używasz na własne ryzyko.
- GPS wymaga umieszczenia na zewnątrz w celu uzyskania sygnału satelitarnego (1–5 minut).
- balenaOS nie zawiera `git`, `sudo`, ani `docker`; skrypt korzysta z `wget` i poleceń `balena`.
- System plików root (`/`) jest tylko do odczytu; wszystkie pliki przechowywane w `/mnt/data`.
- balenaOS może wyświetlać ostrzeżenie dotyczące limitów swap – można je zignorować przy 4GB RAM.
- Docker w kontenerze korzysta ze sterownika `vfs` z powodu ograniczeń balenaOS.

## Kroki instalacji automatycznej
1. **Zaloguj się do SenseCAP M1**:
   ```
   ssh root@<adres_IP_urządzenia>
   ```

2. **Przejdź do katalogu zapisu**:
   ```
   cd /mnt/data
   ```

3. **Pobierz skrypt**:
   ```
   wget https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
   ```
   Alternatywnie:
   ```
   curl -o install-piphi.sh https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
   ```

4. **Nadaj uprawnienia do uruchomienia**:
   ```
   chmod +x install-piphi.sh
   ```

5. **Uruchom skrypt**:
   ```
   ./install-piphi.sh
   ```
   - Wybierz opcję 1, aby rozpocząć instalację automatyczną.
   - Podaj strefę czasową (np. `Europe/Warsaw`) lub wciśnij ENTER, aby użyć domyślnej.

Skrypt:
- Zweryfikuje kontenery Helium (`pktfwd_` itp.).
- Załaduje moduł GPS (`cdc-acm`) na hoście.
- Utworzy katalog `/mnt/data/piphi-network`.
- Pobierze lub wygeneruje poprawny `docker-compose.yml` z GPS i Grafana.
- Usunie istniejący kontener `ubuntu-piphi`, aby uniknąć konfliktów.
- Uruchomi kontener Ubuntu w trybie `--privileged`, z limitami zasobów i restartem automatycznym.
- Zainstaluje wszystkie zależności bez interakcji.
- Skonfiguruje strefę czasową.
- Uruchomi Dockera i usługi PiPhi (porty 31415, 5432, 3000).

## Użytkowanie
- **Dostęp do PiPhi**: `http://<IP_urządzenia>:31415`
- **Dostęp do Grafana**: `http://<IP_urządzenia>:3000`
- **GPS**: `cgps -s` w kontenerze `ubuntu-piphi`.
- **Logi**: `docker logs <nazwa_kontenera>` w kontenerze Ubuntu.

## Rozwiązywanie problemów
- Sprawdź działanie demona Dockera: `ps aux | grep dockerd`
- Sprawdź GPS: `lsusb` (powinno pokazać `1546:01a7`).
- Restart usług: `docker compose up -d`

## Roadmap
- [x] Obsługa Helium + PiPhi równolegle
- [x] Stała konfiguracja Grafana
- [x] Automatyczny start usług
- [ ] Obsługa różnych odbiorników GPS
- [ ] Instrukcja wideo

## Licencja
MIT – używaj na własne ryzyko.

## Wsparcie
Jeśli projekt jest pomocny, możesz postawić kawę:
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/B0B01KMW5G)
