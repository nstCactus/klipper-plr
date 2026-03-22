#!/bin/bash

# Get the directory containing this script at runtime
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PRINTER_DATA_DIR="${SCRIPT_DIR}/../printer_data"
CFG="${PRINTER_DATA_DIR}/config/variables.cfg"
PLR_DIR="${PRINTER_DATA_DIR}/gcodes/plr"
TMP="${PRINTER_DATA_DIR}/plr/tmp.gcode"

mkdir -p "${PLR_DIR}"

# ----------------------------
# Read variables.cfg
# ----------------------------

get_var() {
    sed -n "s/.*$1 *= *'\?\([^']*\)'\?/\1/p" "$CFG"
}

filepath=$(get_var filepath)
last_file=$(get_var last_file)
power_resume_z=$(get_var power_resume_z)
bed_temp=$(get_var bed_temp)
extruder_temp=$(get_var extruder_temp)

# Fallbacks
bed_temp=${bed_temp:-60}
extruder_temp=${extruder_temp:-210}

echo "File: $filepath"
echo "Output: $last_file"
echo "Resume Z: $power_resume_z"

# ----------------------------
# Extract target layer marker
# ----------------------------

# Find first PLR marker matching the Z
marker=$(grep -m1 ";PLR:.*Z=${power_resume_z}" "$filepath")

if [ -z "$marker" ]; then
    echo "ERROR: Could not find PLR marker for Z=${power_resume_z}"
    exit 1
fi

echo "Marker: $marker"

# ----------------------------
# Trim G-code from marker
# ----------------------------

sed -e "1,/${marker}/d" "$filepath" > "$TMP"

# ----------------------------
# Extract first XY move AFTER marker
# ----------------------------

next_xy=$(grep -m1 -E "G1 X[0-9\.\-]+ Y[0-9\.\-]+" "$TMP")

if [ -z "$next_xy" ]; then
    echo "WARNING: Could not find next XY move, defaulting to X0 Y0"
    next_xy="G1 X0 Y0"
fi

echo "Next XY: $next_xy"

# ----------------------------
# Generate resume file
# ----------------------------

OUTPUT="${PLR_DIR}/${last_file}"

cat > "$OUTPUT" <<EOF
; ---- PLR RESUME FILE ----

M118 RESUMING_PRINT

; --- restore Z if needed ---
{% if "z" not in printer.toolhead.homed_axes %}
SET_KINEMATIC_POSITION Z=${power_resume_z}
{% endif %}

; --- heat ---
M140 S${bed_temp}
M104 S${extruder_temp}
M190 S${bed_temp}
M109 S${extruder_temp}

; --- deterministic state ---
G90
M83
G92 E0

; --- lift safely ---
G1 Z$(( $(echo "$power_resume_z + 25" | bc -l) )) F600

; --- home XY ---
G28 X Y

; --- move to park position ---
{% set client = printer["gcode_macro _CLIENT_VARIABLE"] %}
{% set park_x = client.custom_park_x|float %}
{% set park_y = client.custom_park_y|float %}
G1 X{park_x} Y{park_y} F12000

; --- purge ---
G1 E30 F300
G92 E0

; --- move above next print position ---
${next_xy} F12000

; --- move to resume height ---
G1 Z$(echo "$power_resume_z + 0.05" | bc -l) F300

; ---- RESUME PRINT ----
EOF

# Append remaining G-code
cat "$TMP" >> "$OUTPUT"

rm "$TMP"

echo "PLR file generated: $OUTPUT"
