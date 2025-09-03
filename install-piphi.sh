#!/bin/bash

# Ustawienia początkowe
DATE=$(date +"%Y-%m-%d %H:%M %Z")
LANGUAGE="en"
CONTAINER_NAME="ubuntu-piphi"
DOCKER_COMPOSE_URL="https://chibisafe.piphi.network/docker-compose.yml"

# Funkcja wyświetlania menu
show_menu() {
    clear
    if [ "$LANGUAGE" = "pl" ]; then
        echo "================================================================"
        echo "Skrypt instalacyjny PiPhi Network na SenseCAP M1 z balenaOS"
        echo "Wersja: 2.27 | Data: $DATE"
        echo "================================================================"
        echo "1 - Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
        echo "2 - Wyjście"
        echo "3 - Zmień na język Angielski"
        echo "================================================================"
        echo "Wybierz opcję i naciśnij ENTER: "
    else
        echo "================================================================"
        echo "PiPhi Network Installation Script for SenseCAP M1 with balenaOS"
        echo "Version: 2.27 | Date: $DATE"
        echo "================================================================"
        echo "1 - Install PiPhi Network with GPS support and automatic startup"
        echo "2 - Exit"
        echo "3 - Change to Polish language"
        echo "================================================================"
        echo "Select an option and press ENTER: "
    fi
}

# Funkcja zmiany języka
change_language() {
    if [ "$LANGUAGE" = "en" ]; then
        LANGUAGE="pl"
        echo "Język zmieniony na polski."
    else
        LANGUAGE="en"
        echo "Language changed to English."
    fi
    sleep 2
}

