# PiPhi Network Installer for SenseCAP M1 with balenaOS

## Overview
This repository provides a Bash script to install PiPhi Network on SenseCAP M1 devices running balenaOS, with support for a GPS dongle (tested with U-Blox 7). The installation runs PiPhi alongside the existing Helium Miner, using a Ubuntu container to handle Docker and GPS dependencies. Files are stored in `/mnt/data` to avoid read-only filesystem issues in balenaOS.

Based on:
- PiPhi Network documentation: [docs.piphi.network/Installation](https://docs.piphi.network/Installation)
- docker-compose.yml: [chibisafe.piphi.network/m2JmK11Z7tor.yml](https://chibisafe.piphi.network/m2JmK11Z7tor.yml)
- Inspired by: [WantClue/Sensecap](https://github.com/WantClue/Sensecap)

**Tested on**: balenaOS 2.80.3+rev1, SenseCAP M1 (Raspberry Pi 4, 4GB RAM), GPS U-Blox 7.

**Key Features**:
- Coexists with Helium Miner (e.g., `pktfwd_`, `miner_` containers).
- GPS support via `cdc-acm` module and `gpsd`.
- Uses `/mnt/data` for writable storage.
- Automated Docker and `gpsd` installation in a Ubuntu container.
- Port mapping for PiPhi (default: 31415).

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
- balenaOS lacks `git`; script uses `wget` for file downloads.
- Root filesystem (`/`) is read-only; use `/mnt/data` for all files.

## Installation Steps
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

4. **Make Script Executable**:
   ```
   chmod +x install-piphi.sh
   ```

5. **Run the Script**:
   ```
   ./install-piphi.sh
   ```
   - Select option 1 to start installation.

The script will:
- Verify Helium containers (`pktfwd_`, etc.).
- Load GPS module (`cdc-acm`) for U-Blox 7 (`/dev/ttyACM0`).
- Store files in `/mnt/data/piphi-network`.
- Download and modify `docker-compose.yml` for GPS support.
- Pull and run a Ubuntu container with `--privileged` mode.
- Install Docker, `gpsd`, and dependencies inside Ubuntu.
- Start PiPhi services (port 31415).
- Restart containers for changes.

## Usage
- **Access PiPhi**: Open http://<device IP>:31415 in a browser (default port from PiPhi docs).
- **Check GPS**:
  - Enter Ubuntu container: `balena exec -it ubuntu-piphi /bin/bash`.
  - Run: `cgps -s` (place device outdoors for satellite fix, 1–5 minutes).
- **Logs**:
  - PiPhi logs: `balena exec ubuntu-piphi docker logs <piphi_container_name>` (e.g., `piphi_piphi_1`).
  - All containers: `balena ps`.
- **Stop/Remove**:
  - Stop PiPhi: `balena exec ubuntu-piphi docker compose down`.
  - Remove container: `balena stop ubuntu-piphi && balena rm ubuntu-piphi`.
- **Update PiPhi**:
  - In Ubuntu container: `cd /piphi-network && docker compose pull && docker compose up -d`.

## Troubleshooting
- **Read-only Filesystem**:
  - Ensure all operations are in `/mnt/data`. Do not use `/` or `/home`.
- **GPS Not Detected**:
  - Verify U-Blox 7: `lsusb` (should show `1546:01a7`).
  - Check `/dev/ttyACM0`: `balena exec ubuntu-piphi ls /dev/ttyACM*`.
  - Run `modprobe cdc-acm`: `balena exec ubuntu-piphi modprobe cdc-acm`.
  - Check logs: `balena exec ubuntu-piphi dmesg | grep usb`.
  - No fix? Place device outdoors; use `ubxtool` for NMEA mode:
    ```
    balena exec ubuntu-piphi apt-get install -y ubxtool && ubxtool -s NMEA
    ```
- **Port Conflicts**:
  - PiPhi uses 31415; Helium uses 44158. Edit `docker-compose.yml` if conflicts occur.
- **Resource Issues**:
  - Script limits resources in `docker-compose.yml`:
    ```yaml
    services:
      piphi:
        deploy:
          resources:
            limits:
              cpus: '0.5'
              memory: 512M
    ```
- **Helium Stops**:
  - Restart: `balena restart pktfwd_11463326_3483250`.
- **Errors in Ubuntu**:
  - Re-enter container: `balena exec -it ubuntu-piphi /bin/bash`.
  - Rerun commands manually (e.g., `apt-get install ...`).
- **Wget Fails**:
  - Use `curl`:
    ```
    curl -o install-piphi.sh https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
    ```
  - Or upload via `scp` from another machine:
    ```
    scp install-piphi.sh root@<device IP>:/mnt/data/
    ```

## Roadmap
- [x] Dual Mining (PiPhi + Helium)
- [ ] Add overwrite safety for existing files
- [ ] Support regional GPS configurations
- [ ] Add Watchtower for auto-updates
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
