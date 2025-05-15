#!/bin/bash
set -e  # Exit the script if any statement returns a non-true return value

# Function to install uv if not already available or not the desired version
install_uv() {
    echo "Checking for uv..."
    if command -v uv &> /dev/null; then
        echo "uv is already installed and in PATH."
        uv --version
    else
        echo "uv not found in PATH or not installed. Attempting installation..."
        # Install uv, letting it use its default $HOME/.local/bin (which is /root/.local/bin)
        # The -L flag for curl is important to follow redirects from astral.sh
        # Set UV_NO_MODIFY_PATH=1 as per the installer's deprecation warning
        curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh
        
        # Add /root/.local/bin to PATH for the current script and subsequent processes
        # This is crucial if the installer doesn't modify .bashrc or if .bashrc isn't sourced by Jupyter's terminals
        export PATH="/root/.local/bin:${PATH}"
        echo "uv installation attempted to /root/.local/bin."
        echo "Updated PATH: ${PATH}"
        
        if command -v uv &> /dev/null; then
            echo "uv successfully installed and added to PATH:"
            uv --version
        else
            echo "ERROR: uv installation failed or uv is still not in PATH after attempting install."
            # Optionally, you might want to exit here if uv is critical: exit 1
        fi
    fi
}

# Install uv
install_uv

echo "Starting Jupyter Lab..."

# Create workspace directory if it doesn't exist, though Dockerfile VOLUME should handle this
mkdir -p /workspace

# Change to a neutral directory before starting Jupyter
cd /

# Start JupyterLab
# The PATH should now include uv if installed by the function above
python3 -m jupyter lab \
    --allow-root \
    --no-browser \
    --port=8888 \
    --ip=0.0.0.0 \
    --ServerApp.token=${JUPYTER_TOKEN} \
    --ServerApp.preferred_dir=/workspace \
    --ServerApp.allow_origin='*' \
    --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}'

echo "Jupyter Lab startup attempted. If it exited, check logs above."
