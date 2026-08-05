#!/bin/bash

echo "========================================="
echo "   RareTrickks Panel Auto-Installer      "
echo "========================================="

# 1. System Update & Dependencies Install
echo "[+] Updating system and installing required packages..."
apt-get update -y
apt-get install python3 python3-pip stunnel4 openssh-server unzip wget certbot -y

# 2. Enable BBR & Network Optimizations (Fixes Speed Drop & Stalling)
echo "[+] Applying TCP BBR and Network Performance Tweaks..."
if ! grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 3. Optimize SSH Keep-Alive to Prevent Connection Freezing
echo "[+] Optimizing SSH Keep-Alive settings..."
sed -i '/ClientAliveInterval/d' /etc/ssh/sshd_config
sed -i '/ClientAliveCountMax/d' /etc/ssh/sshd_config
sed -i '/TCPKeepAlive/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config
echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config
systemctl restart ssh

# 4. Panel Data Download
echo "[+] Downloading Panel Raw Data..."
wget -O /root/panel_backup.zip "https://github.com/paysafenew8-coder/Alyan/raw/refs/heads/main/panel_backup%20(1).zip"

# 5. Extracting Data
echo "[+] Extracting data to system folders..."
unzip -o /root/panel_backup.zip -d /

# 6. Fixing Permissions
echo "[+] Setting up executable permissions..."
chmod +x /usr/local/bin/raretriccks*.py
chmod +x /usr/local/bin/ws-proxy.py

# 7. Creating Direct-Path SSL Script (/usr/bin/add-ssl)
echo "[+] Setting up SSL Manager..."
cat << 'EOF' > /usr/bin/add-ssl
#!/bin/bash
echo "========================================="
echo "       RareTrickks SSL Manager           "
echo "========================================="
read -p "Enter your Domain Name (e.g., Your.domain.com): " DOMAIN

echo "[+] Stopping web services to free port 80..."
systemctl stop ws-proxy.service
systemctl stop raretriccks-web.service
systemctl stop stunnel4

echo "[+] Generating SSL Certificate via Certbot..."
certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "[+] SSL Generated Successfully!"
    
    # Configure Stunnel with Direct Paths
    if ! grep -q "\[panel-ssl\]" /etc/stunnel/stunnel.conf; then
        cat << STUNNEL >> /etc/stunnel/stunnel.conf

[panel-ssl]
accept = 443
connect = 127.0.0.1:2026
cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem
key = /etc/letsencrypt/live/$DOMAIN/privkey.pem
STUNNEL
    else
        sed -i "s|cert = .*|cert = /etc/letsencrypt/live/$DOMAIN/fullchain.pem|g" /etc/stunnel/stunnel.conf
        sed -i "s|key = .*|key = /etc/letsencrypt/live/$DOMAIN/privkey.pem|g" /etc/stunnel/stunnel.conf
    fi

    echo "[+] Restarting Stunnel and Web Services..."
    systemctl restart stunnel4
    systemctl start ws-proxy.service
    systemctl start raretriccks-web.service
    echo "[+] SSL Configured Successfully!"
else
    echo "[-] SSL Generation Failed. Check your domain's DNS A-Record."
    systemctl start stunnel4
    systemctl start ws-proxy.service
    systemctl start raretriccks-web.service
fi
EOF

chmod +x /usr/bin/add-ssl

# 8. Writing a Clean & Fixed Menu Script from Scratch
echo "[+] Creating clean Terminal Menu..."
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
            echo -e "\n--- Change Admin Credentials ---"
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
            echo -e "\n[+] Credentials updated successfully! Web panel restarted."
            read -p "Press Enter to return to menu..."
            ;;
        2)
            journalctl -u raretriccks-web.service -n 50 --no-pager
            read -p "Press Enter to return to menu..."
            ;;
        3)
            systemctl status raretriccks-web.service raretriccks-monitor.service --no-pager
            read -p "Press Enter to return to menu..."
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
            read -p "Press Enter to return to menu..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Invalid option, try again."
            sleep 1
            ;;
    esac
done
EOF

cp /usr/local/bin/menu /usr/bin/menu
chmod +x /usr/local/bin/menu
chmod +x /usr/bin/menu

# 9. Reloading Systemd and Starting Custom Services
echo "[+] Configuring and starting RareTrickks Services..."
systemctl daemon-reload

systemctl enable --now raretriccks-web.service
systemctl enable --now raretriccks-monitor.service
systemctl enable --now ws-proxy.service
systemctl enable --now ip-monitor.service

# 10. Restarting SSH and Stunnel4
echo "[+] Restarting SSH and Stunnel4..."
systemctl restart ssh
systemctl restart stunnel4

# Cleanup
rm -f /root/panel_backup.zip

echo "========================================="
echo " INSTALLATION COMPLETE! "
echo " - BBR & Keep-Alive Optimized!"
echo " - Type 'menu' to open your panel dashboard."
echo "========================================="
