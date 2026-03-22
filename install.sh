#!/bin/bash

set -e

CREATED_FILES=()
VARIABLES_EXISTED=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

step() {
    echo -e "${YELLOW}Doing $1${NC}"
}

done_msg() {
    echo -e "  ${GREEN}⤷ done${NC}"
}

exists_msg() {
    echo -e "  ${BLUE}⤷ already exists${NC}"
}

warn_msg() {
    echo -e "  ${YELLOW}⤷ $1${NC}"
}

error_msg() {
    echo -e "  ${RED}⤷ $1${NC}"
}

check_environment() {
    step "Checking environment"

    if [ -n "$SUDO_USER" ]; then
        if [ "$SUDO_USER" = "runner" ]; then
            USER_HOME="/home/pi"
            OWNER="pi"
        else
            USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
            OWNER="$SUDO_USER"
        fi
    else
        USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
        OWNER="$USER"
    fi

    KLIPPER_DIR="$USER_HOME/klipper"
    if [ ! -d "$KLIPPER_DIR/klippy/extras" ]; then
        error_msg "Klipper extras directory not found: $KLIPPER_DIR/klippy/extras"
        exit 1
    fi

    if [ ! -d "$USER_HOME/printer_data/config" ]; then
        error_msg "Printer config directory not found: $USER_HOME/printer_data/config"
        exit 1
    fi

    done_msg
}

create_plr_directory() {
    step "Creating PLR directory"

    PLR_DIR="$USER_HOME/printer_data/plr"

    if [ ! -d "$PLR_DIR" ]; then
        mkdir -p "$PLR_DIR"
        done_msg
    else
        exists_msg
    fi

    # Fix permissions if running with sudo
    if [ -n "$SUDO_USER" ]; then
        chown -R "$OWNER":"$OWNER" "$PLR_DIR"
    fi
}

create_symlinks() {
    step "Creating symlinks"

    PROJECT_DIR="$PWD"
    KLIPPER_DIR="$USER_HOME/klipper"
    PLR_DIR="$USER_HOME/printer_data/plr"
    CONFIG_DIR="$USER_HOME/printer_data/config"

    safe_symlink() {
        local source="$1"
        local target="$2"

        if [ ! -f "$source" ] && [ ! -d "$source" ]; then
            error_msg "source not found: $source"
            return 1
        fi

        if [ -e "$target" ] && [ ! -L "$target" ]; then
            error_msg "target exists and is not a symlink: $target"
            return 1
        fi

        ln -nfs "$source" "$target"

        # Fix permissions if running with sudo
        if [ -n "$SUDO_USER" ]; then
            chown -h "$OWNER":"$OWNER" "$target"
        fi
    }

    # Create symlinks
    safe_symlink "$PROJECT_DIR/plr/plr.sh" "$PLR_DIR/plr.sh"
    safe_symlink "$PROJECT_DIR/plr/clear_plr.sh" "$PLR_DIR/clear_plr.sh"
    safe_symlink "$PROJECT_DIR/plr/plr.cfg" "$CONFIG_DIR/plr.cfg"
    safe_symlink "$PROJECT_DIR/plr/gcode_shell_command.py" "$KLIPPER_DIR/klippy/extras/gcode_shell_command.py"
    safe_symlink "$PROJECT_DIR/plr/update_plr.cfg" "$CONFIG_DIR/update_plr.cfg"

    done_msg
}

setup_variables() {
    step "Creating variables.cfg"

    CONFIG_DIR="$USER_HOME/printer_data/config"
    VARIABLES_FILE="$CONFIG_DIR/variables.cfg"

    if [ ! -f "$VARIABLES_FILE" ]; then
        touch "$VARIABLES_FILE"
        CREATED_FILES+=("$VARIABLES_FILE")
        done_msg

        # Fix permissions if running with sudo
        if [ -n "$SUDO_USER" ]; then
            chown "$OWNER":"$OWNER" "$VARIABLES_FILE"
        fi
    else
        VARIABLES_EXISTED=true
        exists_msg
    fi
}

display_final_summary() {
    local template_file="$PWD/plr/variables.cfg"
    local template_contents="# Template not found: $template_file"
    if [ -f "$template_file" ]; then
        template_contents=$(cat "$template_file")
    fi

    local created_section="  • none"
    if [ "${#CREATED_FILES[@]}" -gt 0 ]; then
        created_section=""
        for created_file in "${CREATED_FILES[@]}"; do
            created_section+="  • ${created_file}"$'\n'
        done
    fi

    # Build manual actions - skip template step if variables.cfg was just created
    local manual_actions="1️⃣  Add the include to printer.cfg:
    [include plr.cfg]

2️⃣  Add the include to moonraker.conf:
    [include update_plr.cfg]"

    if [ "$VARIABLES_EXISTED" = true ]; then
        manual_actions+="

3️⃣  Append this template content to $USER_HOME/printer_data/config/variables.cfg:

${template_contents}

4️⃣  In your slicer, add this to AFTER_LAYER_CHANGE:
    SAVE_PLR_RESUME_DATA

5️⃣  Restart Klipper and Moonraker from the web interface"
    else
        manual_actions+="

3️⃣  In your slicer, add this to AFTER_LAYER_CHANGE:
    SAVE_PLR_RESUME_DATA

4️⃣  Restart Klipper and Moonraker from the web interface"
    fi

    cat << EOF

🎉 Power Loss Recovery system has been installed!

📄 Created files:
${created_section}

📋 Manual actions required:

${manual_actions}

🔗 Documentation:
   Check the README.md for detailed setup instructions

EOF
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
    check_environment
    create_plr_directory
    create_symlinks
    setup_variables
    display_final_summary
}

# Run main function
main "$@"

# End of script
