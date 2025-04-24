cat <<EOF > liqui-mind/scripts/setup_codespaces.sh
#!/bin/bash
sudo apt update
sudo apt install -y python3 python3-pip nodejs npm docker.io
docker pull supraoracles/supra-cli:latest
wget https://dist.ipfs.io/go-ipfs/v0.20.0/go-ipfs_v0.20.0_linux-amd64.tar.gz
tar -xvzf go-ipfs_v0.20.0_linux-amd64.tar.gz
cd go-ipfs
sudo bash install.sh
ipfs init
pip3 install -r requirements.txt
npm install @supra/sdk@1.0.0
sudo systemctl start docker
EOF
chmod +x liqui-mind/scripts/setup_codespaces.sh