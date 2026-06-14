import os
import sys
import time
import meshtastic
import meshtastic.tcp_interface
from pubsub import pub

def provision():
    port = int(os.environ.get("API_PORT", 44404))
    print(f"Connecting to meshtasticd on localhost:{port}...")
    
    interface = None
    for _ in range(15):
        try:
            interface = meshtastic.tcp_interface.TCPInterface(hostname="127.0.0.1", portNumber=port)
            break
        except Exception as e:
            time.sleep(2)
            
    if not interface:
        print("Failed to connect!")
        sys.exit(1)
        
    print("Connected. Provisioning node...")
    
    # Set owner
    long_name = os.environ.get("NODE_LONG_NAME", "Mesh Ollama")
    short_name = os.environ.get("NODE_SHORT_NAME", "OLMA")
    
    # We don't use setOwner here because it triggers a reboot. We just set the node info directly.
    # Actually setOwner is safe if we wait. Let's just do it at the end, or set it via API.
    
    # Set Network Config (UDP Broadcast)
    # enabled_protocols is a bitmask. 1 = UDP_BROADCAST
    interface.localNode.localConfig.network.enabled_protocols = 1
    
    # Set Device Config
    interface.localNode.localConfig.device.node_info_broadcast_secs = 10800
    
    # Disable Telemetry
    interface.localNode.moduleConfig.telemetry.device_telemetry_enabled = False
    
    # Set Position Config
    lat = os.environ.get("LATITUDE", "")
    lon = os.environ.get("LONGITUDE", "")
    if lat and lon:
        interface.localNode.localConfig.position.fixed_position = True
        interface.localNode.localConfig.position.position_broadcast_smart_enabled = False
        interface.localNode.localConfig.position.position_broadcast_secs = 43200
        interface.localNode.localConfig.position.gps_update_interval = 21600
        # The python API requires sending the position as a packet to fix it
        try:
            interface.sendPosition(latitude=float(lat), longitude=float(lon))
        except Exception as e:
            print(f"Warning: Could not send position packet: {e}")
    else:
        interface.localNode.localConfig.position.fixed_position = False
        interface.localNode.localConfig.position.position_broadcast_secs = 0
        interface.localNode.localConfig.position.gps_update_interval = 0

    # Set LoRa Region (Required to trigger PKI key generation on reboot)
    interface.localNode.localConfig.lora.region = 1
    
    # Advanced LoRa Settings
    interface.localNode.localConfig.lora.config_ok_to_mqtt = True
    hop_limit = os.environ.get("HOP_LIMIT")
    if hop_limit is not None:
        interface.localNode.localConfig.lora.hop_limit = int(hop_limit)

    # Write configs
    print("Writing configurations...")
    interface.localNode.writeConfig("network")
    time.sleep(1)
    interface.localNode.writeConfig("device")
    time.sleep(1)
    interface.localNode.writeConfig("telemetry")
    time.sleep(1)
    interface.localNode.writeConfig("position")
    time.sleep(1)
    interface.localNode.writeConfig("lora")
    time.sleep(1)
    
    # Configure Primary Channel
    channel_name = os.environ.get("CHANNEL_NAME", "LongFast")
    channel_key = os.environ.get("CHANNEL_KEY", "AQ==")
    ch = interface.localNode.channels[0]
    ch.settings.name = channel_name
    
    # Safely decode the base64 PSK
    import base64
    if channel_key == "default" or channel_key == "AQ==":
        ch.settings.psk = base64.b64decode("AQ==")
    elif channel_key == "none":
        ch.settings.psk = b""
    elif channel_key.startswith("base64:"):
        ch.settings.psk = base64.b64decode(channel_key.split(":")[1])
    else:
        ch.settings.psk = base64.b64decode(channel_key)
        
    pos_precision = os.environ.get("POSITION_PRECISION", "")
    if pos_precision:
        ch.settings.module_settings.position_precision = int(pos_precision)
        
    print("Writing channel configuration...")
    interface.localNode.writeChannel(0)
    time.sleep(2)
    
    print("Setting owner (will trigger reboot)...")
    interface.localNode.setOwner(long_name, short_name)
    time.sleep(3)
    
    interface.close()
    print("Provisioning complete.")

if __name__ == "__main__":
    provision()
