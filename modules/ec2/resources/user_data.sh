#!/bin/bash

# Get version ID
VERSION_ID=$(awk -F '[="]*' '/^VERSION_ID/ { print $2 }' < /etc/os-release)
echo "▶ FOUND AMAZON LINUX $VERSION_ID"

sudo yum update -y

# Create tmp folder that mongo util needs
mkdir /tmp/public

# Add Node repo
if [ "$VERSION_ID" = "2" ]; then 
    #AL2
    curl -fsSL https://rpm.nodesource.com/setup_14.x | bash -
    export AWS_REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/region`
else
    #AL2023
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -

    #AL2023, used IMDv2 by default to retrieve the instance metadata.
    TOKEN=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
    export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region --header "X-aws-ec2-metadata-token: $TOKEN")
fi

# Package installs
sudo yum install nodejs git jq ruby wget -y

# Code Agent install
cd /home/ec2-user

wget https://aws-codedeploy-$AWS_REGION.s3.$AWS_REGION.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

# Clone nightscout repo (do this as codepipeline fails until connection authenticated)
cd /srv
sudo git clone https://github.com/nightscout/cgm-remote-monitor.git
cd cgm-remote-monitor

# Create a swap file because npm run posinstall is hungry
#export NODE_OPTIONS="--max-old-space-size=5120"
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Setup systemctl service
sudo cat > /etc/systemd/system/nightscout.service << EOL
[Unit]
Description=Nightscout Service
After=network.target
[Service]
Type=simple
WorkingDirectory=/srv/cgm-remote-monitor
ExecStart=/srv/cgm-remote-monitor/node_modules/.bin/env-cmd node /srv/cgm-remote-monitor/lib/server/server.js
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl daemon-reload
sudo systemctl enable nightscout.service

# Setup CodeDeploy / appspec scripts
sudo mkdir /opt/codedeploy-agent/scripts

#sudo cat > /opt/codedeploy-agent/scripts/before_install.sh << EOL
# This cat don't change variables
#sudo cat <<"EOL" >/opt/codedeploy-agent/scripts/before_install.sh
#[[BEFORE_INSTALL]]
#EOL

sudo cat > /opt/codedeploy-agent/scripts/after_install.sh << EOL
[[AFTER_INSTALL]]
EOL

sudo cat > /opt/codedeploy-agent/scripts/app_start.sh << EOL
[[APP_START]]
EOL

sudo cat > /opt/codedeploy-agent/scripts/app_stop.sh << EOL
[[APP_STOP]]
EOL

# Create cronjob
sudo cat > /opt/codedeploy-agent/scripts/cron_ssm.sh << EOL
[[CRON_SSM]]
EOL



# Create cronjob that gets env vars from SSM every 10 minutes & restarts if changes
# Removed, only get 20,000 calls to AWS Key Management Service per month & prev SSM was storing as SecureString.
# I think we can revert this after updating SSM.
if [ "$VERSION_ID" = "2" ]; then 
    crontab -l ; echo "*/10 * * * * sudo /opt/codedeploy-agent/scripts/cron_ssm.sh >/dev/null 2>&1" | crontab -
else
    sudo dnf install -y cronie
    sudo crontab -l -u ec2-user| { cat; echo "*/10 * * * * sudo /opt/codedeploy-agent/scripts/cron_ssm.sh >/dev/null 2>&1"; } | sudo crontab -u ec2-user -
fi

## GENERATE SCRIPT MANUAL TO CREATE CERTITICATE LETS ENCRYPT
# This cat don't change variables
sudo cat <<"EOL" >/opt/codedeploy-agent/scripts/manual_generate_cert_lets.sh
#!/bin/bash
## RUN AFTER REDIRECTED TO DOMAIN
DOMAIN=nightscout.leguedex.com
letsencrypt_subscriber_email=rogeriosilvarocha@gmail.com

echo "▶ creating certificate"
sudo certbot run --non-interactive --agree-tos --email "$letsencrypt_subscriber_email" \
  --nginx --domains "$DOMAIN"

echo "▶ restarting NGINX"
sudo systemctl restart nginx
EOL
##

# Make scripts executable
sudo chmod +x /opt/codedeploy-agent/scripts/*.sh


### install Nginx
#!/bin/bash
DOMAIN=nightscout.leguedex.com
letsencrypt_subscriber_email=rogeriosilvarocha@gmail.com

echo "▶ installing nginx"
sudo yum update -y

#sudo amazon-linux-extras install -y nginx1
sudo yum install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

echo "▶ Updating NGINX Server $DOMAIN"
BLOCK="/etc/nginx/conf.d/$DOMAIN.conf"
sudo tee $BLOCK > /dev/null <<EOF

server {
    server_name  $DOMAIN;
    root         /usr/share/nginx/html;

    # Load configuration files for the default server block.
    include /etc/nginx/default.d/*.conf;

    error_page 404 /404.html;
    location = /404.html {
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }

    location / {
      proxy_pass http://localhost:8080;
    }
}
EOF

echo "▶ installing certbot"
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

echo "▶ Setting crontab certbot renew"
sudo dnf install -y cronie

sudo crontab -l -u ec2-user| { cat; echo "0 3 * * * sudo certbot renew >/dev/null 2>&1"; } | sudo crontab -u ec2-user -