#!/bin/bash -e
################################################################################
##  File:  install-zeek.sh
##  Desc:  Build & install Zeek 8.2.0 from source (works on arm64 and amd64)
################################################################################

source $HELPER_SCRIPTS/install.sh

ZEEK_VERSION="8.2.0"
ZEEK_PREFIX="/opt/zeek"
SRC_URL="https://download.zeek.org/zeek-${ZEEK_VERSION}.tar.gz"
BUILD_DIR="$(mktemp -d)"

apt-get update
apt-get install --no-install-recommends -y \
  ca-certificates curl ethtool \
  bison cmake flex g++ gcc git make ninja-build \
  libfl-dev libpcap-dev libssl-dev zlib1g-dev \
  libzmq3-dev cppzmq-dev \
  python3 python3-dev swig

cd "$BUILD_DIR"
curl -fsSL "$SRC_URL" -o zeek.tar.gz
tar xzf zeek.tar.gz
cd "zeek-${ZEEK_VERSION}"

# --- configure & build ---------------------------------------------------------
./configure \
  --prefix="${ZEEK_PREFIX}" \
  --generator=Ninja \
  --build-type=Release \
  --disable-auxtools

cd build
ninja -j 2
ninja install

# --- cleanup -------------------------------------------------------------------
cd /
rm -rf "$BUILD_DIR"

ln -sf "${ZEEK_PREFIX}/bin/zeek"      /usr/local/bin/zeek
ln -sf "${ZEEK_PREFIX}/bin/zeek-cut"  /usr/local/bin/zeek-cut
cat > /etc/profile.d/zeek.sh << EOF
export PATH="${ZEEK_PREFIX}/bin:\$PATH"
EOF

if [[ ! -x "${ZEEK_PREFIX}/bin/zeek" ]]; then
  echo "ERROR: zeek binary not found after build (arch=$(dpkg --print-architecture))" >&2
  exit 1
fi
"${ZEEK_PREFIX}/bin/zeek" --version

echo "zeek (source ${ZEEK_VERSION}) ${SRC_URL}" >> $HELPER_SCRIPTS/apt-sources.txt

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
# KVM/virtio guests offload checksums, so captured outbound packets carry
# bogus checksums and Zeek would discard them (dropping ClientHello/SNI and
# DNS queries). Disable NIC offload so the kernel computes checksums correctly.
ethtool -K "$iface" rx off tx off gro off gso off tso off 2>/dev/null || true
# Belt-and-suspenders: also tell Zeek to ignore checksum validation (-C),
# the recommended setting for capturing inside virtualized environments.
exec /opt/zeek/bin/zeek -C -i "$iface" LogAscii::use_json=T -e "redef Log::default_rotation_interval = 0sec;"
WRAPPER
chmod +x /usr/local/bin/zeek-capture.sh

cat > /etc/systemd/system/zeek-capture.service << 'UNIT'
[Unit]
Description=Zeek network analyzer for per-domain bandwidth capture
After=network-online.target
Wants=network-online.target

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

#invoke_tests "Tools" "zeek"
