#!/bin/bash

echo "========================================="
echo "   RareTrickks Panel Auto-Installer      "
echo "========================================="

# 1. System Update & Dependencies Install
echo "[+] Updating system and installing required packages..."
apt-get update -y
apt-get install python3 python3-pip python3-flask stunnel4 openssh-server unzip wget certbot -y

# 2. Enable BBR & Aggressive Network Tuning (Duplicate-Free)
echo "[+] Applying Aggressive Network Tweaks (Zero Buffering & BBR)..."
# Smart Cleaner: Removes any existing duplicates first
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_keepalive_intvl/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_keepalive_probes/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf

# Freshly Appending single copies
cat << EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=6
net.ipv4.tcp_slow_start_after_idle=0
EOF
sysctl -p

# 3. Optimize SSH Settings (Keep-Alive & Connection Spike Fix)
echo "[+] Optimizing SSH Keep-Alive & DNS settings..."
sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
sed -i '/TCPKeepAlive/d' /etc/ssh/sshd_config
sed -i 's/.*UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config
echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config

# 4. Advanced Encryption Tuning (Lightweight Mobile Tunneling)
echo "[+] Applying Lightweight Encryption Ciphers..."
sed -i '/^Ciphers/d' /etc/ssh/sshd_config
sed -i '/^MACs/d' /etc/ssh/sshd_config
echo "Ciphers aes128-ctr,chacha20-poly1305@openssh.com" >> /etc/ssh/sshd_config
echo "MACs hmac-sha1,umac-64@openssh.com" >> /etc/ssh/sshd_config
systemctl restart ssh

# 5. Panel Data Download
echo "[+] Downloading Panel Raw Data..."
wget -O /root/panel_backup.zip "https://github.com/paysafenew8-coder/Alyan/raw/refs/heads/main/panel_backup%20(1).zip"

# 6. Extracting Data
echo "[+] Extracting data to system folders..."
unzip -o /root/panel_backup.zip -d /

# 7. Fixing Bugs, CPU Priority & Reboot Glitches
echo "[+] Setting up permissions and patching bugs..."
chmod +x /usr/local/bin/raretriccks*.py
chmod +x /usr/local/bin/ws-proxy.py

# Auto-Generate Default Stunnel Certificate (Prevents Crash on Fresh Install)
openssl req -new -x509 -days 3650 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem -subj "/C=PK/CN=DarkTunnel"
sed -i 's|cert = .*|cert = /etc/stunnel/stunnel.pem|g' /etc/stunnel/stunnel.conf
sed -i '/key = .*/d' /etc/stunnel/stunnel.conf

# Stunnel Reboot Fix (Ensures VPN starts automatically after VPS restarts)
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4

# Python Bugs Fix
sed -i 's/new_bytes \/ 1048576.0/new_bytes \/ 2097152.0/g' /usr/local/bin/raretriccks_monitor.py
sed -i 's/def delete_user():/@app.route("\/api\/delete-user", methods=["POST"])\ndef delete_user():/g' /usr/local/bin/raretriccks_web.py
sed -i 's/recv(4096)/recv(65536)/g' /usr/local/bin/ws-proxy.py

# Stunnel Advanced Fixes (Clean before add to prevent duplicates)
sed -i '/TIMEOUTidle/d' /etc/stunnel/stunnel.conf
sed -i '/TCP_NODELAY/d' /etc/stunnel/stunnel.conf
sed -i '1i TIMEOUTidle = 86400' /etc/stunnel/stunnel.conf
sed -i '/SO_KEEPALIVE=1/a socket = l:TCP_NODELAY=1\nsocket = r:TCP_NODELAY=1' /etc/stunnel/stunnel.conf

# WS-Proxy CPU Priority (Clean before add)
sed -i '/Nice=-15/d' /etc/systemd/system/ws-proxy.service
sed -i '/IOSchedulingClass=realtime/d' /etc/systemd/system/ws-proxy.service
sed -i '/\[Service\]/a Nice=-15\nIOSchedulingClass=realtime' /etc/systemd/system/ws-proxy.service

# 8. Creating Direct-Path SSL Manager Script (/usr/bin/add-ssl)
echo "[+] Setting up SSL Manager..."
cat << 'EOF' > /usr/bin/add-ssl
#!/bin/bash
echo "========================================="
echo "       RareTrickks SSL Manager           "
echo "========================================="
read -p "Enter your Domain Name (e.g., Your.domain.com): " DOMAIN

echo "[+] Stopping services to free port 80..."
systemctl stop ws-proxy.service
systemctl stop raretriccks-web.service