# Funkcja instalacji PiPhi Network
install_piphi() {
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Moduł: Instalacja PiPhi Network z obsługą GPS i automatycznym startem"
        echo "================================================================"
    else
        echo "Module: Installing PiPhi Network with GPS support and automatic startup"
        echo "================================================================"
    fi

    # Zmiana katalogu
    cd /mnt/data/piphi-network || { echo "Błąd: Nie można zmienić katalogu na /mnt/data/piphi-network"; exit 1; }

    # Sprawdzanie kontenerów Helium
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Sprawdzanie kontenerów Helium..."
    else
        echo "Checking Helium containers..."
    fi
    balena ps -a | grep pktfwd > /dev/null && HELIUM_CONTAINER=$(balena ps -a | grep pktfwd | awk '{print $NF}') && echo "Znaleziono kontener Helium: $HELIUM_CONTAINER" || echo "Nie znaleziono kontenera Helium."

    # Ładowanie modułu GPS
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Ładowanie modułu GPS (cdc-acm) na hoście..."
    else
        echo "Loading GPS module (cdc-acm) on host..."
    fi
    modprobe cdc-acm
    sleep 2
    GPS_DEVICE=$(ls /dev/ttyACM* 2>/dev/null | head -n 1)
    if [ -n "$GPS_DEVICE" ]; then
        if [ "$LANGUAGE" = "pl" ]; then
            echo "GPS wykryty: $GPS_DEVICE"
        else
            echo "GPS detected: $GPS_DEVICE"
        fi
    else
        if [ "$LANGUAGE" = "pl" ]; then
            echo "Błąd: Nie wykryto GPS."
        else
            echo "Error: GPS not detected."
        fi
        exit 1
    fi

    # Usuwanie istniejących instalacji
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Usuwanie istniejących instalacji (kontenerów i danych), jeśli istnieją..."
    else
        echo "Removing existing installations (containers and data), if any..."
    fi
    balena rm -f $CONTAINER_NAME 2>/dev/null
    rm -rf /mnt/data/piphi-network/*

    # Pobieranie docker-compose.yml
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Pobieranie docker-compose.yml..."
    else
        echo "Downloading docker-compose.yml..."
    fi
    wget -q $DOCKER_COMPOSE_URL -O docker-compose.yml || { echo "Błąd: Nie udało się pobrać docker-compose.yml"; exit 1; }
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Weryfikacja pobranego pliku docker-compose.yml..."
    else
        echo "Verifying downloaded docker-compose.yml..."
    fi
    [ -s docker-compose.yml ] || { echo "Błąd: Plik docker-compose.yml jest pusty"; exit 1; }

    # Sprawdzanie połączenia sieciowego
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Sprawdzanie połączenia sieciowego..."
    else
        echo "Checking network connection..."
    fi
    ping -c 4 8.8.8.8 >/dev/null 2>&1 || { echo "Błąd: Brak połączenia sieciowego"; exit 1; }

    # Pobieranie i uruchamianie obrazu Ubuntu
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Pobieranie obrazu Ubuntu (próba 1/3)..."
    else
        echo "Pulling Ubuntu image (attempt 1/3)..."
    fi
    docker pull ubuntu:20.04 || { echo "Błąd: Nie udało się pobrać obrazu Ubuntu"; exit 1; }

    if [ "$LANGUAGE" = "pl" ]; then
        echo "Uruchamianie kontenera Ubuntu z PiPhi..."
    else
        echo "Running Ubuntu container with PiPhi..."
    fi
    balena run -d --name $CONTAINER_NAME -v /mnt/data/piphi-network:/piphi-network -p 3000:3000 -p 5432:5432 -p 31415:31415 ubuntu:20.04 /bin/bash -c "/piphi-network/start-docker.sh" || { echo "Błąd: Nie udało się uruchomić kontenera"; exit 1; }

    # Czekanie na uruchomienie kontenera
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Czekanie na uruchomienie kontenera Ubuntu (maks. 60 sekund)..."
    else
        echo "Waiting for Ubuntu container to start (max 60 seconds)..."
    fi
    for i in {1..12}; do
        if balena ps -a | grep -q $CONTAINER_NAME; then
            sleep 5
        else
            echo "Błąd: Kontener nie wystartował."
            exit 1
        fi
    done

    # Ustawianie DNS
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Ustawianie DNS na Google (8.8.8.8) w kontenerze..."
    else
        echo "Setting DNS to Google (8.8.8.8) in container..."
    fi
    balena exec $CONTAINER_NAME bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"

    # Wykrywanie strefy czasowej
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Wykrywanie strefy czasowej z hosta..."
    else
        echo "Detecting timezone from host..."
    fi
    TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
    [ -n "$TIMEZONE" ] && balena exec $CONTAINER_NAME ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

    # Instalacja zależności
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Instalacja zależności w Ubuntu..."
    else
        echo "Installing dependencies in Ubuntu..."
    fi
    balena exec $CONTAINER_NAME bash -c "apt-get update && apt-get install -y apt-utils && apt-get install -y ca-certificates curl gnupg lsb-release usbutils gpsd gpsd-clients iputils-ping netcat-openbsd tzdata" || {
        if [ "$LANGUAGE" = "pl" ]; then
            echo "Błąd instalacji podstawowych zależności. Sprawdź logi: balena logs $CONTAINER_NAME lub balena exec $CONTAINER_NAME cat /tmp/apt.log"
        else
            echo "Error installing basic dependencies. Check logs: balena logs $CONTAINER_NAME or balena exec $CONTAINER_NAME cat /tmp/apt.log"
        fi
        exit 1
    }

    # Uruchamianie Dockera i usług
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Uruchamianie daemon Dockera..."
    else
        echo "Starting Docker daemon..."
    fi
    balena exec $CONTAINER_NAME /piphi-network/start-docker.sh

    if [ "$LANGUAGE" = "pl" ]; then
        echo "Uruchamianie usług PiPhi..."
    else
        echo "Starting PiPhi services..."
    fi
    balena exec $CONTAINER_NAME bash -c "cd /piphi-network && docker compose pull && docker compose up -d && docker compose ps"

    # Konfiguracja cron
    if [ "$LANGUAGE" = "pl" ]; then
        echo "Konfiguracja automatycznego uruchamiania..."
    else
        echo "Configuring automatic startup..."
    fi
    balena exec $CONTAINER_NAME bash -c "crontab -l 2>/dev/null; echo '@reboot sleep 30 && cd /piphi-network && docker compose pull && docker compose up -d && docker compose ps' | crontab -"

    if [ "$LANGUAGE" = "pl" ]; then
        echo "Instalacja zakończona pomyślnie!"
    else
        echo "Installation completed successfully!"
    fi
}

# Główna pętla
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_piphi ;;
        2) exit 0 ;;
        3) change_language ;;
        *) echo "Nieprawidłowa opcja." ;;
    esac
done
