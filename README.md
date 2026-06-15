# Meshtastic Virtual Node Service

A fully dockerized, head-less [Meshtastic](https://meshtastic.org/) virtual node (running on the native Portduino build) that automatically provisions itself based on environment variables! 

Unlike a standard physical radio, this container dynamically configures its database on first boot. It is perfectly suited for running AI bots, MQTT bridges, or home automation integrations without dedicating physical hardware to the task.

## Features
- **Zero-Touch Provisioning:** No need to connect via serial or bluetooth. The node builds its `NodeDB` and sets LoRa regions, channel keys, and identity completely autonomously via a python provisioning script on first boot.
- **Persistent Keys:** Generates and maintains a permanent Node ID and cryptographic keys inside the mounted `/data` volume.
- **Client Mute by Default:** Configured as a `CLIENT_MUTE` node out of the box, preventing it from needlessly echoing packets and consuming network bandwidth (since it lacks an actual radio antenna!).
- **Custom MAC Addressing:** Optionally specify a static MAC Address to guarantee a deterministic Node ID.

> [!IMPORTANT]
> **Network Bridging Requirement**
> Because this is a headless virtual node without physical radio hardware, it relies entirely on IP network transport. In order to actually send and receive packets to an RF mesh, **you must have at least one physical Meshtastic node on the same local subnet with UDP enabled.** The virtual node will automatically discover and bridge with it.

---

## 🚀 Quick Start

1. Clone the repository and rename the environment template:
```bash
git clone https://github.com/yourusername/meshtastic-virtual-node-service.git
cd meshtastic-virtual-node-service
cp .env.example .env
```

2. Edit `.env` to configure your node's identity, GPS location, and Channel settings.

3. Spin up the container!
```bash
docker compose up -d
```

You can now connect your Meshtastic mobile app or python scripts directly to the node via TCP on port `44404`!

---

## ⚙️ Configuration Variables

All configuration is handled seamlessly through the `.env` file.

| Variable | Default | Description |
|---|---|---|
| `MAC_ADDRESS` | *(Random)* | Set a static MAC address to force a specific Hex Node ID. E.g. `AA:BB:CC:DD:EE:FF` |
| `IMAGE_TAG` | `beta-debian` | The official `meshtastic/meshtasticd` image tag to build from. |
| `NODE_LONG_NAME` | `Virtual Node` | The long name visible to other users on the mesh. |
| `NODE_SHORT_NAME`| `VIRT` | The 4-character short name. |
| `NODE_ROLE` | `1` | Meshtastic Role. Default `1` is `CLIENT_MUTE`. |
| `CHANNEL_NAME` | `LongFast` | The primary channel preset. |
| `CHANNEL_KEY` | `AQ==` | The Base64 encryption key. `AQ==` is the standard "Default" mesh key. |
| `LATITUDE` | *(None)* | Fixed GPS Latitude. |
| `LONGITUDE` | *(None)* | Fixed GPS Longitude. |
| `POSITION_PRECISION` | `14` | [See here for more info](https://meshtastic.org/docs/configuration/radio/channels/#position-precision) |
| `API_PORT` | `44404` | The TCP port exposed for the Meshtastic API. |
| `HOP_LIMIT` | `7` | The default maximum hop limit for outbound packets. |
| `DATA_DIR` | `./data` | Where the persistent NodeDB and configuration files are stored. |

---

## 🛠️ How It Works

When the container launches, a custom `entrypoint.sh` runs:
1. It checks the mounted `DATA_DIR` to see if a valid Meshtastic database exists.
2. If it is a fresh boot, it generates a spoofed MAC address and triggers a temporary, isolated instance of `meshtasticd` to generate cryptographic keys.
3. It runs a Python provisioning script (`provision.py`) to inject your `.env` variables directly into the new NodeDB.
4. Finally, it launches the permanent `meshtasticd` daemon, fully configured and ready to communicate!

*(Note: If you ever change your `.env` variables and want them to take effect, you must delete the `./data` directory to trigger a fresh provisioning run!)*
