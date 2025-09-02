#!/bin/bash

# PiPhi Network Installation Script for SenseCAP M1 with balenaOS
# Version: 2.12
# Author: hattimon (with assistance from Grok, xAI)
# Date: September 02, 2025
# Description: Installs PiPhi Network alongside Helium Miner, with GPS dong Hawkins dongle (U-Blox 7) support and automatic startup on reboot.
# Requirements: balenaOS (tested on 2.80.3+rev1), USB GPS dongle, SSH access as root.

# Language setting (default: English)
LANGUAGE="en"

# Function to set language to Polish
function set_polish() {
    LANGUAGE="pl"
    echo -e "Język zmieniony na polski."
}

# Installation function
function install() {
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Moduł: Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
        echo -e "================================================================"
    else
        echo -e "Module: Installing PiPhi Network with GPS support and automatic startup"
        echo -e "================================================================"
    fi
    
    # Check for wget availability
    if ! command -v wget >/dev/null 2>&1; then
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Wget nie jest zainstalowany. Zainstaluj wget lub pobierz pliki ręcznie via scp."
        else
            echo -e "Wget is not installed. Install wget or download files manually via scp."
        fi
        exit 1
    fi
    
    # Change directory to /mnt/data (writable)
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Zmiana katalogu na /mnt/data/piphi-network..."
    else
        echo -e "Changing directory to /mnt/data/piphi-network..."
    fi
    mkdir -p /mnt/data/piphi-network
    cd /mnt/data/piphi-network || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Nie można zmienić katalogu na /mnt/data/piphi-network"
        else
            echo -e "Cannot change directory to /mnt/data/piphi-network"
        fi
        exit 1
    }
    
    # Check for existing Helium containers
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Sprawdzanie kontenerów Helium..."
    else
        echo -e "Checking Helium containers..."
    fi
    balena ps
    local helium_container=$(balena ps --format "{{.Names}}" | grep pktfwd_ || true)
    if [ -z "$helium_container" ]; then
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Nie znaleziono kontenera Helium (pktfwd_). Sprawdź konfigurację SenseCAP M1."
        else
            echo -e "No Helium container (pktfwd_) found. Check SenseCAP M1 configuration."
        fi
        exit 1
    fi
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Znaleziono kontener Helium: $helium_container"
    else
        echo -e "Found Helium container: $helium_container"
    fi
    
    # Load GPS module (U-Blox 7) on the host
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Ładowanie modułu GPS (cdc-acm) na hoście..."
    else
        echo -e "Loading GPS module (cdc-acm) on the host..."
    fi
    modprobe cdc-acm
    if ls /dev/ttyACM* >/dev/null 2>&1; then
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "GPS wykryty: $(ls /dev/ttyACM*)"
        else
            echo -e "GPS detected: $(ls /dev/ttyACM*)"
        fi
    else
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "GPS nie wykryty. Sprawdź podłączenie U-Blox 7 i uruchom 'lsusb'."
        else
            echo -e "GPS not detected. Check U-Blox 7 connection and run 'lsusb'."
        fi
        exit 1
    fi
    
    # Download docker-compose.yml from PiPhi link
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Pobieranie docker-compose.yml..."
    else
        echo -e "Downloading docker-compose.yml..."
    fi
    wget -O docker-compose.yml https://chibisafe.piphi.network/m2JmK11Z7tor.yml || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd pobierania docker-compose.yml"
        else
            echo -e "Error downloading docker-compose.yml"
        fi
        exit 1
    }
    
    # Verify the correctness of docker-compose.yml
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Weryfikacja pobranego pliku docker-compose.yml..."
    else
        echo -e "Verifying downloaded docker-compose.yml..."
    fi
    if ! grep -q "services:" docker-compose.yml || ! grep -q "software:" docker-compose.yml; then
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Pobrany plik docker-compose.yml jest nieprawidłowy lub nie zawiera usługi 'software'. Używanie domyślnego pliku."
        else
            echo -e "Downloaded docker-compose.yml is invalid or does not contain 'software' service. Using default file."
        fi
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
    
    # Remove existing ubuntu-piphi container if it exists
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Usuwanie istniejącego kontenera ubuntu-piphi, jeśli istnieje..."
    else
        echo -e "Removing existing ubuntu-piphi container if it exists..."
    fi
    balena stop ubuntu-piphi 2>/dev/null || true
    balena rm ubuntu-piphi 2>/dev/null || true
    
    # Pull Ubuntu image
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Pobieranie obrazu Ubuntu..."
    else
        echo -e "Pulling Ubuntu image..."
    fi
    balena pull ubuntu:20.04 || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd pobierania obrazu Ubuntu"
        else
            echo -e "Error pulling Ubuntu image"
        fi
        exit 1
    }
    
    # Run Ubuntu container with appropriate resources and automatic restart
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Uruchamianie kontenera Ubuntu z PiPhi..."
    else
        echo -e "Running Ubuntu container with PiPhi..."
    fi
    balena run -d --privileged -v /mnt/data/piphi-network:/piphi-network -p 31415:31415 -p 5432:5432 -p 3000:3000 --cpus="2.0" --memory="2g" --name ubuntu-piphi --restart unless-stopped ubuntu:20.04 /bin/bash -c "while true; do sleep 3600; done" || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd uruchamiania kontenera Ubuntu"
        else
            echo -e "Error running Ubuntu container"
        fi
        exit 1
    }
    
    # Wait for the container to fully start
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Czekanie na uruchomienie kontenera Ubuntu (5 sekund)..."
    else
        echo -e "Waiting for Ubuntu container to start (5 seconds)..."
    fi
    sleep 5
    
    # Configure timezone non-interactively
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Konfiguracja strefy czasowej (domyślnie Europe/Warsaw)..."
        read -rp "Wpisz strefę czasową (np. Europe/Warsaw) lub naciśnij ENTER dla domyślnej: " timezone
    else
        echo -e "Configuring timezone (default: Europe/Warsaw)..."
        read -rp "Enter timezone (e.g., Europe/Warsaw) or press ENTER for default: " timezone
    fi
    if [ -z "$timezone" ]; then
        timezone="Europe/Warsaw"
    fi
    balena exec ubuntu-piphi bash -c "apt-get update && apt-get install -y tzdata && echo '$timezone' > /etc/timezone && ln -sf /usr/share/zoneinfo/$timezone /etc/localtime && dpkg-reconfigure -f noninteractive tzdata" || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd konfiguracji strefy czasowej"
        else
            echo -e "Error configuring timezone"
        fi
        exit 1
    }
    
    # Configure inside the Ubuntu container
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Instalacja zależności w Ubuntu..."
    else
        echo -e "Installing dependencies in Ubuntu..."
    fi
    balena exec ubuntu-piphi apt-get update || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd aktualizacji pakietów w Ubuntu"
        else
            echo -e "Error updating packages in Ubuntu"
        fi
        exit 1
    }
    balena exec ubuntu-piphi apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ca-certificates curl gnupg lsb-release usbutils gpsd gpsd-clients iputils-ping || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd instalacji podstawowych zależności"
        else
            echo -e "Error installing core dependencies"
        fi
        exit 1
    }
    
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Instalacja yq do modyfikacji YAML..."
    else
        echo -e "Installing yq for YAML modification..."
    fi
    balena exec ubuntu-piphi bash -c 'curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64 -o /usr/bin/yq && chmod +x /usr/bin/yq' || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd instalacji yq"
        else
            echo -e "Error installing yq"
        fi
        exit 1
    }
    
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Konfiguracja repozytorium Dockera..."
    else
        echo -e "Configuring Docker repository..."
    fi
    balena exec ubuntu-piphi mkdir -p /etc/apt/keyrings
    balena exec ubuntu-piphi bash -c 'rm -f /etc/apt/sources.list.d/docker.list'
    balena exec ubuntu-piphi bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
    balena exec ubuntu-piphi bash -c 'echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list'
    balena exec ubuntu-piphi apt-get update || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd aktualizacji po dodaniu repozytorium Dockera"
        else
            echo -e "Error updating after adding Docker repository"
        fi
        exit 1
    }
    
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Instalacja Dockera i docker-compose..."
    else
        echo -e "Installing Docker and docker-compose..."
    fi
    balena exec ubuntu-piphi apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" docker-ce docker-ce-cli containerd.io docker-compose-plugin || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd instalacji Dockera"
        else
            echo -e "Error installing Docker"
        fi
        exit 1
    }
    
    # Create startup script for Docker daemon
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Konfiguracja automatycznego startu daemona Dockera..."
    else
        echo -e "Configuring automatic Docker daemon startup..."
    fi
    balena exec ubuntu-piphi bash -c 'echo "#!/bin/bash" > /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "nohup dockerd --host=unix:///var/run/docker.sock --storage-driver=vfs > /piphi-network/dockerd.log 2>&1 &" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'chmod +x /usr/local/bin/start-docker.sh'
    
    # Start Docker daemon
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Uruchamianie daemona Dockera..."
    else
        echo -e "Starting Docker daemon..."
    fi
    balena exec ubuntu-piphi /usr/local/bin/start-docker.sh
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Czekanie na uruchomienie daemona Dockera (maks. 30 sekund)..."
    else
        echo -e "Waiting for Docker daemon to start (max 30 seconds)..."
    fi
    for i in {1..6}; do
        if balena exec ubuntu-piphi bash -c "docker info" > /dev/null 2>&1; then
            if [ "$LANGUAGE" = "pl" ]; then
                echo -e "Daemon Dockera uruchomiony poprawnie."
            else
                echo -e "Docker daemon started successfully."
            fi
            break
        fi
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Czekanie na daemon Dockera... ($((i*5)) sekund)"
        else
            echo -e "Waiting for Docker daemon... ($((i*5)) seconds)"
        fi
        sleep 5
        if [ $i -eq 6 ]; then
            if [ "$LANGUAGE" = "pl" ]; then
                echo -e "Błąd: Daemon Dockera nie uruchomił się w ciągu 30 sekund."
                echo -e "Sprawdź logi: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
            else
                echo -e "Error: Docker daemon failed to start within 30 seconds."
                echo -e "Check logs: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
            fi
            exit 1
        fi
    done
    
    # Start PiPhi services
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Uruchamianie usług PiPhi..."
    else
        echo -e "Starting PiPhi services..."
    fi
    balena exec ubuntu-piphi bash -c "cd /piphi-network && docker compose pull"
    for attempt in {1..3}; do
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Próba uruchamiania usług ($attempt/3)..."
        else
            echo -e "Attempting to start services ($attempt/3)..."
        fi
        if balena exec ubuntu-piphi bash -c "cd /piphi-network && docker compose up -d"; then
            if [ "$LANGUAGE" = "pl" ]; then
                echo -e "Usługi PiPhi uruchomione poprawnie."
            else
                echo -e "PiPhi services started successfully."
            fi
            break
        else
            if [ "$LANGUAGE" = "pl" ]; then
                echo -e "Błąd podczas uruchamiania usług. Czekanie 10 sekund przed kolejną próbą..."
            else
                echo -e "Error starting services. Waiting 10 seconds before retrying..."
            fi
            sleep 10
            if [ $attempt -eq 3 ]; then
                if [ "$LANGUAGE" = "pl" ]; then
                    echo -e "Błąd: Nie udało się uruchomić usług po 3 próbach."
                    echo -e "Sprawdź logi: balena exec ubuntu-piphi docker logs piphi-network-image"
                else
                    echo -e "Error: Failed to start services after 3 attempts."
                    echo -e "Check logs: balena exec ubuntu-piphi docker logs piphi-network-image"
                fi
                exit 1
            fi
        fi
    done
    
    # Check network connectivity
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Sprawdzanie połączenia sieciowego..."
    else
        echo -e "Checking network connectivity..."
    fi
    balena exec ubuntu-piphi curl -I https://registry-1.docker.io/v2/ || { 
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Błąd połączenia z Docker Hub. Sprawdź sieć i spróbuj ponownie."
        else
            echo -e "Error connecting to Docker Hub. Check network and try again."
        fi
        exit 1
    }
    
    # Restart container to apply changes
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Restartowanie kontenera ubuntu-piphi..."
    else
        echo -e "Restarting ubuntu-piphi container..."
    fi
    balena restart ubuntu-piphi
    
    # Verification
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Sprawdzanie instalacji..."
    else
        echo -e "Verifying installation..."
    fi
    balena ps
    balena exec ubuntu-piphi docker compose ps
    
    if [ "$LANGUAGE" = "pl" ]; then
        echo -e "Instalacja zakończona! Dostęp do PiPhi: http://<IP urządzenia>:31415"
        echo -e "Dostęp do Grafana: http://<IP urządzenia>:3000"
        echo -e "Sprawdź GPS w Ubuntu: balena exec -it ubuntu-piphi cgps -s"
        echo -e "Logi PiPhi: balena exec ubuntu-piphi docker logs piphi-network-image"
        echo -e "Logi Dockera: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
        echo -e "Uwaga: Umieść urządzenie na zewnątrz dla fix GPS (1–5 minut)."
    else
        echo -e "Installation complete! Access PiPhi: http://<device IP>:31415"
        echo -e "Access Grafana: http://<device IP>:3000"
        echo -e "Check GPS in Ubuntu: balena exec -it ubuntu-piphi cgps -s"
        echo -e "PiPhi logs: balena exec ubuntu-piphi docker logs piphi-network-image"
        echo -e "Docker logs: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
        echo -e "Note: Place the device outdoors for GPS fix (1–5 minutes)."
    fi
}

