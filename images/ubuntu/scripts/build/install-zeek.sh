#!/bin/bash -e
################################################################################
##  File:  install-zeek.sh
##  Desc:  Install Zeek network analyzer for per-domain bandwidth observability
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

ubuntu_version=$(lsb_release -rs)
REPO_URL="https://download.opensuse.org/repositories/security:/zeek/xUbuntu_${ubuntu_version}"
GPG_KEY="/usr/share/keyrings/zeek.gpg"
REPO_PATH="/etc/apt/sources.list.d/zeek.list"

curl -fsSL "${REPO_URL}/Release.key" | gpg --dearmor > $GPG_KEY
echo "deb [signed-by=$GPG_KEY] ${REPO_URL}/ /" > $REPO_PATH

apt-get update
apt-get install --no-install-recommends -y zeek

rm $GPG_KEY
rm $REPO_PATH

echo "zeek $REPO_URL" >> $HELPER_SCRIPTS/apt-sources.txt

# Wrapper: detect primary interface and exec zeek
cat > /usr/local/bin/zeek-capture.sh << 'WRAPPER'
#!/bin/bash
set -e
mkdir -p /tmp/zeek
cd /tmp/zeek
iface=$(ip -o link show up | awk -F': ' '{print $2}' | grep -vE "^(lo|docker|veth|br|virbr)" | head -n 1)
if [[ -z "$iface" ]]; then
  echo "No capture interface found" >&2
  exit 1
fi
echo "Capturing on $iface"
exec /opt/zeek/bin/zeek -i "$iface" LogAscii::use_json=T -e "redef Log::default_rotation_interval = 0sec;"
WRAPPER
chmod +x /usr/local/bin/zeek-capture.sh

# Systemd unit: start after network is up and cloud-init has finished
# (cloud-init reconfigures netplan, so starting before it would race)
cat > /etc/systemd/system/zeek-capture.service << 'UNIT'
[Unit]
Description=Zeek network analyzer for per-domain bandwidth capture
After=network-online.target cloud-init.target
Wants=network-online.target
Requires=cloud-init.target

[Service]
Type=simple
ExecStart=/usr/local/bin/zeek-capture.sh
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/zeek-capture.log
StandardError=append:/var/log/zeek-capture.log

[Install]
WantedBy=multi-user.target
UNIT

systemctl enable zeek-capture.service

invoke_tests "Tools" "zeek"
