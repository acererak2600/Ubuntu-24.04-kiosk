UBUNTU 24.04 WEB KIOSK SCRIPT

Installation:
git clone repo
cd into file

# makes file executable
chmod +x kiosk.sh

# run script
./kiosk.sh

# once complete
sudo reboot

AFTER INSTALLATION
Ubuntu will automatically boot into chromium & show webpage

WARNING
I/O devices can still be used
More user hardening required if used in public
Firefox --kiosk does not work correctly if installed with snap. Hence chromium
