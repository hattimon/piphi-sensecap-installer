#!/bin/bash

# Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS
# Wersja: 1.4
# Autor: hattimon (z pomocą Grok, xAI)
# Data: September 02, 2025
# Opis: Instaluje PiPhi Network obok Helium Miner, z obsługą GPS dongle (U-Blox 7).
# Wymagania: balenaOS (testowane na 2.80.3+rev1), GPS dongle USB, dostęp SSH jako root.

# Funkcja instalacji
function install() {
    echo -e "Module: Instalacja PiPhi Network z obsługą GPS"
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
    
    # Ładowanie modułu GPS (U-Blox 7)
    echo -e "Ładowanie modułu GPS (cdc-acm)..."
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
    
    # Modyfikacja docker-compose.yml dla GPS i optymalizacji zasobów
    echo -e "Modyfikacja docker-compose.yml dla obsługi GPS..."
    cat <<EOF >> docker-compose.yml.temp
devices:
  - "/dev/ttyACM0:/dev/ttyACM0"
environment:
  - GPS_DEVICE=/dev/ttyACM0
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
EOF
    cat docker-compose.yml docker-compose.yml.temp > docker-compose-updated.yml
    mv docker-compose-updated.yml docker-compose.yml
    rm docker-compose.yml.temp
    
    # Pobierz obraz Ubuntu
    echo -e "Pobieranie obrazu Ubuntu..."
    balena pull ubuntu:20.04 || { echo -e "Błąd pobierania obrazu Ubuntu"; exit 1; }
    
    # Uruchom kontener Ubuntu w tle z obsługą GPS
    echo -e "Uruchamianie kontenera Ubuntu z PiPhi..."
    balena run -d --privileged -v /mnt/data/piphi-network:/piphi-network -p 31415:31415 --name ubuntu-piphi --restart unless-stopped ubuntu:20.04
    
    # Wejdź do kontenera Ubuntu i zainstaluj zależności
    echo -e "Konfiguracja w kontenerze Ubuntu... (to zajmie chwilę)"
    balena exec -it ubuntu-piphi /bin/bash -c "
        apt-get update && apt-get upgrade -y
        apt-get install -y ca-certificates curl gnupg lsb-release usbutils gpsd gpsd-clients
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable' | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        apt-get install -y docker-compose-plugin
        modprobe cdc-acm
        gpsd /dev/ttyACM0
        cd /piphi-network
        docker compose pull
        docker compose up -d
    " || { echo -e "Błąd konfiguracji w Ubuntu"; exit 1; }
    
    # Restartuj kontenery
    echo -e "Restartowanie kontenerów..."
    balena restart ubuntu-piphi
    
    # Weryfikacja
    echo -e "Sprawdzanie instalacji..."
    balena ps
    balena exec ubuntu-piphi docker compose ps
    
    echo -e "Instalacja zakończona! Dostęp do PiPhi: http://<IP urządzenia>:31415"
    echo -e "Sprawdź GPS w Ubuntu: balena exec -it ubuntu-piphi cgps -s"
    echo -e "Logi PiPhi: balena exec ubuntu-piphi docker logs <nazwa_kontenera_piphi>"
    echo -e "Uwaga: Umieść urządzenie na zewnątrz dla fix GPS (1–5 minut)."
}

# Menu główne
echo -e ""
echo -e "================================================================"
echo -e "Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS"
echo -e "Wersja: 1.4 | Data: September 02, 2025"
echo -e "================================================================"
echo -e "1 - Instalacja PiPhi Network z obsługą GPS"
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
