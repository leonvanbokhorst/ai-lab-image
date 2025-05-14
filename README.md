# AI Lab Docker Environment

A Docker environment with PyTorch, uv package manager, and Jupyter Lab for AI development.

## Features

- PyTorch with CUDA support
- uv package manager for faster Python package installation
- Jupyter Lab server
- Volume mounting for local development

## Usage

### Build and Start

```bash
# Build and start the container
docker-compose up

# Or build and run in detached mode
docker-compose up -d
```

### Access Jupyter Lab

Once running, access Jupyter Lab at:

```
http://localhost:8888
```

### Working with the Container

Your current directory is mounted as a volume to `/workspace` in the container,
so any files you create or modify will persist on your local machine.

### Using uv Package Manager

uv is a fast Python package installer. To use it inside the container:

```bash
# Enter the container
docker exec -it ai-lab-image_pytorch-jupyter_1 bash

# Install packages with uv
uv pip install package-name
```

### Stopping the Container

```bash
# If running in foreground, use Ctrl+C
# If running in detached mode
docker-compose down
```