# Main menu
echo -e ""
echo -e "================================================================"
echo -e "PiPhi Network Installation Script for SenseCAP M1 with balenaOS"
echo -e "Version: 2.12 | Date: September 02, 2025"
echo -e "================================================================"
echo -e "1 - Install PiPhi Network with GPS support and automatic startup"
echo -e "2 - Exit"
echo -e "3 - Change language to Polish"
echo -e "================================================================"
read -rp "Select an option and press ENTER: "
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
  3)
    clear
    sleep 1
    set_polish
    clear
    sleep 1
    echo -e "================================================================"
    echo -e "Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS"
    echo -e "Wersja: 2.12 | Data: September 02, 2025"
    echo -e "================================================================"
    echo -e "1 - Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
    echo -e "2 - Wyjście"
    echo -e "3 - Zmień język na angielski"
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
      3)
        clear
        sleep 1
        LANGUAGE="en"
        echo -e "Language changed to English."
        clear
        sleep 1
        echo -e "================================================================"
        echo -e "PiPhi Network Installation Script for SenseCAP M1 with balenaOS"
        echo -e "Version: 2.12 | Date: September 02, 2025"
        echo -e "================================================================"
        echo -e "1 - Install PiPhi Network with GPS support and automatic startup"
        echo -e "2 - Exit"
        echo -e "3 - Change language to Polish"
        echo -e "================================================================"
        read -rp "Select an option and press ENTER: "
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
          3)
            clear
            sleep 1
            set_polish
            ;;
        esac
        ;;
    esac
    ;;
esac
