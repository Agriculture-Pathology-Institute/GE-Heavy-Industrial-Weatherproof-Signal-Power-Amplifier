# File Path: src/hardware/rt_json_network_bridge.py
#!/usr/bin/env python3
"""
Revolutionary Technology Company — UNIVAC IX Systems Group
Production YAML-Driven Cross-Server JSON Communication & Inter-Process Bridge.

Dynamically updates memory-mapped Chrysler inertia gain registers over live 
network socket streams to balance autonomous tracking steering vectors.
"""

import os
import sys
import json
import time
import math
import socket
import threading

try:
    import yaml
except ImportError:
    print("[-] Dependency Warning: 'pyyaml' package not found. Install via: pip install pyyaml", file=sys.stderr)
    class FakeYaml:
        @staticmethod
        def safe_load(stream):
            return {
                "planetary_geodetic_anchor": {"origin_latitude": 47.6062, "origin_longitude": -122.3321, "safety_setback_buffer_mm": 50.8},
                "microclimate_atmospheric_physics": {"terrain_roughness_exponent": 0.14, "enforced_gale_shutoff_kts": 45.0},
                "aerospace_kinematics_bridge": {"chrysler_inertia_gain_default": 256, "chassis_slip_friction_modifier": 0.85},
                "robotic_hardware_interlock_thresholds": {"maximum_allowable_torque_nm": 450.0, "target_network_bridge_port": 8080}
            }
    yaml = FakeYaml()

