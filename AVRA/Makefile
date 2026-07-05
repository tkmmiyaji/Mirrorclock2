PRG         = AVRClock2
# LED Brightness va ambient brghtness adjustment parameters.
#*** Brightness adjustment. Adjust for your system (LED, Photoresitor properties)
#ADCH value is divided by 4 to sADC=0-63. LED faintest if sADC<=FA_LIM, Brightest
#(full duty) if sADC>FA_LIM+BR_LIM. In general, BR_LIM<(63-FA_LIM) to attain full
#LED brightness at the bright ambient light, but logically it accepts up to 255.
#LED duty cylce is approximately (sADC-FA_LIM+1)/BR_LIM
#(sADC>=FA_LIM) or 1/BR_LIM (sADC<=FA_LIM).
FA_LIM = 10
BR_LIM=  50
#MCU_TARGET = atmega328
#MCU_TARGET = atmega328p
#MCU_TARGET = atmega48
#MCU_TARGET = atmega88
MCU_TARGET = atmega88p
#MCU_TARGET = atmega88pb
#PROGRAMMER  = avrispv2
PROGRAMMER  = 	usbasp
#PROGRAMMER = arduino
DUDEOPTS = -B10 -b19200
PORT = /dev/ttyUSB0
ASM  = avra
INC  = ./

ifeq ($(MCU_TARGET),atmega48)
	FUSES = -U lfuse:w:0x62:m -U hfuse:w:0xdf:m -U efuse:w:0xff:m
	INCFIL = m48def.inc
endif

ifeq ($(MCU_TARGET),atmega88p)
	FUSES = -U lfuse:w:0x62:m -U hfuse:w:0xdf:m -U efuse:w:0xf9:m
	INCFIL = m88Pdef.inc
endif

ifeq ($(MCU_TARGET),atmega328)
	FUSES = -U lfuse:w:0x62:m -U hfuse:w:0xdf:m -U efuse:w:0xf9:m
	INCFIL = m328def.inc
endif

ifeq ($(MCU_TARGET),atmega328p)
	FUSES = -U lfuse:w:0x62:m -U hfuse:w:0xd9:m -U efuse:w:0xff:m
	INCFIL = m328Pdef.inc
endif

all: hex

dev: hex_dev

hex:
	sed "s/__INCFIL__/$(INCFIL)/;s/__BR_LIM__/$(BR_LIM)/;s/__FA_LIM__/$(FA_LIM)/" \
		$(PRG).asmTMP > $(PRG).asm
	$(ASM) -I $(INC) $(PRG).asm 

hex_dev:
	sed "s/__INCFIL__/$(INCFIL)/;s/__BR_LIM__/$(BR_LIM)/;s/__FA_LIM__/$(FA_LIM)/" \
		$(PRG)_dev.asmTMP > $(PRG)_dev.asm
	$(ASM) -I $(INC) $(PRG)_dev.asm 

clean:
	rm -rf *.obj $(PRG).cof $(PRG)_dev.cof

install: $(PRG).hex
	avrdude -v -p $(MCU_TARGET) $(DUDEOPTS) -c $(PROGRAMMER)  -P $(PORT) -U flash:w:$(PRG).hex $(FUSES)

install_dev: $(PRG)_dev.hex
	avrdude -v -p $(MCU_TARGET) $(DUDEOPTS) -c $(PROGRAMMER)  -P $(PORT) -U flash:w:$(PRG)_dev.hex $(FUSES)

erase:
	avrdude -v -p $(MCU_TARGET) $(DUDEOPTS) -c $(PROGRAMMER)  -P $(PORT) -e

