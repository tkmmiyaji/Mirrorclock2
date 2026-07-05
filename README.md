# Mirrorclock2 --- Through the Looking Glass and How the Digital Clock Looks
# 鏡の国のデジタル時計  Ver. 2.2 b 

### by Homebrew and Electronics Lab Cosmic Web, 16 Jul, 2026

## Summary
This repository contains the hardware designs (KiCAD) and the software (AVR assembly language). The hardware design and software are distributed with the Beerware license. See LICENSE.md  

## Hardware

The KiCAD Ver. 10 project files (incl.  kicad_pro, kicad_pcb, and kicad_sch files are included with necessary ./KiCAD.

* AVR: The 28-dip pachage of the Atmega48,88,168,328 and variants should work. 
* The resistor footprints on the PCB accept either THT (3 DIP pitches/7.62mm between holes) or SMD (1206) components. The LED footprints accept 3mm, 5mm diameter ones that have one DIP pitch (2.54mm) between leads. You may be able to place SMD LEDs if you dare.
* Place the tilt switch diagonally, so that the display is stably in the normal mode (see below) when it is placed on a level surface. See ./Gallery/Tilt_Switch_small.jpg.

### Hard-to-find components

* The temperature-compensated Crytsal Module Kyocera KTXO-18 (12.8MHz) or Mercury VCTCXO VM39S5G is used. The latter can be purchased at Akizuki Denshi Tsuusho in Akihabara, Tokyo (https://akizukidenshi.com/catalog/g/g107275/) (availbale as of July, 2026). There may be easier-to find equivalent SMD parts, but to use these a modification in the PCB footprint is required.  

## Software AVRClock2

This software is written in the assmbly language and can be compiled with avra (https://github.com/Ro5bert/avra) and uploaded to the chip using avrdude (https://github.com/avrdudes/avrdude/), both included in the standard repositories of many Linux distros.

### How to Compile/Install (Linux)
* Install avrdude and avra to your system.
* Connect an ISP programmer to the ISP header (6-pin) on board. Watch the orientation. Match the ISP connector bump to that of the PCB drawing.
* Go to directory: ./AVRA
* Open Makefile in your editor and edit the lines with "MCU_TARGET =" and "PROGRAMMER =" to your chip and programmer respectively. Check the port where the programmer is connected and adjust the PORT=/dev/ttyUSB0 line if needed.
* Also the LED brightness auto-adjustment parameters can be set by editing "FA_LIM =" and "BR_LIM =" lines. See Makefile comments for more explanations. 
* From the shell: <br>
SHELL>make                # This compiles the program. <br>
SHELL>make install        # This installs (uploads) the binary to the chip. <br>

## Usage Instructions 
* Connect an external 12V power source.
* It is highly recommended to connect a 9V rectangular battery (called 006P in Japan) for time backup.
* When the unit turns on or reset with the RST button, the clock displays 00:00 00. The clock starts running.
* __Time Adjustment:__ There are three buttons aligned vertically. With a long (~2 sec) push of the central button (MODE), the system enters the hour adjustment mode. Dots in the hour zone blink. You can adjust hours by pushing the upper (ADJ_FWD) and/or lower (ADJ_BWD) buttons. One more pressing of the central button leads to the minute adjustment mode. Dots in the minute zone blink. Use the ADJ_FWD and/or ADJ_BWD buttons to adjust the minute. Note that a long push **will not** make the forward/backward move fast. Whenever the minute is changed, the second zone is reset to zero. When you want to adjust the clock to a second level, push the ADJ_FWD/ADJ_BWD button at the exact moment the reference clock ticks a zero second.
* One more push of the MODE will return the clock to the normal mode.
* __LED Check:__ In the normal mode, pressing the upper button will turn on all the LEDs.
* LED brightness changes responding to the ambient brightness. A press of the lower button shows some calibration and brightness information. There is a trimpot for limited adjustments of the ambient-to-LED brightness relation. Wider range of adjustment is possible in the software (See above).
* __Normal Mode:__ When the clock is right-side up or on a level surface (i.e. the HH:MM display is above the circuts), it displays the clock normally.
* __Mirror Mode: Turn the clock upside down and look through a mirror!__ The roles of ADJ_FWD and ADJ_BWD buttons are also exchanged in the time adjustment.
