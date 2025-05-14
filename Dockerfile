FROM pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime

# Set working directory
WORKDIR /workspace

# Set default shell and environment for non-interactive installs
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    bash \
    locales \
    libpam-modules \
    libssl-dev \
    pkg-config \
    gcc \
    g++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generate locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

# uv will be installed via start.sh

# Install Jupyter and Python packages
RUN pip install --no-cache-dir \
    jupyter \
    jupyterlab \
    ipywidgets \
    ipykernel

# Register the Python kernel
RUN python -m ipykernel install --user

# Enable Jupyter server terminals extension
RUN jupyter server extension enable jupyter_server_terminals

# Ensure /root directory exists and has correct permissions
RUN mkdir -p /root && chmod 755 /root

# Expose Jupyter port
EXPOSE 8888

# Create volume mount point
VOLUME /workspace

# Copy start script and make it executable
ADD start.sh /
RUN chmod +x /start.sh

# Set the default command for the container
CMD [ "/start.sh" ] 