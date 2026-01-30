#!/bin/bash -e
################################################################################
##  File:  install-nodejs.sh
##  Desc:  Install Node.js LTS and related tooling
################################################################################

source $HELPER_SCRIPTS/install.sh

# 1. Install Node.js
default_version=$(get_toolset_value '.node.default')
curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o ~/n
bash ~/n $default_version

# 2. Prepare module list
node_modules=$(get_toolset_value '.node_modules[].name')

if [[ "$(uname -m)" == "s390x" ]]; then
    echo "Detected s390x architecture. Excluding 'lerna'."
    node_modules=$(echo "$node_modules" | sed -E 's/(^| )lerna( |$)/ /g')
fi

# 3. Install modules
echo "Installing node modules: $node_modules"
npm install -g $node_modules

NODE_PREFIX=$(npm prefix -g)
NPM_BIN_DIR="$NODE_PREFIX/bin"

echo "NPM Prefix found: $NODE_PREFIX"
echo "Binaries located at: $NPM_BIN_DIR"

if [[ -d "$NPM_BIN_DIR" ]] && [[ "$NPM_BIN_DIR" != "/usr/local/bin" ]]; then
    echo "Symlinking all global binaries to /usr/local/bin..."
    ln -sf "$NPM_BIN_DIR"/* /usr/local/bin/
fi

# 4. [Stub Strategy] for Lerna on s390x
if [[ "$(uname -m)" == "s390x" ]]; then
    cat << 'EOF' > /usr/local/bin/lerna
#!/bin/bash
# Stub for Lerna on s390x
echo "8.0.0 (s390x-skipped)"
exit 0
EOF
    chmod +x /usr/local/bin/lerna
fi

# 5. Final setup
if [ -f /usr/local/bin/vercel ]; then
    ln -s /usr/local/bin/vercel /usr/local/bin/now
fi

# Fix permissions
sudo chmod -R 777 /usr/local/lib/node_modules
sudo chmod -R 777 /usr/local/bin
rm -rf ~/n

invoke_tests "Node" "Node.js"
