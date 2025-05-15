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
3.  **Persistent Cache Configuration**: Sets environment variables to ensure that caches for Hugging Face, `uv`, and `pip` are stored on the mounted `/workspace` volume, making them persistent across container runs:
    - `ENV HF_HOME=/workspace/.cache/huggingface`
    - `ENV UV_CACHE_DIR=/workspace/.cache/uv`
    - `ENV PIP_CACHE_DIR=/workspace/.cache/pip`
    - `ENV UV_LINK_MODE=copy`: Configures `uv` to copy files from its cache, which is necessary when the cache directory and the target installation directory are on different filesystems (like our volume mount setup). This prevents potential hardlinking issues.
4.  Installs essential system dependencies (`git`, `curl`, `wget`, `bash`, `locales`, `libpam-modules`, `libssl-dev`, `pkg-config`, `gcc`, `g++`) and generates the `en_US.UTF-8` locale. Note: `gcc` and `g++` are included for tools like Triton that may need to compile code on the fly.
5.  Installs Python packages: `jupyter`, `jupyterlab`, `ipywidgets`, `ipykernel` using `pip` with `--no-cache-dir` to keep the image layers lean.
6.  Registers the default Python kernel for Jupyter.
7.  Enables the `jupyter_server_terminals` extension.
8.  Ensures the `/root` directory exists with appropriate permissions.
9.  Copies and makes executable the `start.sh` script, which is set as the `CMD`. (Note: `uv` installation is handled by `start.sh` at runtime).

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

python3 -m jupyter lab \\
    --allow-root \\
    --no-browser \\
    --port=8888 \\
    --ip=0.0.0.0 \\
    --ServerApp.token=${JUPYTER_TOKEN} \\
    --ServerApp.preferred_dir=/workspace \\
    --ServerApp.allow_origin='*' \\
    --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}'

echo "Jupyter Lab startup attempted. If it exited, check logs above."
```

Key flags explained:

- `--allow-root`: Necessary as the container runs as root by default.
- `--ip=0.0.0.0`: Makes JupyterLab accessible from outside the container.
- `--ServerApp.token=${JUPYTER_TOKEN}`: Configures JupyterLab to use a token for authentication. The actual token value is passed via the `JUPYTER_TOKEN` environment variable (see "Authentication" section below). This is a security measure to protect your JupyterLab instance.
- `--ServerApp.preferred_dir=/workspace`: Sets the default directory in JupyterLab to our mounted volume.
- `--ServerApp.allow_origin='*'`: **Crucial for RunPod/proxied environments.** Allows connections from any origin, preventing cross-origin request (CORS) issues that can break UI elements or terminal connections.
- `--ServerApp.terminado_settings='{\\"shell_command\\":[\\"/bin/bash\\"]}'`: **Essential for terminal functionality.** Explicitly tells the Jupyter terminal backend (Terminado) to use `/bin/bash` as the shell. This resolves the "Launcher Error - Not Found" for the terminal.

The script no longer uses `--debug` for quieter default operation, nor `sleep infinity` as JupyterLab itself keeps the container running.

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

Upon first access, JupyterLab will prompt you for a token. See the "Authentication" section below for how to set this up.

### Authentication

This JupyterLab setup uses token-based authentication for security. The token is passed to JupyterLab via the `JUPYTER_TOKEN` environment variable.

**Recommended Method: `.env` file**

1.  Create a file named `.env` in the root of your project directory (the same directory as `docker-compose.yml`).
2.  Add your desired token to this file:
    ```
    JUPYTER_TOKEN=your_super_secret_and_unique_token_here
    ```
    Replace `your_super_secret_and_unique_token_here` with a strong, private token.
3.  The project includes a `.gitignore` file that is already configured to ignore the `.env` file, so your token will not be accidentally committed to version control.

When you run `docker-compose up`, Docker Compose will automatically load the `JUPYTER_TOKEN` from the `.env` file and make it available to the container.

**Alternative: Exporting as a Shell Environment Variable**

You can also set the token by exporting it as an environment variable in your shell before running Docker Compose:

```bash
export JUPYTER_TOKEN="your_super_secret_and_unique_token_here"
docker-compose up
```

This method requires you to set the variable in each new terminal session or add it to your shell's startup configuration file (e.g., `.bashrc`, `.zshrc`).

When you access JupyterLab in your browser, you will be prompted to enter this token.

### Deploying to Docker Hub (Example with username `leonvanbokhorst`)

1.  Build your image if you've made changes:
    ```bash
    docker-compose build
    ```
2.  Tag the image. The image built by `docker-compose` is typically named `ai-lab-image-pytorch-jupyter` (based on the project directory and service name in `docker-compose.yml`). You'll want to tag this with your Docker Hub repository name and a version.
    ```bash
    # First, find the IMAGE ID of your recently built image (e.g., via 'docker images ai-lab-image-pytorch-jupyter')
    # Let's say the ID is 'abcdef123456'
    docker tag abcdef123456 leonvanbokhorst/ai-lab-image:1.3.0
    docker tag abcdef123456 leonvanbokhorst/ai-lab-image:latest
    ```
    (Replace `1.3.0` with your desired version tag and `abcdef123456` with the actual image ID).
3.  Login to Docker Hub:
    ```bash
    docker login
    ```
4.  Push the tags:
    ```bash
    docker push leonvanbokhorst/ai-lab-image:1.3.0
    docker push leonvanbokhorst/ai-lab-image:latest
    ```

### Using on RunPod

1.  Push the image to Docker Hub as described above (e.g., `leonvanbokhorst/ai-lab-image:latest` or a specific version).
2.  When creating a pod on RunPod, use your tagged image (e.g., `leonvanbokhorst/ai-lab-image:latest`).
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

`uv` is installed at container startup by the `start.sh` script and made available on the `PATH`. Its cache is directed to `/workspace/.cache/uv` on the persistent volume. To use it inside the container's shell:

```bash
# Install a package
uv pip install some-package

# Create and manage virtual environments (optional but recommended for complex projects)
uv venv myenv
source myenv/bin/activate
uv pip install -r requirements.txt
```

### Persistent Caches

To improve performance and avoid re-downloading packages and models, this environment is configured to store caches on the persistently mounted `/workspace` volume. You will find the following directories created in your project folder on your host machine (which is mounted to `/workspace`):

- `.cache/huggingface`: For Hugging Face models, datasets, etc.
- `.cache/uv`: For packages downloaded by `uv`.
- `.cache/pip`: For packages downloaded by `pip` (if used directly in the running container).

These caches will persist even if you stop and remove the Docker container, as long as your local project directory remains.

### Stopping the Container

```bash
# If running in the foreground (docker-compose up)
Ctrl+C

# If running in detached mode (docker-compose up -d)
docker-compose down
```

This updated README should provide a much clearer picture of your powerful AI Lab environment!

This setup aims to provide a robust, reproducible, and efficient environment for your deep learning endeavors. May the Force be with your code!
