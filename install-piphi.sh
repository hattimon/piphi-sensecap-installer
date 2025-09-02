#!/bin/bash

# Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS
# Wersja: 2.12
# Autor: hattimon (z pomocą Grok, xAI)
# Data: September 02, 2025
# Opis: Instaluje PiPhi Network obok Helium Miner, z obsługą GPS dongle (U-Blox 7) i automatycznym startem po restarcie.
# Wymagania: balenaOS (testowane na 2.80.3+rev1), GPS dongle USB, dostęp SSH jako root.

# Funkcja instalacji
function install() {
    echo -e "Module: Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
    echo -e "================================================================"
    
    # Sprawdź dostępność wget
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "Wget nie jest zainstalowany. Zainstaluj wget lub pobierz pliki ręcznie via scp."
        exit 1
    fi
    
    # Zmień katalog na /mnt/data (zapisywalny)
    echo -e "Zmiana katalogu na /mnt/data/piphi-network..."
    mkdir -p /mnt/data/piphi-network
    cd /mnt/data/piphi-network || { echo -e "Nie można zmienić katalogu na /mnt/data/piphi-network"; exit 1; }
    
    # Sprawdź istniejące kontenery Helium
    echo -e "Sprawdzanie kontenerów Helium..."
    balena ps
    local helium_container=$(balena ps --format "{{.Names}}" | grep pktfwd_ || true)
    if [ -z "$helium_container" ]; then
        echo -e "Nie znaleziono kontenera Helium (pktfwd_). Sprawdź konfigurację SenseCAP M1."
        exit 1
    fi
    echo -e "Znaleziono kontener Helium: $helium_container"
    
    # Ładowanie modułu GPS (U-Blox 7) na hoście
    echo -e "Ładowanie modułu GPS (cdc-acm) na hoście..."
    modprobe cdc-acm
    if ls /dev/ttyACM* >/dev/null 2>&1; then
        echo -e "GPS wykryty: $(ls /dev/ttyACM*)"
    else
        echo -e "GPS nie wykryty. Sprawdź podłączenie U-Blox 7 i uruchom 'lsusb'."
        exit 1
    fi
    
    # Pobierz docker-compose.yml z linku PiPhi
    echo -e "Pobieranie docker-compose.yml..."
    wget -O docker-compose.yml https://chibisafe.piphi.network/m2JmK11Z7tor.yml || { echo -e "Błąd pobierania docker-compose.yml"; exit 1; }
    
    # Weryfikacja poprawności docker-compose.yml
    echo -e "Weryfikacja pobranego pliku docker-compose.yml..."
    if ! grep -q "services:" docker-compose.yml || ! grep -q "software:" docker-compose.yml; then
        echo -e "Pobrany plik docker-compose.yml jest nieprawidłowy lub nie zawiera usługi 'software'. Używanie domyślnego pliku."
        cat > docker-compose.yml << EOL
version: '3.3'
services:
  db:
    container_name: db
    image: postgres:13.3
    restart: always
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=piphi31415
      - POSTGRES_DB=postgres
      - POSTGRES_NAME=postgres
    ports:
      - "5432:5432"
    volumes:
      - db:/var/lib/postgresql/data
      - /etc/localtime:/etc/localtime:ro
    network_mode: host
  software:
    container_name: piphi-network-image
    restart: on-failure
    pull_policy: always
    image: piphinetwork/team-piphi:latest
    ports:
      - "31415:31415"
    depends_on:
      - db
    privileged: true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/dbus:/var/run/dbus
    devices:
      - "/dev/ttyACM0:/dev/ttyACM0"
    environment:
      - "GPS_DEVICE=/dev/ttyACM0"
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    network_mode: host
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: always
    command: --interval 300
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_LABEL_ENABLE=true
      - WATCHTOWER_INCLUDE_RESTARTING=true
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    network_mode: host
  grafana:
    container_name: grafana
    image: grafana/grafana-oss
    ports:
      - "3000:3000"
    volumes:
      - grafana:/var/lib/grafana
    restart: unless-stopped
volumes:
  db:
    driver: local
  grafana:
    driver: local
EOL
    fi
    
    # Usuń istniejący kontener ubuntu-piphi, jeśli istnieje
    echo -e "Usuwanie istniejącego kontenera ubuntu-piphi, jeśli istnieje..."
    balena stop ubuntu-piphi 2>/dev/null || true
    balena rm ubuntu-piphi 2>/dev/null || true
    
    # Pobierz obraz Ubuntu
    echo -e "Pobieranie obrazu Ubuntu..."
    balena pull ubuntu:20.04 || { echo -e "Błąd pobierania obrazu Ubuntu"; exit 1; }
    
    # Uruchom kontener Ubuntu z odpowiednimi zasobami i automatycznym restartem
    echo -e "Uruchamianie kontenera Ubuntu z PiPhi..."
    balena run -d --privileged -v /mnt/data/piphi-network:/piphi-network -p 31415:31415 -p 5432:5432 -p 3000:3000 --cpus="2.0" --memory="2g" --name ubuntu-piphi --restart unless-stopped ubuntu:20.04 /bin/bash -c "while true; do sleep 3600; done" || { echo -e "Błąd uruchamiania kontenera Ubuntu"; exit 1; }
    
    # Poczekaj, aż kontener będzie w pełni uruchomiony
    echo -e "Czekanie na uruchomienie kontenera Ubuntu (5 sekund)..."
    sleep 5
    
    # Konfiguracja strefy czasowej w sposób nieinteraktywny
    echo -e "Konfiguracja strefy czasowej (domyślnie Europe/Warsaw)..."
    read -rp "Wpisz strefę czasową (np. Europe/Warsaw) lub naciśnij ENTER dla domyślnej: " timezone
    if [ -z "$timezone" ]; then
        timezone="Europe/Warsaw"
    fi
    balena exec ubuntu-piphi bash -c "apt-get update && apt-get install -y tzdata && echo '$timezone' > /etc/timezone && ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && dpkg-reconfigure -f noninteractive tzdata" || { echo -e "Błąd konfiguracji strefy czasowej"; exit 1; }
    
    # Konfiguracja w kontenerze Ubuntu
    echo -e "Instalacja zależności w Ubuntu..."
    balena exec ubuntu-piphi apt-get update || { echo -e "Błąd aktualizacji pakietów w Ubuntu"; exit 1; }
    balena exec ubuntu-piphi apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ca-certificates curl gnupg lsb-release usbutils gpsd gpsd-clients iputils-ping || { echo -e "Błąd instalacji podstawowych zależności"; exit 1; }
    
    echo -e "Instalacja yq do modyfikacji YAML..."
    balena exec ubuntu-piphi bash -c 'curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64 -o /usr/bin/yq && chmod +x /usr/bin/yq' || { echo -e "Błąd instalacji yq"; exit 1; }
    
    echo -e "Konfiguracja repozytorium Dockera..."
    balena exec ubuntu-piphi mkdir -p /etc/apt/keyrings
    balena exec ubuntu-piphi bash -c 'rm -f /etc/apt/sources.list.d/docker.list'
    balena exec ubuntu-piphi bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
    balena exec ubuntu-piphi bash -c 'echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list'
    balena exec ubuntu-piphi apt-get update || { echo -e "Błąd aktualizacji po dodaniu repozytorium Dockera"; exit 1; }
    
    echo -e "Instalacja Dockera i docker-compose..."
    balena exec ubuntu-piphi apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" docker-ce docker-ce-cli containerd.io docker-compose-plugin || { echo -e "Błąd instalacji Dockera"; exit 1; }
    
    # Utwórz skrypt startowy dla daemona Dockera
    echo -e "Konfiguracja automatycznego startu daemona Dockera..."
    balena exec ubuntu-piphi bash -c 'echo "#!/bin/bash" > /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "nohup dockerd --host=unix:///var/run/docker.sock --storage-driver=vfs > /piphi-network/dockerd.log 2>&1 &" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'chmod +x /usr/local/bin/start-docker.sh'
    
    # Uruchom daemon Dockera
    echo -e "Uruchamianie daemona Dockera..."
    balena exec ubuntu-piphi /usr/local/bin/start-docker.sh
    echo -e "Czekanie na uruchomienie daemona Dockera (maks. 30 sekund)..."
    for i in {1..6}; do
        if balena exec ubuntu-piphi bash -c "docker info" > /dev/null 2>&1; then
            echo -e "Daemon Dockera uruchomiony poprawnie."
            break
        fi
        echo -e "Czekanie na daemon Dockera... ($((i*5)) sekund)"
        sleep 5
        if [ $i -eq 6 ]; then
            echo -e "Błąd: Daemon Dockera nie uruchomił się w ciągu 30 sekund."
            echo -e "Sprawdź logi: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
            exit 1
        fi
    done
    
    # Uruchom usługi PiPhi
    echo -e "Uruchamianie usług PiPhi..."
    balena exec ubuntu-piphi bash -c "cd /piphi-network && docker compose pull"
    for attempt in {1..3}; do
        echo -e "Próba uruchamiania usług ($attempt/3)..."
        if balena exec ubuntu-piphi bash -c "cd /piphi-network && docker compose up -d"; then
            echo -e "Usługi PiPhi uruchomione poprawnie."
            break
        else
            echo -e "Błąd podczas uruchamiania usług. Czekanie 10 sekund przed kolejną próbą..."
            sleep 10
            if [ $attempt -eq 3 ]; then
                echo -e "Błąd: Nie udało się uruchomić usług po 3 próbach."
                echo -e "Sprawdź logi: balena exec ubuntu-piphi docker logs piphi-network-image"
                exit 1
            fi
        fi
    done
    
    # Sprawdź połączenie sieciowe
    echo -e "Sprawdzanie połączenia sieciowego..."
    balena exec ubuntu-piphi curl -I https://registry-1.docker.io/v2/ || { echo -e "Błąd połączenia z Docker Hub. Sprawdź sieć i spróbuj ponownie."; exit 1; }
    
    # Restartuj kontener dla zastosowania zmian
    echo -e "Restartowanie kontenera ubuntu-piphi..."
    balena restart ubuntu-piphi
    
    # Weryfikacja
    echo -e "Sprawdzanie instalacji..."
    balena ps
    balena exec ubuntu-piphi docker compose ps
    
    echo -e "Instalacja zakończona! Dostęp do PiPhi: http://<IP urządzenia>:31415"
    echo -e "Dostęp do Grafana: http://<IP urządzenia>:3000"
    echo -e "Sprawdź GPS w Ubuntu: balena exec -it ubuntu-piphi cgps -s"
    echo -e "Logi PiPhi: balena exec ubuntu-piphi docker logs piphi-network-image"
    echo -e "Logi Dockera: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
    echo -e "Uwaga: Umieść urządzenie na zewnątrz dla fix GPS (1–5 minut)."
}

# Menu główne
echo -e ""
echo -e "================================================================"
echo -e "Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS"
echo -e "Wersja: 2.12 | Data: September 02, 2025"
echo -e "================================================================"
echo -e "1 - Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
echo -e "2 - Wyjście"
echo -e "================================================================"
read -rp "Wybierz opcję i naciśnij ENTER: "
case "$REPLY" in
  1)
    clear
    sleep 1
    install
    ;;
  2)
    clear
    sleep 1
    exit
    ;;
esac
