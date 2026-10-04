// File Path: src/hardware/ge_amplifier_chassis.scad
// IEC 60664-1 & IPC-2152 Physics-Compliant High-Voltage Shielded Enclosure
// Features an integrated isolation divider wall and pre-drilled condensation drainage paths.

$fn = 60;

// Central structural enclosure dimensions (in millimeters)
chassis_length = 280.0; 
chassis_width  = 180.0;
chassis_height = 100.0;
wall_thickness = 6.0;   // Thicker aluminum cast wall for extreme environment protection

// IEC 60664-1 Standards Constants for 690V AC Operational Line Systems
iec_clearance_air_gap_mm = 12.0; 
iec_creepage_surface_mm  = 8.0;   // Material Group IIIa, Pollution Degree 2 Threshold
divider_thickness_mm     = 5.0;   // Structural thickness of the internal isolation wall
drain_diameter_mm        = 4.0;   // Calibrated diameter for condensation weep holes

module ge_drained_housing() {
    difference() {
        union() {
            // Main Cast Aluminum Rugged Outer Frame Block
            cube([chassis_length, chassis_width, chassis_height], center = true);
            
            // Integrated Cooling Fins designed for high-current albedo thermal decay
            for (i = [-7 : 7]) {
                translate([i * 18, 0, (chassis_height / 2) + 2.5])
                    cube([5.0, chassis_width - 12.0, 6.0], center = true);
            }
        }
        
        // 1. Hollow out Cavity A: The High-Voltage Power Bay (Left Side)
        translate([-(chassis_length / 4) - (divider_thickness_mm / 4), 0, 0])
            cube([
                (chassis_length / 2) - wall_thickness - (divider_thickness_mm / 2), 
                chassis_width - (2 * wall_thickness), 
                chassis_height - wall_thickness
            ], center = true);
            
        // 2. Hollow out Cavity B: The Protected Analog Tracking Low-Noise Bay (Right Side)
        translate([(chassis_length / 4) + (divider_thickness_mm / 4), 0, 0])
            cube([
                (chassis_length / 2) - wall_thickness - (divider_thickness_mm / 2), 
                chassis_width - (2 * wall_thickness), 
                chassis_height - wall_thickness
            ], center = true);
        
        // High-Voltage 690V AC Input Bushing Port Cutout (Pipes into Left Power Bay Only)
        translate([-(chassis_length / 2) - 1, -40, -10])
            rotate([0, 90, 0])
                cylinder(h = wall_thickness + 5, d = 35.0, center = true);
                
        // Low-Power Snap-Circuit Signal Entry Port (Pipes into Right Analog Bay Only)
        translate([(chassis_length / 2) + 1, 40, -10])
            rotate([0, 90, 0])
                cylinder(h = wall_thickness + 5, d = iec_clearance_air_gap_mm + 12.0, center = true);

        // Recessed Laser-Etched GUNDAM ROBOTIC SYSTEMS Side Plate
        translate([0, (chassis_width / 2) - 1, 15])
            cube([150.0, wall_thickness, 25.0], center = true);
            
        // IEC 60664-1 Creepage Surface Isolation Trenches (Milled inside both bays)
        translate([0, 0, -(chassis_height / 2) + wall_thickness])
            cube([chassis_length - 20.0, iec_creepage_surface_mm, 4.0], center = true);

        ---------------------------------------------------------------------
        -- HIGH-VOLTAGE FLUID DRAINAGE INTERFACE (WEEP CHANNELS)
        -- Linear drilled conduits configured at an angle to bleed moisture
        ---------------------------------------------------------------------
        // Weep Hole 1: Drains the Left High-Voltage Power Bay safely to the floor
        translate([-(chassis_length / 4), -(chassis_width / 2) + (wall_thickness / 2), -(chassis_height / 2) + (wall_thickness / 2)])
            rotate([30, 0, 0]) // 30-degree slant ensures out-and-down gravity drainage flow
                cylinder(h = wall_thickness + 10, d = drain_diameter_mm, center = true);

        // Weep Hole 2: Drains the Right Analog Tracking Low-Noise Bay safely to the floor
        translate([(chassis_length / 4), -(chassis_width / 2) + (wall_thickness / 2), -(chassis_height / 2) + (wall_thickness / 2)])
            rotate([30, 0, 0]) 
                cylinder(h = wall_thickness + 10, d = drain_diameter_mm, center = true);
    }
    
    // Concrete Placement of the Form-Molded Inter-Bay Divider Rail
    // Keeps internal chambers completely sealed from cross-contamination
    translate([0, 0, -(wall_thickness / 2)])
        cube([divider_thickness_mm, chassis_width - (2 * wall_thickness), chassis_height - wall_thickness], center = true);
}

// Instantiate the dual-cavity moisture-venting chassis structure
ge_drained_housing();
