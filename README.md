# PN003_ir_control
The project uses the IR RX and TX sensors on a Matrix Creator linked to a Raspberry Pi. It enables the functions of an IR remote control (that uses the NEC protocol) to be read, essentially learning the remote. This data can the be used to program the device that the remote was linked to.

## Project Requirements
* Raspberry Pi
* Matrix Creator
* ISE (if the VHDL code is to be modified)

## Project Outline
The FPGA is used to decode and encode IR signals, with the Raspberry Pi acting as the controller which interactes with the FPGA via the SPI. When a IR signal is detected, the FPGA decodes the signal and stores the 32 bit word. 

When running the `learn` function of the program, the RPi poles the FPGA every 0.2ms to see if the an IR word has been detected and decoded, if not the FPGA will return 4 bytes of 0x00, else it will return the full IR word. All the commands are stored in a file in the same folder called ctlData.txt.

After the commands have been learned, the `write [cmdName]` function can be used to program the device. This will load the data from the .txt file for the requested function, and send it over the the FPGA which encodes the data and modulates it with a 38kHz carrier frequency for tranmission to the IR TX led.

## Run Instructions
1. Set up the Matrix Creator HAL, following the guide [here](https://matrix-io.github.io/matrix-documentation/matrix-hal/overview/)
2. Transfer `irCtl.c` and the `Makefile`, as well as the `irCtl_top.bit` file to the Raspberry Pi
3. Load the FPGA bit file using `sudo xc3sprog -c matrix_creator irCtl_top.bit -p 1`
4. Run `make` to compile the program
5. Run `./irCtl` to the see the full usage statement.

## General Info
The program is currently setup to learn the **Volume Up**, **Volume Down**, **Channel Up**, **Channel Down**, **Mute** and **Power** commands. This can be modified by adding, removing or altering the names at the top of the the `irCtl.c` file. Note that both `cmdNames` and `cmdNameShort` needs to have the same number of commands, the exact name of commands can be specifed by the user.

Disclaimer: It is not a fool proof system, more of a proof of concept. Errors can occurs if a button has been pressed on the remote before running the 'learn' function. I will make modifications, but would prefer that any modifications are made by the requesting user, and subitted in a PR.