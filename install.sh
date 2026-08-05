#!/bin/bash

echo "========================================="
echo "   RareTrickks Panel Auto-Installer      "
echo "    (Direct SSL + Menu Option Integrated)"
echo "========================================="

# 1. System Update & Dependencies Install
echo "[+] Updating system and installing required packages..."
apt-get update -y
apt-get install python3 python3-pip stunnel4 openssh-server unzip wget certbot -y

# 2. Panel Data Download
echo "[+] Downloading Panel Raw Data..."
wget -O /root/panel_backup.zip "https://github.com/paysafenew8-coder/Alyan/raw/refs/heads/main/panel_backup%20(1).zip"

# 3. Extracting Data
echo "[+] Extracting data to system folders..."
unzip -o /root/panel_backup.zip -d /

# 4. Fixing Permissions
echo "[+] Setting up executable permissions..."
chmod +x /usr/local/bin/raretriccks*.py
chmod +x /usr/local/bin/ws-proxy.py
chmod +x /usr/local/bin/menu
chmod +x /usr/bin/menu

# 5. Creating Direct-Path SSL Script (/usr/bin/add-ssl)
echo "[+] Setting up SSL Manager..."
cat << 'EOF' > /usr/bin/add-ssl
#!/bin/bash
echo "========================================="
echo "       RareTrickks SSL Manager           "
echo "========================================="
read -p "Enter your Domain Name (e.g., pr.alyan.tech): " DOMAIN

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

# 6. Safely Patching the 'menu' script to add SSL Option cleanly
echo "[+] Adding SSL option to Panel Menu..."
python3 - << 'PYEOF'
import os

menu_paths = ['/usr/local/bin/menu', '/usr/bin/menu']
for path in menu_paths:
    if os.path.exists(path):
        with open(path, 'r') as f:
            content = f.read()
        
        # Clean up if old bad patches exist
        content = content.replace("5)\n    add-ssl\n    read -p 'Press Enter to return to menu...'\n    menu\n    ;;\n    0)", "0)")
        
        if "5) Add Domain & Install SSL" not in content:
            content = content.replace("[0-4]", "[0-5]")
            content = content.replace("0) Exit Menu", "5) Add Domain & Install SSL\n0) Exit Menu")
            
            if "0)" in content:
                ssl_case = "5)\n        add-ssl\n        read -p 'Press Enter to return to menu...'\n        menu\n        ;;\n    0)"
                content = content.replace("0)", ssl_case)
            
            with open(path, 'w') as f:
                f.write(content)
PYEOF

chmod +x /usr/local/bin/menu
chmod +x /usr/bin/menu

# 7. Reloading Systemd and Starting Custom Services
echo "[+] Configuring and starting RareTrickks Services..."
systemctl daemon-reload

systemctl enable --now raretriccks-web.service
systemctl enable --now raretriccks-monitor.service
systemctl enable --now ws-proxy.service
systemctl enable --now ip-monitor.service

# 8. Restarting SSH and Stunnel4
echo "[+] Restarting SSH and Stunnel4..."
systemctl restart ssh
systemctl restart stunnel4

# Cleanup
rm -f /root/panel_backup.zip

echo "========================================="
echo " INSTALLATION COMPLETE! "
echo " - Type 'menu' to open your panel dashboard."
echo " - Option 5 is now fully functional!"
echo "========================================="
