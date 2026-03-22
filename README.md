# Klipper Power loss recovery

Simple print recovery system for Klipper, a 3D printer firmware. 
It allows you to resume prints after a power loss or other types of MCU disconnection. 

Please note there is no guarantee that it will work in 100% of cases. 
It works best if the Z axis hasn't moved.

⚠️ the print will be resumed at the beginning of the layer being printed when it was interrupted, 
causing part of that layer to be reprinted. 


## Prerequisites

Having already installed Klipper, Moonraker, and Mainsail (you can use Kiauh).


## Installation

### Clone the repository and install

```bash
git clone https://github.com/nstcactus/klipper-plr.git
cd klipper-plr
./install.sh
```
### Configure your slicer software

#### Start custom G-code

```bash
G31
save_last_file
SAVE_VARIABLE VARIABLE=was_interrupted VALUE=True
```

#### End custom G-code

```bash
SAVE_VARIABLE VARIABLE=was_interrupted VALUE=False
clear_last_file
G31
```

### After layer change custom G-code

```gcode
SAVE_PLR_RESUME_DATA
```

## Resuming an interrupted print

1. _Optional but highly recommended:_ heat the bed and nozzle to reasonable values, move the nozzle up a few millimeters, 
   then manually lower it until it touches the part.  
   Once done, run:

   ```gcode
   SET_KINEMATIC_POSITION Z=<value present in the power_resume_z var from variables.cfg>
   ```

   ⚠️ if you choose to skip this step, you consider the current nozzle position hasn't moved (at all) since the 
   interruption.

2. Run the `RESUME_INTERRUPTED` macro to generate a resume G-code file.

3. Manually start printing the generated resume file found in `gcodes/plr`.


## Known issues

- the preview image of the G-code file is not rebuilt
- the resumed print will not be able to display the correct layer progress; do not trust any remaining time estimation 
  or ETA
- resuming a print will most likely leave a scar of some form on your part
