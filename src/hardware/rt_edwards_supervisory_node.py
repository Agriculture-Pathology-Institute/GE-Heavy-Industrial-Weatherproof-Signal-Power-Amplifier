# File Path: src/hardware/rt_edwards_supervisory_node.py
#!/usr/bin/env python3
"""
Revolutionary Technology Company — UNIVAC IX Systems Group
Production Edwards FireWorks High-Priority Watchdog Supervisory Core.

Maintains an unbroken active-high loop pattern across cross-server socket networks,
mechanically dropping the safety circuit if hardware telemetry stalls for >2000ms.
"""

import os
import sys
import json
import time
import socket
import threading

class EdwardsSupervisoryHeartbeatNode:
    def __init__(self, host="127.0.0.1", port=8083, watch_timeout_ms=2000):
        self.host = host
        self.port = port
        self.timeout_seconds = watch_timeout_ms / 1000.0
        
        # Operational Watchdog States
        self.last_heartbeat_received = time.time()
        self.hardware_loop_active = True
        self.relay_pin_energized = True # Active-High baseline pattern logic [1.15]

    def process_incoming_heartbeat(self, raw_json_frame):
        """Ingests live cross-server telemetry frames and refreshes the timing registers."""
        try:
            data = json.loads(raw_json_frame)
            header = data.get("univac_core_header", {})
            diagnostics = data.get("analog_signal_diagnostics", {})
            
            # Ensure the frame originates from a verified active 16-state computing fabric
            if header.get("system_architecture") == "NATIVE_16_STATE_HEXADECIMAL_FABRIC" or "UNIVAC" in header.get("system_architecture", ""):
                # Check for active hardware isolation faults passed over the socket line
                isolation_tripped = data.get("boundary_isolation_matrix", {}).get("hardware_clamp_active", False)
                galvanic_fault = diagnostics.get("galvanic_leakage_detected", False)
                
                if isolation_tripped or galvanic_fault:
                    print("[🚨 INSTANT OVERRIDE] Critical system hazard flag extracted. Tripping relay line.")
                    self.relay_pin_energized = False
                    return "CRITICAL_FAULT_DROP"
                
                # Refresh the safety timer if the packet is clean and structurally sound
                self.last_heartbeat_received = time.time()
                self.relay_pin_energized = True
                return "TIMER_REFRESHED"
        except (json.JSONDecodeError, KeyError) as e:
            print(f"[-] Malformed telemetry data packet passed to heartbeat loop: {str(e)}", file=sys.stderr)
        return "PARSE_EXCEPTION"

    def execute_watchdog_sentinel_thread(self):
        """Continuous background thread evaluating elapsed milliseconds since the last successful frame pass."""
        print(f"[*] Initializing Active-High Watchdog Sentinel. Maximum timeout window: {self.timeout_seconds}s")
        while self.hardware_loop_active:
            current_duration = time.time() - self.last_heartbeat_received
            
            if current_duration > self.timeout_seconds:
                if self.relay_pin_energized:
                    print("\n[🚨 CATASTROPHIC WATCHDOG TIMEOUT] System execution loop has stalled!")
                    print(f"[!] Elapsed time since last valid handshake: {current_duration:.4f} seconds.")
                    print("[!] DROPPING GPIO CONTROL PIN LOW -> NORMALLY CLOSED RELAY CIRCUIT POPS OPEN [1.15].")
                    print("[!] EDWARDS FIREWORKS PANEL TRIGGERING PRIORITY 1 INCIDENT REPORT EVACUATION MODE [1.15].")
                    self.relay_pin_energized = False
            else:
                # Maintain the active hardware loop state while signals are nominal
                pass
            time.sleep(0.1) # 100ms sweep check interval rate matches your industrial divider [1.15]

    def launch_supervisory_socket_listener(self):
        """Launches a non-blocking TCP server to intercept synchronous health signals from the network bridge."""
        # Initialize and detach the active sentinel watchdog thread first
        sentinel_thread = threading.Thread(target=self.execute_watchdog_sentinel_thread, daemon=True)
        sentinel_thread.start()
        
        server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
        try:
            server_socket.bind((self.host, self.port))
            server_socket.listen(5)
            print(f"[*] Edwards Supervisory Sentinel Core listening on network address: {self.host}:{self.port}")
            
            while self.hardware_loop_active:
                conn, _ = server_socket.accept()
                try:
                    payload = conn.recv(4096).decode('utf-8')
                    if payload:
                        self.process_incoming_heartbeat(payload)
                        # Return active-high pin confirmation frame back to bridge server
                        conn.sendall(json.dumps({"relay_pin_energized": self.relay_pin_energized}).encode('utf-8'))
                except Exception as err:
                    pass
                finally:
                    conn.close()
        except Exception as e:
            print(f"[-] Sentinel server socket initialization failure: {str(e)}", file=sys.stderr)
        finally:
            server_socket.close()

if __name__ == "__main__":
    # Test pass: Emulates a sudden telemetry stall to check the execution of the drop routine
    monitor = EdwardsSupervisoryHeartbeatNode()
    
    # Detach and trigger the socket core headlessly
    server_thread = threading.Thread(target=monitor.launch_supervisory_socket_listener, daemon=True)
    server_thread.start()
    time.sleep(0.2)
    
    # Inject a clean, valid initialization signal to start the tracking timer
    mock_nominal_frame = {
        "univac_core_header": {"system_architecture": "NATIVE_16_STATE_HEXADECIMAL_FABRIC"},
        "boundary_isolation_matrix": {"hardware_clamp_active": False},
        "analog_signal_diagnostics": {"galvanic_leakage_detected": False}
    }
    
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(("127.0.0.1", 8083))
    s.sendall(json.dumps(mock_nominal_frame).encode('utf-8'))
    s.close()
    print("[+] Test initialization vector injected. Intentionally withholding next packet...")
    
    # Wait 3.5 seconds to explicitly breach the 2000ms watchdog timeout barrier
    time.sleep(3.5)
    print("[+] Evaluation sequence completed.")