echo "[+] Generating SSL Certificate via Certbot..."
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "[+] SSL Generated Successfully!"
    
    # Backstage Swap Logic
    sed -i 's/port=2026/port=2027/g' /usr/local/bin/raretriccks_web.py
    sed -i '/\[panel-ssl\]/,$d' /etc/stunnel/stunnel.conf
    
    cat << STUNNEL >> /etc/stunnel/stunnel.conf

[panel-ssl]
accept = 2026
connect = 127.0.0.1:2027
cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem
key = /etc/letsencrypt/live/$DOMAIN/privkey.pem
STUNNEL

    systemctl restart stunnel4
    systemctl start raretriccks-web.service
    systemctl start ws-proxy.service
    
    echo "[+] SUCCESS: Your domain $DOMAIN is securely linked to port 2026!"
else
    echo "[-] SSL Generation Failed. Check your DNS records."
    systemctl start ws-proxy.service
    systemctl start raretriccks-web.service
fi
EOF
chmod +x /usr/bin/add-ssl

# 9. Writing a Clean Menu Script
echo "[+] Creating Terminal Menu..."
cat << 'EOF' > /usr/local/bin/menu
#!/bin/bash
while true; do
    clear
    IP=$(hostname -I | awk '{print $1}')
    echo "========================================="
    echo "    RareTrickks Panel Terminal Menu      "
    echo "========================================="
    echo "VPS Server IP : $IP"
    echo "Web Panel URL : http://$IP:2026"
    echo "-----------------------------------------"
    if systemctl is-active --quiet raretriccks-web.service; then
        echo "Web Dashboard : [ ACTIVE ]"
    else
        echo "Web Dashboard : [ STOPPED ]"
    fi
    echo "-----------------------------------------"
    echo "1) Change Web Panel Username & Password"
    echo "2) View Web Panel Logs"
    echo "3) View Panel Status & Information"
    echo "4) Completely Uninstall Panel"
    echo "5) Add Domain & Install SSL"
    echo "0) Exit Menu"
    echo "========================================="
    read -p "Select Option [0-5]: " choice

    case $choice in
        1)
            read -p "Enter new Admin Username: " new_user
            read -p "Enter new Admin Password: " new_pass
            export NEW_USER="$new_user"
            export NEW_PASS="$new_pass"
            python3 -c '
import json, os
c="/etc/raretriccks/panel_config.json"
d={}
if os.path.exists(c):
    try:
        with open(c) as f: d=json.load(f)
    except: pass
d["admin_user"]=os.environ.get("NEW_USER")
d["admin_pass"]=os.environ.get("NEW_PASS")
with open(c, "w") as f: json.dump(d, f)
'
            systemctl restart raretriccks-web.service
            echo "[+] Credentials updated! Web panel restarted."
            read -p "Press Enter to return..."
            ;;
        2)
            journalctl -u raretriccks-web.service -n 50 --no-pager
            read -p "Press Enter to return..."
            ;;
        3)
            systemctl status raretriccks-web.service raretriccks-monitor.service --no-pager
            read -p "Press Enter to return..."
            ;;
        4)
            read -p "Are you sure you want to uninstall? (y/n): " confirm
            if [[ $confirm == "y" ]]; then
                systemctl stop raretriccks-web.service raretriccks-monitor.service ws-proxy.service
                rm -rf /usr/local/bin/raretriccks* /usr/bin/add-ssl /usr/bin/menu /usr/local/bin/menu /etc/raretriccks
                echo "Panel uninstalled completely."
                exit 0
            fi
            ;;
        5)
            add-ssl
            read -p "Press Enter to return..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option."
            sleep 1
            ;;
    esac
done
EOF
cp /usr/local/bin/menu /usr/bin/menu
chmod +x /usr/local/bin/menu
chmod +x /usr/bin/menu

# 10. Reloading Systemd and Starting Services
echo "[+] Starting RareTrickks Services..."
systemctl daemon-reload
systemctl enable stunnel4
systemctl enable --now raretriccks-web.service
systemctl enable --now raretriccks-monitor.service
systemctl enable --now ws-proxy.service
systemctl restart raretriccks-monitor.service

# 11. Restarting Main Tunnels
echo "[+] Finalizing Setup..."
systemctl restart ssh
systemctl restart stunnel4
rm -f /root/panel_backup.zip

echo "========================================="
echo " INSTALLATION COMPLETE! "
echo " - Anti-Duplication System Active!"
echo " - Video Buffering Bug FIXED!"
echo " - Server Reboot Crash FIXED!"
echo " - Domain SSL Routing Configured!"
echo " - Type 'menu' to open your panel."
echo "========================================="
