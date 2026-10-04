// File Path: src/hardware/ge_amplifier_chassis.scad
// GE Heavy Industrial Weatherproof Signal Power Amplifier Housing Model
// Designed to shield internal 16-State Analog Silicon from high-draw inductive fields

$fn = 60;

// Central structural enclosure dimensions (in millimeters)
chassis_length = 240.0;
chassis_width  = 160.0;
chassis_height = 90.0;
wall_thickness = 5.0;

module ge_industrial_housing() {
    difference() {
        union() {
            // Main Cast Aluminum Core Body block
            cube([chassis_length, chassis_width, chassis_height], center = true);
            
            // Generate Integrated Passive Cooling Fin Array for Thermal Shedding
            for (i = [-5 : 5]) {
                translate([i * 18, 0, (chassis_height / 2) + 2.5])
                    cube([4.0, chassis_width - 10.0, 5.0], center = true);
            }
        }
        
        // Hollow out inner cavity cavity leaving rugged protective wall metrics
        cube([
            chassis_length - (2 * wall_thickness), 
            chassis_width - (2 * wall_thickness), 
            chassis_height - wall_thickness
        ], center = true);
        
        // Cutout port for the MIL-SPEC Amphenol Twist-Lock Bayonet Terminal
        translate([-(chassis_length / 2) - 1, 0, -10])
            rotate([0, 90, 0])
                cylinder(h = wall_thickness + 5, d = 32.0, center = true);
                
        // Recessed Laser-Etched Branding Plate Window Channel
        // Positioned for the "GUNDAM ROBOTIC SYSTEMS" Decal in Plavsky Font
        translate([0, (chassis_width / 2) - 1, 10])
            cube([140.0, wall_thickness, 30.0], center = true);
    }
    
    // Internal PCB Corner Standoff Anchor Bosses
    translate([
        (chassis_length/2) - wall_thickness - 10, 
        (chassis_width/2) - wall_thickness - 10, 
        -(chassis_height/2) + 5
    ])
        difference() {
            cylinder(h = 15, d = 12, center = true);
            cylinder(h = 20, d = 3.5, center = true); // Pre-drilled for M3 tap lines
        }
}

// Instantiate the industrial enclosure die for toolroom machining execution
ge_industrial_housing();
