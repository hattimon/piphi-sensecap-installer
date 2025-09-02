# PiPhi Network Installer for SenseCAP M1 with balenaOS
[🇬🇧 English](README.md) | [🇵🇱 Polski](README-PL.md)

## Key Script Changes (version 2.22)
1. **Creating `start-docker.sh` before starting the container**:
   - The script now creates `start-docker.sh` on the host in `/mnt/data/piphi-network` before starting the `ubuntu-piphi` container to avoid the `no such file or directory` error.

2. **Careful file removal**:
   - Instead of deleting the entire `/mnt/data/piphi-network/*` directory, the script only removes `docker-compose.yml` and `dockerd.log`, preserving `start-docker.sh` during reinstallation.

3. **Reliable GPS startup**:
   - Confirmed that `gpsd /dev/ttyACM0` is started automatically in `start-docker.sh` with device verification.

4. **Logging**:
   - `start-docker.sh` now includes detailed logs with timestamps for each step (`dockerd` start, `gpsd`, `docker compose pull`, `docker compose up`).

## Deployment Instructions
1. **Stop and remove the existing `ubuntu-piphi` container** (on the host):
   ```
   balena stop ubuntu-piphi
   balena rm ubuntu-piphi
   ```

2. **Remove old configuration files** (on the host):
   ```
   cd /mnt/data/piphi-network
   rm -f docker-compose.yml dockerd.log
   ```
   - Note: Do not remove `start-docker.sh`, as it will be overwritten by the new script.

3. **Remove old installer script** (on the host):
   ```
   rm /mnt/data/install-piphi.sh
   ```

4. **Download updated script** (on the host):
   ```
   cd /mnt/data
   wget https://raw.githubusercontent.com/hattimon/piphi-sensecap-installer/main/install-piphi.sh
   ```

5. **Set permissions and run** (on the host):
   ```
   chmod +x install-piphi.sh
   ./install-piphi.sh
   ```
   - Select option 1 to start installation.
   - Optionally, select option 3 to switch language to Polish.

6. **Check PiPhi dashboard**:
   - Open browser: `http://<device IP>:31415`.
   - Check Grafana: `http://<device IP>:3000`.

7. **Check GPS** (on the host):
   ```
   balena exec -it ubuntu-piphi cgps -s
   ```
   - If GPS doesn’t work, make sure the device is outdoors (fix may take 1–5 minutes).

8. **Check service status** (on the host):
   ```
   balena ps -a
   balena exec ubuntu-piphi docker compose ps
   ```

9. **Check logs if error occurs** (on host and container):
   - Container logs:
     ```
     balena logs ubuntu-piphi
     ```
   - apt-get logs:
     ```
     balena exec ubuntu-piphi cat /tmp/apt.log
     ```
   - Docker daemon and GPS logs:
     ```
     balena exec ubuntu-piphi cat /piphi-network/dockerd.log
     ```
   - PiPhi logs:
     ```
     balena exec ubuntu-piphi docker logs piphi-network-image
     ```

10. **Test device reboot** (on the host):
    ```
    reboot
    ```
    - After reboot, check status:
      ```
      balena ps -a
      balena exec ubuntu-piphi docker compose ps
      ```
    - Verify dashboard availability: `http://<device IP>:31415`.

## Manual Fix (if script still fails)
If installation still fails, perform the following:

1. **Check Docker daemon** (on the host):
   ```
   balena exec -it ubuntu-piphi /bin/bash
   pgrep dockerd
   ```
   - If no result, start manually:
     ```
     /piphi-network/start-docker.sh
     ```
   - Check logs:
     ```
     cat /piphi-network/dockerd.log
     ```

2. **Fix GPS** (inside container):
   ```
   ls /dev/ttyACM0
   gpsd /dev/ttyACM0
   cgps -s
   ```
   - If no `/dev/ttyACM0`, check on host:
     ```
     lsusb
     ls /dev/ttyACM*
     ```

3. **Manually start services** (inside container):
   ```
   cd /piphi-network
   docker compose pull
   docker compose up -d
   docker compose ps
   ```

4. **Restart container** (on the host):
   ```
   balena restart ubuntu-piphi
   ```

## Notes
- **Docker daemon**: The script now creates `start-docker.sh` before container launch, eliminating the `no such file or directory` error. A loop in `start-docker.sh` ensures automatic daemon recovery after failure.
- **GPS**: `gpsd` startup is now reliable, with `/dev/ttyACM0` verification.
- **PiPhi dashboard**: Check in browser at `http://<device IP>:31415`. If not working, verify port:
  ```
  balena exec ubuntu-piphi nc -z 127.0.0.1 31415
  ```
- **Swap warning**: Normal in balenaOS, no effect on 4GB RAM.
- **Helium Miner**: Helium containers (`pktfwd_`, `miner_`, etc.) remain unaffected by installation.

## Post-Installation Verification
Run the following commands to confirm installation:

- Container status:
  ```
  balena ps -a
  balena exec ubuntu-piphi docker compose ps
  ```
- Logs:
  ```
  balena logs ubuntu-piphi
  balena exec ubuntu-piphi cat /piphi-network/dockerd.log
  balena exec ubuntu-piphi cat /tmp/apt.log
  balena exec ubuntu-piphi docker logs piphi-network-image
  ```
- Dashboard availability:
  - Browser: `http://<device IP>:31415`
  - Console:
    ```
    balena exec ubuntu-piphi nc -z 127.0.0.1 31415
    ```
- GPS:
  ```
  balena exec -it ubuntu-piphi cgps -s
  ```

## Support My Work
If you find this script helpful, consider supporting the project:
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/B0B01KMW5G)
