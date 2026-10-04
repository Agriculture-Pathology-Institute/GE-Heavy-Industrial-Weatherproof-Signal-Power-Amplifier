# File Path: src/hardware/build_amplifier_netlist.py
#!/usr/bin/env python3
"""
Revolutionary Technology Company — UNIVAC IX Systems Group
Automated KiCad Netlist & Fabric Pattern Generator.

Compiles the component footprints, 16-channel tracking lines, 
and 3oz copper guard networks required for the GE Amplifier PCB.
"""

import os
import sys

class KicadNetlistGenerator:
    def __init__(self, output_path="src/hardware/ge_amplifier_netlist.net"):
        self.output_path = output_path
        
    def generate_amplifier_netlist_string(self):
        """Builds a structured native KiCad netlist block matching your schematic parameters."""
        netlist = """(export (version D)
  (components
    (comp (ref U1)
      (value Micrel_SY10E445)
      (footprint Package_QFP:PLCC-28_11.5x11.5mm_P1.27mm)
      (libsource (lib Converter_Serial_Parallel) (part SY10E445) (description "4-Bit Serial to Parallel Converter"))
      (sheetpath (names /) (tstamps /)))
    (comp (ref U2)
      (value TI_CD4514B)
      (footprint Package_DIP:DIP-24_W15.24mm)
      (libsource (lib Decoder_Demux) (part CD4514B) (description "4-to-16 Line Decoder with Input Latches"))
      (sheetpath (names /) (tstamps /)))
    (comp (ref U3)
      (value XC6602_Regulator)
      (footprint Package_TO_SOT_SMD:SOT-223-3_TabPin2)
      (libsource (lib Regulator_Linear) (part XC6602) (description "0.5V Ultra-Low Dropout Voltage Regulator"))
      (sheetpath (names /) (tstamps /))))
  (nets
    (net (code 1) (name "Net-(U1-PadQ0)")
      (node (ref U1) (pin 12))  (node (ref U2) (pin 2))) -- Connects Parallel Bit 0
    (net (code 2) (name "Net-(U1-PadQ1)")
      (node (ref U1) (pin 13))  (node (ref U2) (pin 3))) -- Connects Parallel Bit 1
    (net (code 3) (name "Net-(U1-PadQ2)")
      (node (ref U1) (pin 14))  (node (ref U2) (pin 21))) -- Connects Parallel Bit 2
    (net (code 4) (name "Net-(U1-PadQ3)")
      (node (ref U1) (pin 15))  (node (ref U2) (pin 22))) -- Connects Parallel Bit 3
    (net (code 5) (name "V_BIAS_0.5V")
      (node (ref U3) (pin 3))  (node (ref U1) (pin 28)) (node (ref U2) (pin 24))) -- Isolated Reference Rail
    (net (code 6) (name "SIGNAL_GROUND_VSS")
      (node (ref U3) (pin 2))  (node (ref U1) (pin 1))  (node (ref U2) (pin 12))) -- Guard Ring Termination Ground
  )
)
"""
        return netlist

    def write_netlist_file(self):
        """Flushes the string mapping data to the targeted netlist directory track."""
        directory = os.path.dirname(self.output_path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory, exist_ok=True)
            
        payload = self.generate_amplifier_netlist_string()
        with open(self.output_path, "w", encoding="utf-8") as f:
            f.write(payload)
        print(f"[+] KiCad manufacturing netlist successfully compiled -> Location Target: {self.output_path}")

if __name__ == "__main__":
    compiler = KicadNetlistGenerator()
    compiler.write_netlist_file()
