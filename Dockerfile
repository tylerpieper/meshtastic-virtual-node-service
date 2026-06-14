FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gpg \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Add OBS repository for meshtasticd
RUN echo 'deb http://download.opensuse.org/repositories/network:/Meshtastic:/beta/Debian_12/ /' | tee /etc/apt/sources.list.d/network:Meshtastic:beta.list \
    && curl -fsSL https://download.opensuse.org/repositories/network:Meshtastic:beta/Debian_12/Release.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/network_Meshtastic_beta.gpg > /dev/null \
    && apt-get update \
    && apt-get install -y meshtasticd \
    && rm -rf /var/lib/apt/lists/*

# Install meshtastic python CLI
RUN pip3 install --break-system-packages meshtastic

# Copy entrypoint script and python provisioner
COPY entrypoint.sh /entrypoint.sh
COPY provision.py /provision.py
RUN chmod +x /entrypoint.sh

# Provide a default configuration directory
VOLUME /var/opt/meshtasticd

ENTRYPOINT ["/entrypoint.sh"]
