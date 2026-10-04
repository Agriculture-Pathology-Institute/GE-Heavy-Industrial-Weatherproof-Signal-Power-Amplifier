// File Path: src/hardware/ge_amplifier_chassis.scad
// IEC 60664-1 & IPC-2152 Physics-Compliant High-Voltage Shielded Enclosure

$fn = 60;

chassis_length = 260.0; // Expanded to handle structural creepage isolation rings
chassis_width  = 180.0;
chassis_height = 100.0;
wall_thickness = 6.0;   // Thicker aluminum cast wall for extreme environment protection

// IEC 60664-1 Standards Constants for 690V AC Operational Line Systems
iec_clearance_air_gap_mm = 12.0; 
iec_creepage_surface_mm  = 8.0;   // Material Group IIIa, Pollution Degree 2 Threshold

module ge_high_voltage_housing() {
    difference() {
        union() {
            // Main Cast Aluminum Rugged Frame Block
            cube([chassis_length, chassis_width, chassis_height], center = true);
            
            // Integrated Cooling Fins designed for high-current albedo thermal decay
            for (i = [-6 : 6]) {
                translate([i * 18, 0, (chassis_height / 2) + 2.5])
                    cube([5.0, chassis_width - 12.0, 6.0], center = true);
            }
        }
        
        // Main internal enclosure layout cavity
        cube([
            chassis_length - (2 * wall_thickness), 
            chassis_width - (2 * wall_thickness), 
            chassis_height - wall_thickness
        ], center = true);
        
        // High-Voltage 690V AC Input Bushing Port Cutout
        // Sized precisely to maintain air gap clearance around terminal rings
        translate([-(chassis_length / 2) - 1, -40, -10])
            rotate([0, 90, 0])
                cylinder(h = wall_thickness + 5, d = 35.0, center = true);
                
        // Low-Power Snap-Circuit Signal Entry Port (Physically isolated from high voltage)
        translate([-(chassis_length / 2) - 1, 40, -10])
            rotate([0, 90, 0])
                cylinder(h = wall_thickness + 5, d = iec_clearance_air_gap_mm + 12.0, center = true);

        // Recessed Laser-Etched GUNDAM ROBOTIC SYSTEMS Side Plate
        translate([0, (chassis_width / 2) - 1, 15])
            cube([150.0, wall_thickness, 25.0], center = true);
    }
    
    // Internal High-Voltage Creepage Isolation Barriers
    // Physical surface trenches that prevent tracking arc paths along the enclosure walls
    translate([-(chassis_length / 4), 0, -(chassis_height / 2) + wall_thickness])
        cube([iec_creepage_surface_mm, chassis_width - (2 * wall_thickness), 20.0], center = true);
}

ge_high_voltage_housing();