class RtJsonNetworkBridge:
    def __init__(self, config_path="config.yaml", host="127.0.0.1", export_directory="Data/UnivacStreams/"):
        self.host = host
        self.export_directory = export_directory
        self.config_path = config_path
        self.hex_states = {f"0x{i:X}": i * 0.0625 for i in range(16)}
        
        # Memory-Mapped Hardware Register Matrix (Simulated FPGA VHDL Dual-Port RAM Layout)
        self.hardware_registers = {
            "REG_CHRYSLER_INERTIA_GAIN": 256,   # Default to 1.0 nominal tracking factor
            "REG_SLIP_FRICTION_MODIFIER": 0.85,
            "REG_LINE_CLAMP_ACTIVE": 0,
            "REG_ACTIVE_HEX_STATE": 0xF
        }
        
        self.poly_vertices = [
            {"x": 100000, "y": 100000},
            {"x": 500000, "y": 120000},
            {"x": 480000, "y": 350000},
            {"x": 120000, "y": 320000}
        ]
        
        self.load_farm_scene_configuration()
        if not os.path.exists(self.export_directory):
            os.makedirs(self.export_directory, exist_ok=True)

    def load_farm_scene_configuration(self):
        """Loads structural environment parameters from config.yaml on server boot."""
        print(f"[*] Booting UNIVAC IX Fabric... Parsing layout file: {self.config_path}")
        
        if not os.path.exists(self.config_path):
            self.listen_port = 8080
            self.safety_setback = 50.8
            self.gale_cutoff = 45.0
            return

        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                config = yaml.safe_load(f)
                
            anchor = config.get("planetary_geodetic_anchor", {})
            physics = config.get("microclimate_atmospheric_physics", {})
            thresholds = config.get("robotic_hardware_interlock_thresholds", {})
            kinematics = config.get("aerospace_kinematics_bridge", {})
            
            self.listen_port = int(thresholds.get("target_network_bridge_port", 8080))
            self.safety_setback = float(anchor.get("safety_setback_buffer_mm", 50.8))
            self.gale_cutoff = float(physics.get("enforced_gale_shutoff_kts", 45.0))
            
            # Commit baseline defaults straight into memory-mapped registers
            self.hardware_registers["REG_CHRYSLER_INERTIA_GAIN"] = int(kinematics.get("chrysler_inertia_gain_default", 256))
            self.hardware_registers["REG_SLIP_FRICTION_MODIFIER"] = float(kinematics.get("chassis_slip_friction_modifier", 0.85))
            
            padding = int(self.safety_setback)
            self.poly_vertices = [
                {"x": 100000 + padding, "y": 100000 + padding},
                {"x": 500000 - padding, "y": 120000 + padding},
                {"x": 480000 - padding, "y": 350000 - padding},
                {"x": 120000 + padding, "y": 320000 - padding}
            ]
            print(f"[+] Initialized hardware registers. Current Gain Register: {self.hardware_registers['REG_CHRYSLER_INERTIA_GAIN']}")
            
        except Exception as e:
            print(f"[-] Error bootstrapping configuration array parameters: {str(e)}")
            self.listen_port = 8080
            self.safety_setback = 50.8
            self.gale_cutoff = 45.0

    def verify_spatial_polygon_bounds(self, test_x, test_y):
        """Executes a cross-product intersection pass to check property limits."""
        num_vtx = len(self.poly_vertices)
        inside = False
        p1x = self.poly_vertices[0]["x"]
        p1y = self.poly_vertices[0]["y"]
        
        for i in range(num_vtx + 1):
            p2x = self.poly_vertices[i % num_vtx]["x"]
            p2y = self.poly_vertices[i % num_vtx]["y"]
            if test_y > min(p1y, p2y) and test_y <= max(p1y, p2y) and test_x <= max(p1x, p2x):
                if p1y != p2y:
                    xints = (test_y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                if p1x == p2x or test_x <= xints:
                    inside = not inside
            p1x, p1y = p2x, p2y
            
        return inside

    def process_incoming_ue5_json(self, raw_json_string):
        """Parses incoming coordinates, updates dynamic inertia registers, and applies shape clamps."""
        try:
            data = json.loads(raw_json_string)
            ue5_pos_cm = data.get("ue5_position_cm", [0.0, 0.0, 0.0])
            base_wind_speed_kts = data.get("wind_speed_kts", 0.0)
            mass_cut_m3 = data.get("volume_cut_m3", 0.0)
            current_hex = data.get("request_hex_state", "0xF")
            
            # ADVANCED TELE_TANK KINEMATICS REGISTRATION
            # Dynamically overwrite internal registers if a specific gain token passes down-line
            if "request_chrysler_inertia_gain" in data:
                new_gain = int(data["request_chrysler_inertia_gain"])
                self.hardware_registers["REG_CHRYSLER_INERTIA_GAIN"] = new_gain
                print(f"[⚡ Hardware Register Update] REG_CHRYSLER_INERTIA_GAIN updated to: {new_gain}")

            target_x_mm = int(math.floor(ue5_pos_cm[0] * 10.0))
            target_y_mm = int(math.floor(ue5_pos_cm[1] * 10.0))
            target_z_mm = int(math.floor(ue5_pos_cm[2] * 10.0))
            
            eff_wind_kts = base_wind_speed_kts * math.pow((4.5 / 10.0), 0.14)
            wind_pressure_pa = 0.5 * 1.225 * math.pow((eff_wind_kts * 0.514444), 2)

            is_inside_bounds = self.verify_spatial_polygon_bounds(target_x_mm, target_y_mm)
            
            assigned_hex = current_hex
            system_interlock = "UNLOCKED_OPERATIONAL_NOMINAL"
            alert_status = "NOMINAL_SPATIAL_TRACKING_IN_BOUNDS"
            authorize_next_cut = True
            enforced_x = target_x_mm
            enforced_y = target_y_mm

            if wind_pressure_pa > 150.0:
                alert_status = "WARNING_WIND_DRIFT_COMPENSATION_ACTIVE"
                assigned_hex = "0xE"
                
            if eff_wind_kts > self.gale_cutoff or not is_inside_bounds:
                assigned_hex = "0x0" 
                authorize_next_cut = False
                system_interlock = "CRITICAL_SAFETY_INTERLOCK_CLAMP_ACTIVE"
                alert_status = "CRITICAL_PROPERTY_LINE_CLAMP_EVENT" if not is_inside_bounds else "CRITICAL_GALE_FORCE_EMERGENCY"
                if not is_inside_bounds:
                    enforced_x = self.poly_vertices[0]["x"]
                    enforced_y = self.poly_vertices[0]["y"]

            self.hardware_registers["REG_LINE_CLAMP_ACTIVE"] = 1 if assigned_hex == "0x0" else 0
            self.hardware_registers["REG_ACTIVE_HEX_STATE"] = assigned_hex

            univac_packet = {
                "univac_core_header": {
                    "system_architecture": "UNIVAC_IX_CORE_FABRIC",
                    "timestamp_epoch_ms": int(time.time() * 1000),
                    "autonomic_handshake_override": "ACTIVE_REVERSE_INJECTION_TRAP" if assigned_hex == "0x0" else "STANDBY"
                },
                "boundary_isolation_matrix": {
                    "polyhedral_keep_in_zone": self.poly_vertices,
                    "hardware_clamp_active": not is_inside_bounds,
                    "safety_alert_status": alert_status,
                    "system_interlock_status": system_interlock
                },
                "hardware_memory_mapped_registers": self.hardware_registers,
                "unreal_spatial_tracking": {
                    "requested_coordinates_mm": [target_x_mm, target_y_mm, target_z_mm],
                    "enforced_coordinates_mm": [enforced_x, enforced_y, target_z_mm],
                    "bus_voltage_target": f"{self.hex_states.get(assigned_hex, 0.0000):.4f}V",
                    "assigned_hex_safety_register": assigned_hex
                },
                "atmospheric_fluid_dynamics": {
                    "scaled_wind_speed_kts": round(eff_wind_kts, 2),
                    "calculated_wind_pressure_pa": round(wind_pressure_pa, 2)
                },
                "univac_closed_loop_checkback": {
                    "actual_volume_displaced_m3": mass_cut_m3,
                    "authorize_next_field_cut": authorize_next_cut
                }
            }
            return univac_packet, True
        except (json.JSONDecodeError, KeyError, TypeError, IndexError) as err:
            return {"status": "MALFORMED_JSON_EXCEPTION", "details": str(err)}, False

    def start_network_server_listener(self):
        """Launches a non-blocking TCP socket server that listens for incoming cross-server JSON frames."""
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\
server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

try:\
server_socket.bind((self.host, self.listen_port))\
server_socket.listen(5)\
print(f"[*] UNIVAC IX Core Fabric listening on configuration port: {self.host}:{self.listen_port}")

while True:\
client_conn, client_addr = server_socket.accept()\
threading.Thread(target=self._handle_client_connection, args=(client_conn, client_addr), daemon=True).start()\
except Exception as e:\
print(f"[-] Server socket initialization failure: {str(e)}")\
finally:\
server_socket.close()

def _handle_client_connection(self, connection, address):\
"""Worker thread processing the received JSON stream data payload."""\
try:\
raw_data = connection.recv(4096).decode('utf-8')\
if raw_data:\
processed_frame, success = self.process_incoming_ue5_json(raw_data)\
response_string = json.dumps({"handshake_received": True, "syntax_valid": success, "assigned_register": processed_frame.get("unreal_spatial_tracking", {}).get("assigned_hex_safety_register", "0x0")})\
connection.sendall(response_string.encode('utf-8'))

if success:\
prefix = "UNIVAC_CRITICAL_" if processed_frame["unreal_spatial_tracking"]["assigned_hex_safety_register"] == "0x0" else "UNIVAC_NOMINAL_"\
filename = f"{prefix}{processed_frame['univac_core_header']['timestamp_epoch_ms']}.json"\
with open(os.path.join(self.export_directory, filename), "w") as f:\
json.dump(processed_frame, f, indent=4)\
except Exception as err:\
print(f"[-] Inter-server connection error processing address {address}: {str(err)}")\
finally:\
connection.close()

if **name** == "**main**":\
# Test execution routing: Mocking an incoming socket update packet containing load mass fluctuations\
mock_ue5_network_packet = {\
"ue5_position_cm": [2500.0, 1800.0, 45.0],\
"wind_speed_kts": 12.4,\
"volume_cut_m3": 14.8,\
"request_hex_state": "0xC",\
"request_chrysler_inertia_gain": 512 # Triggers dynamic register overwrite to max payload saturation\
}

bridge = RtJsonNetworkBridge()\
print("[*] Running network register parsing validation check...")\
json_payload = json.dumps(mock_ue5_network_packet)\
verified_output, status_ok = bridge.process_incoming_ue5_json(json_payload)\
print(json.dumps(verified_output, indent=4))
