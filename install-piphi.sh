#!/bin/bash

# Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS
# Wersja: 1.0
# Autor: [Twoje imię lub Grok-based]
# Data: 2 września 2025
# Opis: Instaluje PiPhi Network obok Helium Miner, z obsługą GPS dongle (U-Blox 7).
# Wymagania: balenaOS (testowane na 2.80.3+rev1), GPS dongle podłączony do USB, dostęp SSH jako root.

function install() {
    echo -e "Module: Instalacja PiPhi Network z obsługą GPS"
    echo -e "================================================================"
    
    if [[ "$USER" != "root" ]]; then
        echo -e "Musisz być zalogowany jako root. Użyj 'sudo su -'."
        exit 1
    fi
    
    echo -e "Sprawdzanie kontenerów Helium..."
    balena ps
    local helium_container=$(balena ps --format "{{.Names}}" | grep pktfwd_ || true)
    if [ -z "$helium_container" ]; then
        echo -e "Nie znaleziono kontenera Helium (pktfwd_). Sprawdź konfigurację SenseCAP M1."
        exit 1
    fi
    echo -e "Znaleziono kontener Helium: $helium_container"
    
    echo -e "Ładowanie modułu GPS (cdc-acm)..."
    modprobe cdc-acm
    ls /dev/ttyACM* || echo -e "GPS nie wykryty. Sprawdź podłączenie U-Blox 7."
    
    mkdir -p /home/user/piphi-network
    cd /home/user/piphi-network
    
    echo -e "Pobieranie docker-compose.yml..."
    curl -o docker-compose.yml https://chibisafe.piphi.network/m2JmK11Z7tor.yml
    
    echo -e "Modyfikacja docker-compose.yml dla obsługi GPS..."
    cat <<EOF >> docker-compose.yml.temp
devices:
  - "/dev/ttyACM0:/dev/ttyACM0"
environment:
  - GPS_DEVICE=/dev/ttyACM0
EOF
    cat docker-compose.yml docker-compose.yml.temp > docker-compose-updated.yml
    mv docker-compose-updated.yml docker-compose.yml
    rm docker-compose.yml.temp
    
    echo -e "Pobieranie obrazu Ubuntu..."
    balena pull ubuntu:20.04
    
    echo -e "Uruchamianie kontenera Ubuntu z PiPhi..."
    balena run -d --privileged -v /home/user/piphi-network:/piphi-network -p 31415:31415 --name ubuntu-piphi --restart unless-stopped ubuntu:20.04
    
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
    "
    
    echo -e "Restartowanie kontenerów..."
    balena restart ubuntu-piphi
    
    echo -e "Sprawdzanie instalacji..."
    balena ps
    balena exec ubuntu-piphi docker compose ps
    
    echo -e "Instalacja zakończona! Dostęp do PiPhi: http://<IP urządzenia>:31415"
    echo -e "Sprawdź GPS w Ubuntu: balena exec -it ubuntu-piphi cgps -s"
    echo -e "Logi PiPhi: balena exec ubuntu-piphi docker logs <nazwa_kontenera_piphi>"
}

echo -e ""
echo -e "================================================================"
echo -e "Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS"
echo -e "Wersja: 1.0 | Data: 2 września 2025"
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
