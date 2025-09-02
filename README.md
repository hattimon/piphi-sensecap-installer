# PiPhi Network Installer for SenseCAP M1 with balenaOS
[🇬🇧 English](README.md) | [🇵🇱 Polski](README-PL.md)

## Overview
This repository provides a fully automated Bash script to install PiPhi Network on SenseCAP M1 devices running balenaOS, with support for a GPS dongle (tested with U-Blox 7). The installation runs PiPhi alongside the existing Helium Miner, using a Ubuntu container to handle Docker, GPS, and all services (PiPhi, PostgreSQL, Watchtower, Grafana). The script ensures automatic startup of the container and services after a system restart.

Based on:
- PiPhi Network documentation: [docs.piphi.network/Installation](https://docs.piphi.network/Installation)
- docker-compose.yml: [chibisafe.piphi.network/m2JmK11Z7tor.yml](https://chibisafe.piphi.network/m2JmK11Z7tor.yml)
- Inspired by: [WantClue/Sensecap](https://github.com/WantClue/Sensecap)

**Tested on**: balenaOS 2.80.3+rev1, SenseCAP M1 (Raspberry Pi 4, 4GB RAM, arm64), GPS U-Blox 7.

**Key Features**:
- Coexists with Helium Miner (e.g., `pktfwd_`, `miner_` containers).
- GPS support via `cdc-acm` module (host) and `gpsd` (container).
- Uses `/mnt/data` for writable storage.
- Automated installation of all dependencies (`curl`, `iputils-ping`, `docker-ce`, `gpsd`, `yq`, etc.).
- Non-interactive timezone configuration (default: `Europe/Warsaw`, customizable).
- Port mapping for PiPhi (31415), PostgreSQL (5432), and Grafana (3000).
- Automatic startup of the `ubuntu-piphi` container, Docker daemon, and all services after reboot.
- Resource allocation (2 CPU cores, 2GB RAM) for stability.
- Fixed Grafana volume and GPS configuration.

## Requirements
- SenseCAP M1 with balenaOS (access via SSH as root).
- GPS dongle (U-Blox 7) connected to USB port.
- Stable network connection (for downloading images and files).
- At least 4GB RAM (SenseCAP M1 standard).
- Backup of your SD card (installation modifies system).

**Warnings**:
- May void warranty or affect Helium mining performance.
- Potential resource conflicts (CPU/RAM); monitor with `balena top`.
- No official support from PiPhi or SenseCAP – use at your own risk.
- GPS requires outdoor placement for satellite fix (1–5 minutes).
- balenaOS lacks `git`, `sudo`, and `docker`; script uses `wget` and `balena` commands.
- Root filesystem (`/`) is read-only; use `/mnt/data` for all files.
- balenaOS may show a warning about swap limit capabilities; this is safe to ignore with 4GB RAM.
- Docker in the container uses `vfs` storage driver due to balenaOS limitations.

## Automated Installation Steps
Follow these simple steps to install PiPhi Network with full automation:

1. **Log in to SenseCAP M1**:
   ```
   ssh root@<device IP>
   ```

2. **Change to Writable Directory**:
   - balenaOS has a read-only root (`/`). Use `/mnt/data`:
     ```
     cd /mnt/data
     ```

3. **Download the Script**:
   - Use `wget` to download the installer:
     ```
     wget https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
     ```
   - Alternatively, use `curl` if `wget` fails:
     ```
     curl -o install-piphi.sh https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
     ```
   - Or upload via `scp` from another machine:
     ```
     scp install-piphi.sh root@<device IP>:/mnt/data/
     ```

4. **Make Script Executable**:
   ```
   chmod +x install-piphi.sh
   ```

5. **Run the Script**:
   ```
   ./install-piphi.sh
   ```
   - Select option 1 to start the automated installation.
   - Enter a timezone (e.g., `Europe/Warsaw`) when prompted, or press ENTER for the default (`Europe/Warsaw`).
   - The script will handle everything: removing old containers, installing dependencies, configuring Docker, setting up GPS, and launching all services.

The script will:
- Verify Helium containers (`pktfwd_`, etc.).
- Load the GPS module (`cdc-acm`) for U-Blox 7 on the host.
- Store files in `/mnt/data/piphi-network`.
- Download or generate a valid `docker-compose.yml` with GPS and Grafana support.
- Remove any existing `ubuntu-piphi` container to avoid conflicts.
- Pull and run a Ubuntu container with `--privileged` mode, resource limits (`--cpus="2.0" --memory="2g"`), and automatic restart.
- Install all dependencies (`curl`, `iputils-ping`, `docker-ce`, `gpsd`, `yq`, etc.) non-interactively.
- Configure the timezone non-interactively.
- Set up a startup script to launch the Docker daemon (`nohup dockerd ...`) automatically.
- Pull and start PiPhi services (ports 31415, 5432, 3000) with retry logic.
- Restart the container to apply changes.

## Usage
- **Access PiPhi**: Open `http://<device IP>:31415` in a browser (default port for PiPhi).
- **Access Grafana**: Open `http://<device IP>:3000` (if used).
- **Check GPS**:
  - Enter the Ubuntu container: `balena exec -it ubuntu-piphi /bin/bash`.
  - Run: `cgps -s` (place device outdoors for satellite fix, 1–5 minutes).
- **Logs**:
  - PiPhi logs: `balena exec ubuntu-piphi docker logs piphi-network-image`.
  - Docker daemon logs: `balena exec ubuntu-piphi cat /piphi-network/dockerd.log`.
  - All containers: `balena ps` (on host) or `balena exec ubuntu-piphi docker ps` (in container).
- **Monitor Resources**:
  - Check CPU and memory usage: `balena top ubuntu-piphi`.
- **Stop/Remove**:
  - Stop PiPhi: `balena exec ubuntu-piphi docker compose down`.
  - Remove container: `balena stop ubuntu-piphi && balena rm ubuntu-piphi`.
- **Update PiPhi**:
  - In the Ubuntu container: `balena exec ubuntu-piphi docker compose pull && balena exec ubuntu-piphi docker compose up -d`.

## Troubleshooting
- **Docker Daemon Not Running**:
  - Check status: `balena exec ubuntu-piphi ps aux | grep dockerd`.
  - Check logs: `balena exec ubuntu-piphi cat /piphi-network/dockerd.log`.
  - Restart manually: `balena exec ubuntu-piphi /usr/local/bin/start-docker.sh`.
  - Verify: `balena exec ubuntu-piphi docker info`.
- **Failed to Pull Images**:
  - Check network: `balena exec ubuntu-piphi curl -I https://registry-1.docker.io/v2/`.
  - Use alternative DNS: `balena exec ubuntu-piphi bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"`.
  - Manually pull: `balena exec -it ubuntu-piphi /bin/bash`, then `cd /piphi-network && docker compose pull && docker compose up -d`.
- **GPS Not Detected**:
  - Verify U-Blox 7: `lsusb` (should show `1546:01a7`).
  - Check device: `balena exec ubuntu-piphi ls /dev/ttyACM*`.
  - Configure NMEA mode: `balena exec ubuntu-piphi apt-get install -y ubxtool && ubxtool -s NMEA`.
  - Place outdoors for fix.
- **PiPhi or Grafana Not Starting**:
  - Check logs: `balena exec ubuntu-piphi docker logs piphi-network-image` or `balena exec ubuntu-piphi docker logs grafana`.
  - Restart services: `balena exec ubuntu-piphi docker compose up -d`.
- **Resource Issues**:
  - Monitor: `balena top ubuntu-piphi`.
  - Adjust limits if needed (e.g., `--cpus="1.5" --memory="1.5g"`).

## Roadmap
- [x] Dual Mining (PiPhi + Helium)
- [x] Resource allocation for Raspberry Pi 3 compatibility
- [x] Fix Grafana volume configuration
- [x] Add iputils-ping and curl for network checks
- [x] Non-interactive timezone configuration
- [x] Handle existing container conflicts
- [x] Automatic startup of container, Docker, and services
- [ ] Add overwrite safety for existing files
- [ ] Support regional GPS configurations
- [ ] Create video tutorial (inspired by WantClue)

## Contributing
Fork the repository and submit pull requests for improvements, e.g., better GPS configuration, error handling, or support for other GPS dongles.

## License
MIT License. Use at your own risk.

## Credits
- Based on PiPhi Network docs and WantClue's ThingsIX script ([WantClue/Sensecap](https://github.com/WantClue/Sensecap)).
- Generated with assistance from Grok (xAI).

## Support My Work
If you find this script helpful, consider supporting the project:
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/your-kofi-link)

## Notes
- If GPS issues persist, consider replacing balenaOS with Ubuntu for better USB support (see [Ubuntu Raspberry Pi](https://ubuntu.com/download/raspberry-pi)).
- Check PiPhi Network Discord or SenseCAP support for specific GPS configuration.
