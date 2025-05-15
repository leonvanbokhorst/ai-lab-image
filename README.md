# AI Lab Docker Environment

A custom Docker environment designed for AI/Deep Learning development, featuring PyTorch with CUDA support, the `uv` package manager, and a JupyterLab server. This setup is configured for both local development and deployment on cloud platforms like RunPod, with specific configurations to ensure full functionality (including the JupyterLab terminal).

## Core Components & Features

- **Base Image**: `pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime` (Provides PyTorch with CUDA 12.1)
- **Python Environment**: Managed by the Conda environment within the base image.
- **Package Management**:
  - `pip` (via `python3 -m pip`) for primary package installation.
  - `uv`: A fast Python package installer. It is installed by the `start.sh` script at container startup, making it available for use within the container.
- **JupyterLab Server**:
  - Provides a web-based interactive development environment.
  - Includes a fully functional terminal.
  - Configured for access when running behind a reverse proxy (e.g., on RunPod).
- **Volume Mounting**: The `docker-compose.yml` mounts the local current directory (`.`) to `/workspace` inside the container, allowing for persistent storage and easy file access.
- **GPU Acceleration**: `docker-compose.yml` is configured to request GPU resources for the container.
- **Custom Startup**: Uses a `start.sh` script to install `uv` and then launch JupyterLab with specific flags crucial for stability and functionality, especially in proxied environments.

## Setup and Configuration Details

### Dockerfile

The `Dockerfile` orchestrates the image build:

1.  Starts from the official PyTorch image.
2.  Sets `/bin/bash` as the default shell and configures environment variables for non-interactive package installations (`DEBIAN_FRONTEND=noninteractive`, `ENV SHELL=/bin/bash`).
3.  Installs essential system dependencies (`git`, `curl`, `wget`, `bash`, `locales`, `libpam-modules`, `libssl-dev`, `pkg-config`) and generates the `en_US.UTF-8` locale.
4.  Installs Python packages: `jupyter`, `jupyterlab`, `ipywidgets`, `ipykernel`.
5.  Registers the default Python kernel for Jupyter.
6.  Enables the `jupyter_server_terminals` extension.
7.  Ensures the `/root` directory exists with appropriate permissions.
8.  Copies and makes executable the `start.sh` script, which is set as the `CMD`. (Note: `uv` installation is handled by `start.sh` at runtime).

### `start.sh`

This script is responsible for preparing the environment and launching JupyterLab:

1.  **Installs `uv`**: It checks if `uv` is present; if not, it downloads and installs `uv` to `/root/.local/bin` and adds this location to the `PATH`. This ensures `uv` is available even if there are filesystem quirks on some deployment platforms.
2.  **Launches JupyterLab**: Starts JupyterLab with specific configurations:

```bash
#!/bin/bash
set -e

# Function to install uv if not already available or not the desired version
install_uv() {
    echo "Checking for uv..."
    if command -v uv &> /dev/null; then
        echo "uv is already installed and in PATH."
        uv --version
    else
        echo "uv not found in PATH or not installed. Attempting installation..."
        curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh
        export PATH="/root/.local/bin:${PATH}"
        echo "uv installation attempted to /root/.local/bin."
        echo "Updated PATH: ${PATH}"
        if command -v uv &> /dev/null; then
            echo "uv successfully installed and added to PATH:"
            uv --version
        else
            echo "ERROR: uv installation failed or uv is still not in PATH after attempting install."
        fi
    fi
}

install_uv

echo "Starting Jupyter Lab..."
mkdir -p /workspace # Ensure workspace exists
cd / # Start from a neutral directory

python3 -m jupyter lab \
    --allow-root \
    --no-browser \
    --port=8888 \
    --ip=0.0.0.0 \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.preferred_dir=/workspace \
    --ServerApp.allow_origin='*' \
    --ServerApp.terminado_settings='{\"shell_command\":[\"/bin/bash\"]}' \
    --debug

echo "Jupyter Lab startup attempted. If it exited, check logs above."
sleep infinity
```

