ARG IMAGE_TAG=beta-debian
FROM meshtastic/meshtasticd:${IMAGE_TAG}

# Install python and meshtastic CLI needed for the provisioning script
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages meshtastic

# Copy entrypoint script and python provisioner
COPY entrypoint.sh /entrypoint.sh
COPY provision.py /provision.py
RUN chmod +x /entrypoint.sh

# Provide a default configuration directory
VOLUME /var/opt/meshtasticd

ENTRYPOINT ["/entrypoint.sh"]
