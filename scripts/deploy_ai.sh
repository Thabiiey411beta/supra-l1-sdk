cat <<EOF > liqui-mind/scripts/deploy_ai.sh
#!/bin/bash
AKASH_KEY_NAME="liquimind"
MODEL_PATH="./models/trading_model.zip"
akash provider deploy --key \$AKASH_KEY_NAME --image python:3.8 --command "python3 main.py" --input \$MODEL_PATH
EOF
chmod +x liqui-mind/scripts/deploy_ai.sh