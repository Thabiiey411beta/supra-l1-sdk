cat <<EOF > liqui-mind/scripts/setup_ipfs.sh
#!/bin/bash
sudo apt update
wget https://dist.ipfs.io/go-ipfs/v0.20.0/go-ipfs_v0.20.0_linux-amd64.tar.gz
tar -xvzf go-ipfs_v0.20.0_linux-amd64.tar.gz
cd go-ipfs
sudo bash install.sh
ipfs init
ipfs daemon &
EOF
chmod +x liqui-mind/scripts/setup_ipfs.sh