# Instalator PiPhi Network dla SenseCAP M1 z balenaOS
[🇬🇧 English](README.md) | [🇵🇱 Polski](README-PL.md)

## Kluczowe zmiany w skrypcie (wersja 2.22)
1. **Tworzenie `start-docker.sh` przed uruchomieniem kontenera**:
   - Skrypt teraz tworzy `start-docker.sh` na hoście w `/mnt/data/piphi-network` przed uruchomieniem kontenera `ubuntu-piphi`, aby uniknąć błędu `no such file or directory`.

2. **Ostrożne usuwanie plików**:
   - Zamiast usuwać cały katalog `/mnt/data/piphi-network/*`, skrypt usuwa tylko `docker-compose.yml` i `dockerd.log`, zachowując `start-docker.sh` podczas reinstalacji.

3. **Niezawodne uruchamianie GPS**:
   - Potwierdzono, że `gpsd /dev/ttyACM0` jest uruchamiane automatycznie w `start-docker.sh` z weryfikacją urządzenia.

4. **Logowanie**:
   - `start-docker.sh` zawiera szczegółowe logi z sygnaturami czasowymi dla każdego kroku (start `dockerd`, `gpsd`, `docker compose pull`, `docker compose up`).

## Instrukcje wdrożenia
1. **Zatrzymaj i usuń istniejący kontener `ubuntu-piphi`** (na hoście):
   ```
   balena stop ubuntu-piphi
   balena rm ubuntu-piphi
   ```

2. **Usuń stare pliki konfiguracyjne** (na hoście):
   ```
   cd /mnt/data/piphi-network
   rm -f docker-compose.yml dockerd.log
   ```
   - Uwaga: Nie usuwamy `start-docker.sh`, ponieważ zostanie nadpisany przez nowy skrypt.

3. **Usuń stary skrypt instalacyjny** (na hoście):
   ```
   rm /mnt/data/install-piphi.sh
   ```

4. **Pobierz zaktualizowany skrypt** (na hoście):
   ```
   cd /mnt/data
   wget https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
   ```

5. **Ustaw uprawnienia i uruchom** (na hoście):
   ```
   chmod +x install-piphi.sh
   ./install-piphi.sh
   ```
   - Wybierz opcję 1, aby rozpocząć instalację.
   - Opcjonalnie, wybierz opcję 3, aby zmienić język na polski.

   * Jeżeli podczas instalacji pojawi się błąd (np. „pobieranie obrazu Ubuntu nie powiodło się po 3 próbach”),
odczekaj chwilę i uruchom ponownie:
   ```
   ./install-piphi.sh
   ```

7. **Sprawdź panel PiPhi**:
   - Otwórz przeglądarkę: `http://<IP urządzenia>:31415`.
   - Sprawdź Grafana: `http://<IP urządzenia>:3000`.

8. **Sprawdź GPS** (na hoście):
   ```
   balena exec -it ubuntu-piphi cgps -s
   ```
   - Jeśli GPS nie działa, upewnij się, że urządzenie jest na zewnątrz (fix może zająć 1–5 minut).

9. **Sprawdź status usług** (na hoście):
   ```
   balena ps -a
   balena exec ubuntu-piphi docker compose ps
   ```

10. **Sprawdź logi w razie błędu** (na hoście i w kontenerze):
   - Logi kontenera:
     ```
     balena logs ubuntu-piphi
     ```
   - Logi apt-get:
     ```
     balena exec ubuntu-piphi cat /tmp/apt.log
     ```
   - Logi daemona Dockera i GPS:
     ```
     balena exec ubuntu-piphi cat /piphi-network/dockerd.log
     ```
   - Logi PiPhi:
     ```
     balena exec ubuntu-piphi docker logs piphi-network-image
     ```

11. **Test restartu urządzenia** (na hoście):
    ```
    reboot
    ```
    - Po restarcie sprawdź status:
      ```
      balena ps -a
      balena exec ubuntu-piphi docker compose ps
      ```
    - Sprawdź dostępność panelu: `http://<IP urządzenia>:31415`.

## Ręczna naprawa (jeśli skrypt nadal nie działa)
Jeśli instalacja nadal się nie powiedzie, wykonaj następujące kroki:

1. **Sprawdzenie demona Dockera** (na hoście):
   ```
   balena exec -it ubuntu-piphi /bin/bash
   pgrep dockerd
   ```
   - Jeśli brak wyniku, uruchom ręcznie:
     ```
     /piphi-network/start-docker.sh
     ```
   - Sprawdź logi:
     ```
     cat /piphi-network/dockerd.log
     ```

2. **Naprawa GPS** (w kontenerze):
   ```
   ls /dev/ttyACM0
   gpsd /dev/ttyACM0
   cgps -s
   ```
   - Jeśli brak `/dev/ttyACM0`, sprawdź na hoście:
     ```
     lsusb
     ls /dev/ttyACM*
     ```

3. **Uruchomienie usług ręcznie** (w kontenerze):
   ```
   cd /piphi-network
   docker compose pull
   docker compose up -d
   docker compose ps
   ```

4. **Restart kontenera** (na hoście):
   ```
   balena restart ubuntu-piphi
   ```

## Uwagi
- **Demon Dockera**: Skrypt teraz tworzy `start-docker.sh` przed uruchomieniem kontenera, co eliminuje błąd `no such file or directory`. Pętla w `start-docker.sh` zapewnia automatyczne przywracanie demona po awarii.
- **GPS**: Uruchamianie `gpsd` jest teraz niezawodne, z weryfikacją urządzenia `/dev/ttyACM0`.
- **Panel PiPhi**: Sprawdź w przeglądarce `http://<IP urządzenia>:31415`. Jeśli nie działa, zweryfikuj port:
  ```
  balena exec ubuntu-piphi nc -z 127.0.0.1 31415
  ```
- **Ostrzeżenie o swap**: Jest to normalne w balenaOS i nie wpływa na działanie przy 4GB RAM.
- **Helium Miner**: Kontenery Helium (`pktfwd_`, `miner_`, itp.) nie są naruszane przez instalację.

## Weryfikacja po instalacji
Po wykonaniu skryptu prześlij wyniki następujących komend, aby potwierdzić poprawność instalacji:

- Status kontenerów:
  ```
  balena ps -a
  balena exec ubuntu-piphi docker compose ps
  ```
- Logi:
  ```
  balena logs ubuntu-piphi
  balena exec ubuntu-piphi cat /piphi-network/dockerd.log
  balena exec ubuntu-piphi cat /tmp/apt.log
  balena exec ubuntu-piphi docker logs piphi-network-image
  ```
- Dostępność panelu:
  - Sprawdź w przeglądarce: `http://<IP urządzenia>:31415`
  - W konsoli:
    ```
    balena exec ubuntu-piphi nc -z 127.0.0.1 31415
    ```
- GPS:
  ```
  balena exec -it ubuntu-piphi cgps -s
  ```

## Wesprzyj moją pracę
Jeśli uważasz, że ten skrypt jest pomocny, rozważ wsparcie projektu:
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/B0B01KMW5G)