Key flags explained:

- `--allow-root`: Necessary as the container runs as root by default.
- `--ip=0.0.0.0`: Makes JupyterLab accessible from outside the container.
- `--ServerApp.token=''` & `--ServerApp.password=''` : Disables token/password authentication for simplicity (suitable for trusted environments or when access is controlled by other means, e.g., RunPod proxy).
- `--ServerApp.preferred_dir=/workspace`: Sets the default directory in JupyterLab to our mounted volume.
- `--ServerApp.allow_origin='*'`: **Crucial for RunPod/proxied environments.** Allows connections from any origin, preventing cross-origin request (CORS) issues that can break UI elements or terminal connections.
- `--ServerApp.terminado_settings='{\"shell_command\":[\"/bin/bash\"]}'`: **Essential for terminal functionality.** Explicitly tells the Jupyter terminal backend (Terminado) to use `/bin/bash` as the shell. This resolves the "Launcher Error - Not Found" for the terminal.
- `--debug`: Provides verbose logging from JupyterLab, helpful for troubleshooting.
- `sleep infinity`: Keeps the container running after JupyterLab starts.

### `docker-compose.yml`

Provides a convenient way to build and run the container:

- Builds the image using the `Dockerfile` in the current context.
- Maps port `8888` on the host to `8888` in the container.
- Mounts the current directory (`.`) to `/workspace` in the container.
- Includes a `deploy` section to request GPU resources (NVIDIA driver, all GPUs).

## Usage

### Prerequisites

- Docker installed.
- Docker Compose installed.
- NVIDIA drivers installed on the host machine if GPU support is needed.

### Build the Image

```bash
docker-compose build
```

### Run Locally

```bash
# Start the container (logs will be shown in the terminal)
docker-compose up

# Or, to run in detached mode (background)
docker-compose up -d
```

### Access JupyterLab

Once the container is running, open your web browser and navigate to:
`http://localhost:8888`

### Deploying to Docker Hub (Example with username `leonvanbokhorst`)

1.  Tag the image:
    ```bash
    docker tag ai-lab-image-pytorch-jupyter leonvanbokhorst/ai-lab-image-pytorch-jupyter:latest
    ```
2.  Login to Docker Hub:
    ```bash
    docker login
    ```
3.  Push the image:
    ```bash
    docker push leonvanbokhorst/ai-lab-image-pytorch-jupyter:latest
    ```

### Using on RunPod

1.  Push the image to Docker Hub as described above.
2.  When creating a pod on RunPod, use your tagged image (e.g., `leonvanbokhorst/ai-lab-image-pytorch-jupyter:latest`).
3.  RunPod should automatically map the necessary ports. The JupyterLab instance will be accessible via the "Connect to HTTP Service" button on your RunPod pod interface.
4.  The configurations in `start.sh` (especially `--ServerApp.allow_origin='*'` and `--ServerApp.terminado_settings`) are essential for full functionality on RunPod.

### Working with the Container

- Files placed in your local project directory (where `docker-compose.yml` resides) will appear in `/workspace` inside the JupyterLab environment and vice-versa.
- To execute commands inside the running container:
  ```bash
  # Find your container ID or name
  docker ps
  # Execute a bash shell in the container
  docker exec -it <container_id_or_name> bash
  ```

### Using `uv` Package Manager

`uv` is installed at container startup by the `start.sh` script and made available on the `PATH`. To use it inside the container's shell:

```bash
# Install a package
uv pip install some-package

# Create and manage virtual environments (optional but recommended for complex projects)
uv venv myenv
source myenv/bin/activate
uv pip install -r requirements.txt
```

### Stopping the Container

```bash
# If running in the foreground (docker-compose up)
Ctrl+C

# If running in detached mode (docker-compose up -d)
docker-compose down
```

This updated README should provide a much clearer picture of your powerful AI Lab environment!
 