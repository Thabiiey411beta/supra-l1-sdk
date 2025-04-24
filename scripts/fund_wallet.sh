cat <<EOF > liqui-mind/scripts/fund_wallet.sh
#!/bin/bash
docker run --rm -e SUPRA_RPC=\${SUPRA_RPC} -e PRIVATE_KEY="priority bone rhythm endorse face more spike viable beach project tell rude" supraoracles/supra-cli:latest fund --amount 1000000000000000000
EOF
chmod +x liqui-mind/scripts/fund_wallet.sh