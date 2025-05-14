#!/bin/bash
set -e  # Exit the script if any statement returns a non-true return value

echo "Starting Jupyter Lab..."

# Create workspace directory if it doesn't exist, though Dockerfile VOLUME should handle this
mkdir -p /workspace

# Change to a neutral directory before starting Jupyter
cd /

# Start JupyterLab
# Using python3 directly as it should be the default in the PyTorch base image
# The --ServerApp.preferred_dir=/workspace ensures Jupyter starts in your mounted volume
# The nohup and &> /jupyter.log & are removed for now to see logs directly in docker logs
# If you want to background it later and log to a file, we can add them back.
python3 -m jupyter lab \
    --allow-root \
    --no-browser \
    --port=8888 \
    --ip=0.0.0.0 \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.preferred_dir=/workspace \
    --ServerApp.allow_origin='*' \
    --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
    --debug

echo "Jupyter Lab startup attempted. If it exited, check logs above."
echo "If Jupyter is running, this script will now sleep indefinitely to keep the container alive."

# Keep the container running
sleep infinity
