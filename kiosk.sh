#!/bin/bash

# Exit on error and undefined variables
set -eu

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root. It will use sudo when needed."
    exit 1
fi

# Configuration variables
KIOSK_USER="kiosk"
KIOSK_PASSWORD="kiosk"
CHROMIUM_URL="https://youtube.com"

# Function for error handling
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Install Chromium if not already installed
if ! command -v chromium-browser &> /dev/null; then
    echo "Installing Chromium (this may take a few minutes)..."
    sudo apt update > /dev/null 2>&1 || error_exit "Failed to update package list"
    sudo apt install -y chromium-browser > /dev/null 2>&1 || error_exit "Failed to install Chromium"
    echo "Chromium installation complete."
fi

# Check if user already exists
if id "$KIOSK_USER" &>/dev/null; then
    echo "User $KIOSK_USER already exists. Skipping user creation."
else
    # Create kiosk user with password
    echo "Creating kiosk user..."
    sudo adduser --gecos "" --disabled-password "$KIOSK_USER" > /dev/null 2>&1 || error_exit "Failed to create user $KIOSK_USER"
    echo "$KIOSK_USER:$KIOSK_PASSWORD" | sudo chpasswd || error_exit "Failed to set password"
fi

# Create autostart directory
sudo mkdir -p "/home/$KIOSK_USER/.config/autostart" || error_exit "Failed to create autostart directory"

# Create kiosk desktop file with proper escaping
sudo tee "/home/$KIOSK_USER/.config/autostart/kiosk.desktop" > /dev/null << EOF
[Desktop Entry]
Type=Application
Name=Kiosk
Exec=gnome-session-inhibit --inhibit "logout:suspend:idle" --app-id kiosk chromium-browser --kiosk --no-first-run --disable-features=TranslateUI --disable-session-crashed-bubble --disable-infobars --noerrdialogs --disable-web-security --user-data-dir=/tmp/chromium-profile "$CHROMIUM_URL"
Hidden=false
X-GNOME-Autostart-enabled=true
EOF

# Set ownership permissions
sudo chown -R "$KIOSK_USER:$KIOSK_USER" "/home/$KIOSK_USER" || error_exit "Failed to set ownership"
sudo chmod 755 "/home/$KIOSK_USER/.config/autostart/kiosk.desktop" || error_exit "Failed to set permissions"

# Configure automatic login
if [ -f /etc/gdm3/custom.conf ]; then
    sudo cp /etc/gdm3/custom.conf /etc/gdm3/custom.conf.backup.$(date +%Y%m%d_%H%M%S) || echo "Warning: Could not create backup"
fi

# Use sed to update GDM configuration 
sudo sed -i '/^\[daemon\]/,/^\[/ {/^AutomaticLoginEnable/d; /^AutomaticLogin/d}' /etc/gdm3/custom.conf
sudo sed -i '/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=kiosk' /etc/gdm3/custom.conf || error_exit "Failed to configure automatic login"

# Disable screen saver and power management
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true

# Additional security hardening
echo "Applying security settings..."

# Disable guest account
sudo sh -c 'echo "AllowGuest=false" >> /etc/gdm3/custom.conf' 2>/dev/null || true

# Prevent user switching (optional)
sudo -u "$KIOSK_USER" dbus-launch gsettings set org.gnome.desktop.lockdown disable-user-switching true 2>/dev/null || true

# Set Chromium to start automatically on boot (fallback)
sudo tee "/home/$KIOSK_USER/.xinitrc" > /dev/null << 'EOF'
#!/bin/sh
exec chromium-browser --kiosk --no-first-run --disable-features=TranslateUI --disable-session-crashed-bubble --disable-infobars --noerrdialogs --disable-web-security --user-data-dir=/tmp/chromium-profile "$@"
EOF

sudo chown "$KIOSK_USER:$KIOSK_USER" "/home/$KIOSK_USER/.xinitrc"
sudo chmod +x "/home/$KIOSK_USER/.xinitrc"

echo "Kiosk configuration completed successfully!"
echo "Kiosk user: $KIOSK_USER"
echo "Password: $KIOSK_PASSWORD"
echo "URL: $CHROMIUM_URL"
echo ""
echo "Please reboot for changes to take effect: sudo reboot"