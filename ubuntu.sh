#!/usr/bin/env bash

# ===========================
# ENVIRONMENT & TRAP SETUP
# ===========================

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Prompt for sudo upfront to authorize the terminal session
echo "=== Terminal Authorization ==="
echo "Please enter your password to authorize sudo access:"
sudo -v || { echo "Sudo authorization failed. Exiting."; exit 1; }

# Keep-alive loop: updates sudo timestamp every 60s until the script exits
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

# Global cleanup on exit or failure
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null; rm -rf /tmp/fastfetch.deb /tmp/steam.deb /tmp/sober_cfg.py /tmp/pin_taskbar.py 2>/dev/null' EXIT

# ===========================
# INITIAL PROMPT
# ===========================

clear
echo "=== ubuntu auto ricer by dino13513 ==="
echo ""
read -t 10 -p "Would you like to pre-install Steam and Sober? [y/N] (auto selecting N in 10s): " GAMING_INPUT </dev/tty

GAMING_INPUT=${GAMING_INPUT:-N}

if [[ "$GAMING_INPUT" =~ ^[Yy]$ ]]; then
    INSTALL_GAMING=true
else
    INSTALL_GAMING=false
fi

TOTAL_STEPS=7
CURRENT_STEP=0

clear
echo "=== ubuntu auto ricer by dino13513 ==="

# =======================
# SPINNER HELPER FUNC
# =======================

run_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local msg="$1"
    local cmd="$2"

    eval "$cmd" >/dev/null 2>&1 &
    local pid=$!
    local spin=('/' '-' '\' '|')
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r\033[K[%d/%d] %s [%s]" "$CURRENT_STEP" "$TOTAL_STEPS" "$msg" "${spin[$i]}"
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r\033[K[%d/%d] %s [✓]\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$msg"
    else
        printf "\r\033[K[%d/%d] %s [✗]\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$msg"
    fi
    return $status
}

# =================
# EXECUTION STEPS
# =================

# step 1
run_step "Pre-seeding SDDM selection & 32-bit architecture" '
    echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections
    sudo dpkg --add-architecture i386
    sudo apt-get update -qq
'

# step 2
run_step "Installing KDE Plasma & dependencies" '
    sudo apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
    sddm kde-plasma-desktop kwin-addons mesa-utils git build-essential flatpak python3 nodejs npm curl wget
'

# step 3
run_step "Configuring KDE Plasma & 3D compositing" '
    KWRITE=$(command -v kwriteconfig6 || command -v kwriteconfig5 || echo "")
    if [ -n "$KWRITE" ]; then
        $KWRITE --file kwinrc --group Compositing --key OpenGLIsUnsafe false
        $KWRITE --file kwinrc --group Compositing --key Enabled true
        $KWRITE --file kwinrc --group Plugins --key wobblywindowsEnabled true
        plasma-apply-lookandfeel -a org.kde.breezedark.desktop 2>/dev/null || true
    fi
'

# step 4
run_step "Installing and configuring fastfetch" '
    if ! sudo apt-get install -y -qq fastfetch 2>/dev/null; then
        wget -q https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb -O /tmp/fastfetch.deb
        sudo dpkg -i /tmp/fastfetch.deb || sudo apt-get install -f -y -qq
    fi
    grep -qF "alias fetch=\"fastfetch\"" "$HOME/.bashrc" || echo "alias fetch=\"fastfetch\"" >> "$HOME/.bashrc"
    grep -qF "alias neofetch=\"fastfetch\"" "$HOME/.bashrc" || echo "alias neofetch=\"fastfetch\"" >> "$HOME/.bashrc"
    grep -qF "fastfetch" "$HOME/.bashrc" || echo "fastfetch" >> "$HOME/.bashrc"
'

# step 5
if [ "$INSTALL_GAMING" = true ]; then
    run_step "Installing Steam and Sober (Roblox)" '
        wget -q https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb -O /tmp/steam.deb
        sudo dpkg -i /tmp/steam.deb || sudo apt-get install -f -y -qq

        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub org.vinegarhq.Sober
        flatpak override --user --filesystem=xdg-run/discord-ipc-0 org.vinegarhq.Sober 2>/dev/null || true

        mkdir -p "$HOME/.var/app/org.vinegarhq.Sober/config/sober"
        cat << "EOF" > /tmp/sober_cfg.py
import json, os, subprocess

# Test if Vulkan runs safely on this CPU/GPU combination
use_opengl = True
try:
    # Run vulkaninfo; if it SIGILLs or fails, returncode will not be 0
    res = subprocess.run(["vulkaninfo", "--summary"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if res.returncode == 0:
        use_opengl = False
except Exception:
    use_opengl = True

config_path = os.path.expanduser("~/.var/app/org.vinegarhq.Sober/config/sober/config.json")
data = {
    "allow_gamepad_permission": True,
    "close_on_leave": False,
    "discord_rpc_enabled": True,
    "discord_rpc_show_join_button": False,
    "enable_gamemode": True,
    "enable_hidpi": False,
    "enable_mobile_home_screen": False,
    "fflags": {
        "FFlagExample": True
    },
    "graphics_optimization_mode": "balanced",
    "server_location_indicator_enabled": False,
    "touch_mode": "off",
    "use_console_experience": False,
    "use_libsecret": False,
    "use_opengl": use_opengl
}

with open(config_path, "w") as f:
    json.dump(data, f, indent=2)
EOF
        python3 /tmp/sober_cfg.py
'
else
    run_step "Installing Steam and Sober (Roblox)" '
        echo "Skipped gaming software installation"
    '
fi

# step 6
run_step "Setting up SDDM theme, desktop icons, and taskbar pins" '
    sudo mkdir -p /etc/sddm.conf.d
    echo -e "[Theme]\nCurrent=breeze" | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null

    mkdir -p "$HOME/Desktop"
    if [ "$INSTALL_GAMING" = true ]; then
        cp /usr/share/applications/steam.desktop "$HOME/Desktop/" 2>/dev/null || true
        cp /var/lib/flatpak/exports/share/applications/org.vinegarhq.Sober.desktop "$HOME/Desktop/" 2>/dev/null || true
        chmod +x "$HOME/Desktop/"*.desktop 2>/dev/null || true
    fi

    cat << "EOF" > /tmp/pin_taskbar.py
import configparser, os
config_path = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
if os.path.exists(config_path):
    config = configparser.ConfigParser(interpolation=None)
    config.read(config_path)

    # Base pin
    new_launchers = ["applications:org.kde.konsole.desktop"]

    for section in config.sections():
        if config.has_option(section, "plugin") and config.get(section, "plugin") in ["org.kde.plasma.icontasks", "org.kde.plasma.taskmanager"]:
            applet_id = section.split("[")[-1].replace("]", "")
            gen_section = f"Applets][{applet_id}][Configuration][General"
            if not config.has_section(gen_section):
                config.add_section(gen_section)
            config.set(gen_section, "launchers", ",".join(new_launchers))

    with open(config_path, "w") as f:
        config.write(f, space_around_delimiters=False)
EOF
    python3 /tmp/pin_taskbar.py
'

# step 7
run_step "Reloading Plasma Shell and KWin manager" '
    kquitapp5 plasmashell 2>/dev/null || kquitapp6 plasmashell 2>/dev/null || true
    kstart5 plasmashell >/dev/null 2>&1 || kstart6 plasmashell >/dev/null 2>&1 &
    kwin_x11 --replace >/dev/null 2>&1 &
    kwin_wayland --replace >/dev/null 2>&1 &
'

echo -e "\nRice Complete! It is safe to reboot now."
