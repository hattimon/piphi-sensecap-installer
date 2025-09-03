# PiPhi Network Installation Script for SenseCAP M1 with balenaOS

This repository contains the installation script for setting up the PiPhi Network on a SenseCAP M1 device running balenaOS. The script automates the installation process with GPS support and automatic startup configuration.

## Version
- **Version**: 2.18
- **Date**: September 02, 2025

## Prerequisites
- A SenseCAP M1 device with balenaOS installed.
- Internet connection.
- Root access to the device.

## Installation Steps
1. **Download the Script**:
   ```
   cd /mnt/data
   wget https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
   chmod +x install-piphi.sh
   ```

2. **Run the Script**:
   ```
   ./install-piphi.sh
   ```
   - Select option `1` to install PiPhi Network with GPS support and automatic startup.
   - Use option `3` to switch between English and Polish languages.

The script will automatically start the Docker daemon as part of the installation process and ensure it runs without manual intervention.

3. **Manual Steps (if Automated Installation Fails)**:
   If the script encounters issues (e.g., container stops), follow these manual steps:
   - Start the container: `balena start ubuntu-piphi`
   - Enter the container: `balena exec -it ubuntu-piphi /bin/bash`
   - Update and install dependencies:
     ```
     apt-get update
     apt-get install -y apt-utils ca-certificates curl gnupg lsb-release usbutils gpsd gpsd-clients iputils-ping netcat-openbsd tzdata
     ```
   - Start Docker and services:
     ```
     /piphi-network/start-docker.sh
     cd /piphi-network
     docker compose pull
     docker compose up -d
     docker compose ps
     ```
   - Configure automatic startup:
     ```
     crontab -l 2>/dev/null; echo '@reboot sleep 30 && cd /piphi-network && docker compose pull && docker compose up -d && docker compose ps' | crontab -
     ```

4. **Troubleshooting**:
   - Check logs: `balena logs ubuntu-piphi` or `balena exec ubuntu-piphi cat /tmp/apt.log`
   - Ensure sufficient disk space: `balena exec ubuntu-piphi df -h`
   - Verify network: `ping -c 4 8.8.8.8`

## Notes
- The script requires a GPS module (detected as `/dev/ttyACM0`).
- Ensure Docker and balena CLI are properly configured.
- For support, check the logs or contact the maintainers.
