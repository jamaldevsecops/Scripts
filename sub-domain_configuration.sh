#!/bin/bash

# Prompt for user inputs
read -p "Enter subdomain: " SUB_DOMAIN
read -p "Enter proxy server IP: " PROXY_IP
read -p "Enter proxy server port: " PROXY_PORT

# Additional variables
DOMAIN="apsissolutions.com"
SSL_CERT="/etc/ssl/certs/apsis/apsissolutions_Bundle.crt"
SSL_KEY="/etc/ssl/certs/apsis/apsissolutions.com.key"

# Remote server connection details
REMOTE_HOST="192.168.11.253"
REMOTE_USER="ops"
REMOTE_PASSWORD="Dhaka@123"
REMOTE_PORT="22"  # Fixed SSH port

# Define the Nginx site configuration file path on the remote server
NGINX_SITE_CONFIG="/etc/nginx/sites-available/${SUB_DOMAIN}"

# Create the Nginx site configuration file locally
cat > "${SUB_DOMAIN}.conf" <<EOF
server {
    listen 80;
    server_name ${SUB_DOMAIN}.${DOMAIN};
    return 301 https://${SUB_DOMAIN}.${DOMAIN}\$request_uri;
}

server {
    server_name ${SUB_DOMAIN}.${DOMAIN};
    keepalive_timeout 70;
    server_tokens off;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin";
    add_header X-XSS-Protection "1; mode=block";
    add_header 'Access-Control-Allow-Origin' 'https://${SUB_DOMAIN}.${DOMAIN}' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
    add_header Permissions-Policy "geolocation=(),midi=(),sync-xhr=(),microphone=(),camera=(),magnetometer=(),gyroscope=(),fullscreen=(self),payment=()";

    location / {
        proxy_pass http://${PROXY_IP}:${PROXY_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    listen 443 ssl http2;
    ssl_certificate ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    ssl_stapling on;
    ssl_stapling_verify on;
}
EOF

# Copy the Nginx site configuration file to the remote server
scp -P "${REMOTE_PORT}" "${SUB_DOMAIN}.conf" "${REMOTE_USER}@${REMOTE_HOST}:${NGINX_SITE_CONFIG}"

# SSH into the remote server using the specified remote SSH port and perform the remaining tasks
sshpass -p "${REMOTE_PASSWORD}" ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" <<SSH_COMMANDS
# Create a symbolic link to enable the site
sudo ln -s "$NGINX_SITE_CONFIG" "/etc/nginx/sites-enabled/${SUB_DOMAIN}"

# Check Nginx configuration
sudo nginx -t

# Restart Nginx if configuration is valid
if [ \$? -eq 0 ]; then
    sudo systemctl restart nginx
    echo "Nginx restarted."
else
    echo "Nginx configuration test failed. Check the configuration file."
fi
SSH_COMMANDS

# Clean up the local configuration file
rm "${SUB_DOMAIN}.conf"

