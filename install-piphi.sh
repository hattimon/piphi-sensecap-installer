#!/bin/bash

# PiPhi Network Installation Script for SenseCAP M1 with balenaOS
# Version: 2.12
# Author: hattimon (with assistance from Grok, xAI)
# Date: September 02, 2025, 08:30 PM CEST
# Description: Installs PiPhi Network alongside Helium Miner, with GPS dongle (U-Blox 7) support and automatic startup on reboot, ensuring PiPhi panel availability.
# Requirements: balenaOS (tested on 2.80.3+rev1), USB GPS dongle, SSH access as root.

# Load or set language from temporary file
if [ -f /tmp/language ]; then
    LANGUAGE=$(cat /tmp/language)
else
    LANGUAGE="en"
fi

# Function to set language and save to temporary file
function set_language() {
    if [ "$LANGUAGE" = "en" ]; then
        LANGUAGE="pl"
        echo -e "Język zmieniony na polski."
        echo "pl" > /tmp/language
    else
        LANGUAGE="en"
        echo -e "Language changed to English."
        echo "en" > /tmp/language
    fi
}

# Translation arrays
declare -A MESSAGES
MESSAGES[pl,header]="Moduł: Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
MESSAGES[pl,separator]="================================================================"
MESSAGES[pl,wget_missing]="Wget nie jest zainstalowany. Zainstaluj wget lub pobierz pliki ręcznie via scp."
MESSAGES[pl,changing_dir]="Zmiana katalogu na /mnt/data/piphi-network..."
MESSAGES[pl,dir_error]="Nie można zmienić katalogu na /mnt/data/piphi-network"
MESSAGES[pl,checking_helium]="Sprawdzanie kontenerów Helium..."
MESSAGES[pl,helium_not_found]="Nie znaleziono kontenera Helium (pktfwd_). Sprawdź konfigurację SenseCAP M1."
MESSAGES[pl,helium_found]="Znaleziono kontener Helium: %s"
MESSAGES[pl,loading_gps]="Ładowanie modułu GPS (cdc-acm) na hoście..."
MESSAGES[pl,gps_detected]="GPS wykryty: %s"
MESSAGES[pl,gps_not_detected]="GPS nie wykryty. Sprawdź podłączenie U-Blox 7 i uruchom 'lsusb'."
MESSAGES[pl,removing_old]="Usuwanie istniejących instalacji (kontenerów i danych), jeśli istnieją..."
MESSAGES[pl,downloading_compose]="Pobieranie docker-compose.yml..."
MESSAGES[pl,download_error]="Błąd pobierania docker-compose.yml"
MESSAGES[pl,verifying_compose]="Weryfikacja pobranego pliku docker-compose.yml..."
MESSAGES[pl,compose_invalid]="Pobrany plik docker-compose.yml jest nieprawidłowy lub nie zawiera usługi 'software'. Używanie domyślnego pliku."
MESSAGES[pl,pulling_ubuntu]="Pobieranie obrazu Ubuntu..."
MESSAGES[pl,pull_error]="Błąd pobierania obrazu Ubuntu"
MESSAGES[pl,running_container]="Uruchamianie kontenera Ubuntu z PiPhi..."
MESSAGES[pl,run_error]="Błąd uruchamiania kontenera Ubuntu"
MESSAGES[pl,waiting_container]="Czekanie na uruchomienie kontenera Ubuntu (maks. 30 sekund)..."
MESSAGES[pl,waiting_container_progress]="Czekanie na kontener Ubuntu... (%ds sekund)"
MESSAGES[pl,installing_deps]="Instalacja zależności w Ubuntu..."
MESSAGES[pl,deps_error]="Błąd instalacji podstawowych zależności"
MESSAGES[pl,installing_yq]="Instalacja yq do modyfikacji YAML..."
MESSAGES[pl,yq_error]="Błąd instalacji yq"
MESSAGES[pl,configuring_repo]="Konfiguracja repozytorium Dockera..."
MESSAGES[pl,repo_error]="Błąd aktualizacji po dodaniu repozytorium Dockera"
MESSAGES[pl,installing_docker]="Instalacja Dockera i docker-compose..."
MESSAGES[pl,docker_error]="Błąd instalacji Dockera"
MESSAGES[pl,configuring_daemon]="Konfiguracja automatycznego startu daemona Dockera..."
MESSAGES[pl,starting_daemon]="Uruchamianie daemona Dockera..."
MESSAGES[pl,waiting_daemon]="Czekanie na uruchomienie daemona Dockera (maks. 30 sekund)..."
MESSAGES[pl,daemon_success]="Daemon Dockera uruchomiony poprawnie."
MESSAGES[pl,waiting_daemon_progress]="Czekanie na daemon Dockera... (%ds sekund)"
MESSAGES[pl,daemon_error]="Błąd: Daemon Dockera nie uruchomił się w ciągu 30 sekund."
MESSAGES[pl,daemon_logs]="Sprawdź logi: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
MESSAGES[pl,starting_services]="Uruchamianie usług PiPhi (w tym panelu na porcie 31415)..."
MESSAGES[pl,attempt_services]="Próba uruchamiania usług (%d/%d)..."
MESSAGES[pl,services_success]="Usługi PiPhi uruchomione poprawnie. Czekanie na dostępność panelu..."
MESSAGES[pl,services_error]="Błąd podczas uruchamiania usług. Czekanie 10 sekund przed kolejną próbą..."
MESSAGES[pl,services_failed]="Błąd: Nie udało się uruchomić usług po 3 próbach."
MESSAGES[pl,services_logs]="Sprawdź logi: balena exec ubuntu-piphi docker logs piphi-network-image"
MESSAGES[pl,checking_network]="Sprawdzanie połączenia sieciowego..."
MESSAGES[pl,network_error]="Błąd połączenia z Docker Hub. Ustawianie DNS i ponawianie..."
MESSAGES[pl,restarting_container]="Restartowanie kontenera ubuntu-piphi..."
MESSAGES[pl,waiting_piphi]="Czekanie na dostępność panelu PiPhi na porcie 31415 (maks. 60 sekund)..."
MESSAGES[pl,piphi_success]="Panel PiPhi dostępny na http://<IP urządzenia>:31415!"
MESSAGES[pl,piphi_error]="Błąd: Panel PiPhi nie jest dostępny po 60 sekundach."
MESSAGES[pl,verifying_install]="Sprawdzanie instalacji..."
MESSAGES[pl,install_complete]="Instalacja zakończona! Panel PiPhi: http://<IP urządzenia>:31415"
MESSAGES[pl,grafana_access]="Dostęp do Grafana: http://<IP urządzenia>:3000"
MESSAGES[pl,gps_check]="Sprawdź GPS w Ubuntu: balena exec -it ubuntu-piphi cgps -s"
MESSAGES[pl,piphi_logs]="Logi PiPhi: balena exec ubuntu-piphi docker logs piphi-network-image"
MESSAGES[pl,docker_logs]="Logi Dockera: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
MESSAGES[pl,gps_note]="Uwaga: Umieść urządzenie na zewnątrz dla fix GPS (1–5 minut)."

