# Instalator PiPhi Network dla SenseCAP M1 z balenaOS

## Opis
Repozytorium zawiera skrypt Bash do instalacji PiPhi Network na urządzeniach SenseCAP M1 z systemem balenaOS, z obsługą dongla GPS (przetestowano z U-Blox 7). Instalacja uruchamia PiPhi obok istniejącego Helium Minera, wykorzystując kontener Ubuntu do obsługi Dockera i GPS. Pozwala to na powtarzalną konfigurację na innych SenseCAP M1.

Oparte na dokumentacji PiPhi Network: [docs.piphi.network/Installation](https://docs.piphi.network/Installation) oraz docker-compose.yml z [chibisafe.piphi.network/m2JmK11Z7tor.yml](https://chibisafe.piphi.network/m2JmK11Z7tor.yml).

**Przetestowano na**: balenaOS 2.80.3+rev1, SenseCAP M1 (Raspberry Pi 4), GPS U-Blox 7.

**Najważniejsze cechy**:
- Współistnieje z Helium Minerem.
- Obsługa GPS przez moduł `cdc-acm` i `gpsd`.
- Automatyczna instalacja Dockera w kontenerze Ubuntu.
- Mapowanie portu dla PiPhi (domyślnie: 31415).

## Wymagania
- SenseCAP M1 z balenaOS (dostęp SSH jako root).
- Dongle GPS (U-Blox 7) podłączony do USB.
- Stabilne połączenie sieciowe (do pobierania obrazów i plików).
- Minimum 4 GB RAM (standard w SenseCAP M1).
- Kopia zapasowa karty SD (instalacja modyfikuje system).

**Ostrzeżenia**:
- Może unieważnić gwarancję lub wpłynąć na wydajność Helium Minera.
- Potencjalne konflikty zasobów (CPU/RAM); monitoruj `balena top`.
- Brak oficjalnego wsparcia od PiPhi ani SenseCAP – używasz na własne ryzyko.
- GPS wymaga umieszczenia urządzenia na zewnątrz w celu złapania sygnału satelitarnego.

## Kroki instalacji
1. **Sklonuj repozytorium**:
   ```
   wget https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
   cd piphi-sensecap-installer
   ```

2. **Nadaj uprawnienia skryptowi**:
   ```
   chmod +x install-piphi.sh
   ```

3. **Uruchom skrypt**:
   - Zaloguj się jako root przez SSH: `ssh root@<IP urządzenia>`.
   - Uruchom: `./install-piphi.sh`.
   - Wybierz opcję 1, aby rozpocząć instalację.

Skrypt wykona:
- Sprawdzenie kontenerów Helium.
- Załadowanie modułu GPS (`cdc-acm`).
- Pobranie i modyfikację `docker-compose.yml` dla GPS.
- Pobranie i uruchomienie kontenera Ubuntu.
- Instalację Dockera, gpsd i zależności w Ubuntu.
- Uruchomienie usług PiPhi.
- Restart kontenerów.

## Użycie
- **Dostęp do PiPhi**: http://<IP urządzenia>:31415
- **Sprawdzenie GPS**:
  - Wejdź do kontenera Ubuntu: `balena exec -it ubuntu-piphi /bin/bash`.
  - Uruchom: `cgps -s` (umieść urządzenie na zewnątrz).
- **Logi**:
  - PiPhi: `balena exec ubuntu-piphi docker logs <piphi_container_name>`.
  - Wszystkie kontenery: `balena ps`.
- **Zatrzymanie/Usunięcie**:
  - Zatrzymaj PiPhi: `balena exec ubuntu-piphi docker compose down`.
  - Usuń kontener: `balena stop ubuntu-piphi && balena rm ubuntu-piphi`.
- **Aktualizacja PiPhi**: `cd /piphi-network && docker compose pull && docker compose up -d`.

## Rozwiązywanie problemów
- **GPS nie wykryty**: upewnij się, że U-Blox 7 jest podłączony; uruchom `modprobe cdc-acm`. Sprawdź `dmesg | grep usb`.
- **Konflikt portów**: PiPhi używa 31415; Helium 44158. Zmień w `docker-compose.yml`.
- **Problemy z zasobami**: ogranicz w `docker-compose.yml`:
  ```yaml
  services:
    piphi:
      deploy:
        resources:
          limits:
            cpus: '0.5'
            memory: 512M
  ```
- **Błędy w Ubuntu**: ponownie wejdź do kontenera i wykonaj ręcznie instalację (`apt-get install ...`).
- **Helium nie działa**: uruchom ponownie: `balena restart pktfwd_<id>`.

## Wkład
Chętnie przyjmuję PR-y z ulepszeniami (np. lepsza obsługa GPS, obsługa błędów).

## Licencja
MIT License. Używasz na własne ryzyko.

## Podziękowania
- Na podstawie dokumentacji PiPhi Network i przykładu ThingsIX.
- Wygenerowane z pomocą Grok (xAI).