MESSAGES[en,header]="Module: Installing PiPhi Network with GPS support and automatic startup"
MESSAGES[en,separator]="================================================================"
MESSAGES[en,wget_missing]="Wget is not installed. Install wget or download files manually via scp."
MESSAGES[en,changing_dir]="Changing directory to /mnt/data/piphi-network..."
MESSAGES[en,dir_error]="Cannot change directory to /mnt/data/piphi-network"
MESSAGES[en,checking_helium]="Checking Helium containers..."
MESSAGES[en,helium_not_found]="No Helium container (pktfwd_) found. Check SenseCAP M1 configuration."
MESSAGES[en,helium_found]="Found Helium container: %s"
MESSAGES[en,loading_gps]="Loading GPS module (cdc-acm) on the host..."
MESSAGES[en,gps_detected]="GPS detected: %s"
MESSAGES[en,gps_not_detected]="GPS not detected. Check U-Blox 7 connection and run 'lsusb'."
MESSAGES[en,removing_old]="Removing existing installations (containers and data) if they exist..."
MESSAGES[en,downloading_compose]="Downloading docker-compose.yml..."
MESSAGES[en,download_error]="Error downloading docker-compose.yml"
MESSAGES[en,verifying_compose]="Verifying downloaded docker-compose.yml..."
MESSAGES[en,compose_invalid]="Downloaded docker-compose.yml is invalid or does not contain 'software' service. Using default file."
MESSAGES[en,pulling_ubuntu]="Pulling Ubuntu image..."
MESSAGES[en,pull_error]="Error pulling Ubuntu image"
MESSAGES[en,running_container]="Running Ubuntu container with PiPhi..."
MESSAGES[en,run_error]="Error running Ubuntu container"
MESSAGES[en,waiting_container]="Waiting for Ubuntu container to start (max 30 seconds)..."
MESSAGES[en,waiting_container_progress]="Waiting for Ubuntu container... (%ds seconds)"
MESSAGES[en,installing_deps]="Installing dependencies in Ubuntu..."
MESSAGES[en,deps_error]="Error installing core dependencies"
MESSAGES[en,installing_yq]="Installing yq for YAML modification..."
MESSAGES[en,yq_error]="Error installing yq"
MESSAGES[en,configuring_repo]="Configuring Docker repository..."
MESSAGES[en,repo_error]="Error updating after adding Docker repository"
MESSAGES[en,installing_docker]="Installing Docker and docker-compose..."
MESSAGES[en,docker_error]="Error installing Docker"
MESSAGES[en,configuring_daemon]="Configuring automatic Docker daemon startup..."
MESSAGES[en,starting_daemon]="Starting Docker daemon..."
MESSAGES[en,waiting_daemon]="Waiting for Docker daemon to start (max 30 seconds)..."
MESSAGES[en,daemon_success]="Docker daemon started successfully."
MESSAGES[en,waiting_daemon_progress]="Waiting for Docker daemon... (%ds seconds)"
MESSAGES[en,daemon_error]="Error: Docker daemon failed to start within 30 seconds."
MESSAGES[en,daemon_logs]="Check logs: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
MESSAGES[en,starting_services]="Starting PiPhi services (including panel on port 31415)..."
MESSAGES[en,attempt_services]="Attempting to start services (%d/%d)..."
MESSAGES[en,services_success]="PiPhi services started successfully. Waiting for panel availability..."
MESSAGES[en,services_error]="Error starting services. Waiting 10 seconds before retrying..."
MESSAGES[en,services_failed]="Error: Failed to start services after 3 attempts."
MESSAGES[en,services_logs]="Check logs: balena exec ubuntu-piphi docker logs piphi-network-image"
MESSAGES[en,checking_network]="Checking network connectivity..."
MESSAGES[en,network_error]="Error connecting to Docker Hub. Setting DNS and retrying..."
MESSAGES[en,restarting_container]="Restarting ubuntu-piphi container..."
MESSAGES[en,waiting_piphi]="Waiting for PiPhi panel availability on port 31415 (max 60 seconds)..."
MESSAGES[en,piphi_success]="PiPhi panel available at http://<device IP>:31415!"
MESSAGES[en,piphi_error]="Error: PiPhi panel is not available after 60 seconds."
MESSAGES[en,verifying_install]="Verifying installation..."
MESSAGES[en,install_complete]="Installation complete! PiPhi panel: http://<device IP>:31415"
MESSAGES[en,grafana_access]="Access Grafana: http://<device IP>:3000"
MESSAGES[en,gps_check]="Check GPS in Ubuntu: balena exec -it ubuntu-piphi cgps -s"
MESSAGES[en,piphi_logs]="PiPhi logs: balena exec ubuntu-piphi docker logs piphi-network-image"
MESSAGES[en,docker_logs]="Docker logs: balena exec ubuntu-piphi cat /piphi-network/dockerd.log"
MESSAGES[en,gps_note]="Note: Place the device outdoors for GPS fix (1–5 minutes)."

# Function to display message
function msg() {
    local key=$1
    printf "${MESSAGES[$LANGUAGE,$key]}\n" "${@:2}"
}

# Function to wait for container to be in "Up" state
function wait_for_container() {
    local container_name=$1
    local max_wait=$2
    for i in $(seq 1 $((max_wait/5))); do
        if balena ps -a | grep "$container_name" | grep -q "Up"; then
            return 0
        fi
        msg "waiting_container_progress" $((i*5))
        sleep 5
    done
    return 1
}

# Installation function
function install() {
    msg "header"
    msg "separator"

    # Check for wget availability
    if ! command -v wget >/dev/null 2>&1; then
        msg "wget_missing"
        exit 1
    fi

    # Change directory to /mnt/data (writable)
    msg "changing_dir"
    mkdir -p /mnt/data/piphi-network
    cd /mnt/data/piphi-network || {
        msg "dir_error"
        exit 1
    }

    # Check for existing Helium containers
    msg "checking_helium"
    balena ps
    local helium_container=$(balena ps --format "{{.Names}}" | grep pktfwd_ || true)
    if [ -z "$helium_container" ]; then
        msg "helium_not_found"
        exit 1
    fi
    msg "helium_found" "$helium_container"

    # Load GPS module (U-Blox 7) on the host
    msg "loading_gps"
    modprobe cdc-acm
    if ls /dev/ttyACM* >/dev/null 2>&1; then
        msg "gps_detected" "$(ls /dev/ttyACM*)"
    else
        msg "gps_not_detected"
        exit 1
    fi

    # Remove existing installations to avoid conflicts
    msg "removing_old"
    balena stop ubuntu-piphi 2>/dev/null || true
    balena rm ubuntu-piphi 2>/dev/null || true
    rm -rf /mnt/data/piphi-network/* 2>/dev/null || true

    # Download docker-compose.yml from PiPhi link
    msg "downloading_compose"
    wget -O docker-compose.yml https://chibisafe.piphi.network/m2JmK11Z7tor.yml || {
        msg "download_error"
        exit 1
    }

    # Verify and update docker-compose.yml (remove version attribute)
    msg "verifying_compose"
    if ! grep -q "services:" docker-compose.yml || ! grep -q "software:" docker-compose.yml; then
        msg "compose_invalid"
        cat > docker-compose.yml << EOL
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
    else
        sed -i '/^version:/d' docker-compose.yml
    fi

    # Pull Ubuntu image
    msg "pulling_ubuntu"
    balena pull ubuntu:20.04 || {
        msg "pull_error"
        exit 1
    }

    # Run Ubuntu container with appropriate resources and automatic restart
    msg "running_container"
    balena run -d --privileged -v /mnt/data/piphi-network:/piphi-network -p 31415:31415 -p 5432:5432 -p 3000:3000 --cpus="2.0" --memory="2g" --name ubuntu-piphi --restart unless-stopped ubuntu:20.04 /bin/bash -c "/usr/local/bin/start-docker.sh && while true; do sleep 3600; done" || {
        msg "run_error"
        exit 1
    }

    # Wait for the container to fully start
    msg "waiting_container"
    if ! wait_for_container "ubuntu-piphi" 30; then
        msg "run_error"
        exit 1
    fi

    # Configure inside the Ubuntu container
    msg "installing_deps"
    balena exec ubuntu-piphi apt-get update || {
        msg "deps_error"
        exit 1
    }
    balena exec ubuntu-piphi apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ca-certificates curl gnupg lsb-release usbutils gpsd gpsd-clients iputils-ping || {
        msg "deps_error"
        exit 1
    }

    msg "installing_yq"
    balena exec ubuntu-piphi bash -c 'curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64 -o /usr/bin/yq && chmod +x /usr/bin/yq' || {
        msg "yq_error"
        exit 1
    }

    msg "configuring_repo"
    balena exec ubuntu-piphi mkdir -p /etc/apt/keyrings
    balena exec ubuntu-piphi bash -c 'rm -f /etc/apt/sources.list.d/docker.list'
    balena exec ubuntu-piphi bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
    balena exec ubuntu-piphi bash -c 'echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list'
    balena exec ubuntu-piphi apt-get update || {
        msg "repo_error"
        exit 1
    }

    msg "installing_docker"
    balena exec ubuntu-piphi apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" docker-ce docker-ce-cli containerd.io docker-compose-plugin || {
        msg "docker_error"
        exit 1
    }

    # Create startup script for Docker daemon and services
    msg "configuring_daemon"
    balena exec ubuntu-piphi bash -c 'echo "#!/bin/bash" > /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "nohup dockerd --host=unix:///var/run/docker.sock --storage-driver=vfs > /piphi-network/dockerd.log 2>&1 &" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "sleep 10" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "cd /piphi-network && docker compose pull" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "sleep 5" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'echo "cd /piphi-network && docker compose up -d" >> /usr/local/bin/start-docker.sh'
    balena exec ubuntu-piphi bash -c 'chmod +x /usr/local/bin/start-docker.sh'

    # Start Docker daemon
    msg "starting_daemon"
    balena exec ubuntu-piphi /usr/local/bin/start-docker.sh
    msg "waiting_daemon"
    for i in {1..6}; do
        if balena exec ubuntu-piphi bash -c "docker info" > /dev/null 2>&1; then
            msg "daemon_success"
            break
        fi
        msg "waiting_daemon_progress" $((i*5))
        sleep 5
        if [ $i -eq 6 ]; then
            msg "daemon_error"
            msg "daemon_logs"
            exit 1
        fi
    done

    # Start PiPhi services with network retry
    msg "starting_services"
    for attempt in {1..3}; do
        msg "attempt_services" $attempt 3
        if balena exec ubuntu-piphi bash -c "cd /piphi-network && docker compose pull && docker compose up -d"; then
            msg "services_success"
            break
        else
            msg "checking_network"
            balena exec ubuntu-piphi bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
            if balena exec ubuntu-piphi curl -I https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
                continue
            else
                msg "network_error"
                sleep 10
                if [ $attempt -eq 3 ]; then
                    msg "services_failed"
                    msg "services_logs"
                    exit 1
                fi
            fi
        fi
    done

    # Wait for PiPhi panel availability
    msg "waiting_piphi"
    for i in {1..12}; do
        if balena exec ubuntu-piphi bash -c "nc -z 127.0.0.1 31415" 2>/dev/null; then
            msg "piphi_success"
            break
        fi
        msg "waiting_daemon_progress" $((i*5))
        sleep 5
        if [ $i -eq 12 ]; then
            msg "piphi_error"
            exit 1
        fi
    done

    # Restart container to apply changes
    msg "restarting_container"
    balena restart ubuntu-piphi

    # Verification
    msg "verifying_install"
    balena ps
    balena exec ubuntu-piphi docker compose ps

    # Verify GPS (optional check)
    if balena exec ubuntu-piphi bash -c "cgps -s" 2>/dev/null; then
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "GPS działa poprawnie."
        else
            echo -e "GPS is working correctly."
        fi
    else
        if [ "$LANGUAGE" = "pl" ]; then
            echo -e "Uwaga: GPS wymaga fixu. Umieść urządzenie na zewnątrz (1–5 minut)."
        else
            echo -e "Note: GPS requires a fix. Place the device outdoors (1–5 minutes)."
        fi
    fi

    msg "install_complete"
    msg "grafana_access"
    msg "gps_check"
    msg "piphi_logs"
    msg "docker_logs"
    msg "gps_note"
}

# Main menu
echo -e ""
msg "separator"
if [ "$LANGUAGE" = "pl" ]; then
    echo -e "Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS"
    echo -e "Wersja: 2.12 | Data: 02 września 2025, 20:30 CEST"
    echo -e "================================================================"
    echo -e "1 - Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
    echo -e "2 - Wyjście"
    echo -e "3 - Zmień na język Angielski"
else
    echo -e "PiPhi Network Installation Script for SenseCAP M1 with balenaOS"
    echo -e "Version: 2.12 | Date: September 02, 2025, 08:30 PM CEST"
    echo -e "================================================================"
    echo -e "1 - Install PiPhi Network with GPS support and automatic startup"
    echo -e "2 - Exit"
    echo -e "3 - Change to Polish language"
fi
msg "separator"
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
        set_language
        clear
        sleep 1
        # Recursive call to show updated menu
        . "$0"
        ;;
esac
