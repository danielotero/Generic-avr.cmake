cmake_minimum_required(VERSION 3.0)

# Default project properties
# --------------------------
#
# This set the preferred options for this project.
# Note that this options are set in the CMake cache, so any change here will
# require a new build directory.
#
# Set the default MCU for this project
set(DEFAULT_AVR_MCU "atmega2560" CACHE STRING "")
# Set the default programmer for AVRDUDE
set(AVRDUDE_PROGRAMMER "avrispmkII" CACHE STRING "")
# Set the default port to communicate with the programmer
set(AVRDUDE_PORT "/dev/ttyUSB0" CACHE STRING "")
# Set the default port speed
set(AVRDUDE_BITRATE 9600 CACHE STRING "")

# Notify CMake that this project is build for the AVR architecture
set(CMAKE_TOOLCHAIN_FILE "../Generic-avr.cmake")

# Project definition
project(Blink
  VERSION 0.0.1
  LANGUAGES C
)

## Declare the clock speed project-wide
add_definitions(-DF_CPU=16000000L)

add_executable(blink
   blink.c
)
target_compile_options(blink PRIVATE -std=gnu11 -Wall)

# This will create upload_main CMake target to upload the firmware
add_avr_firmware(blink)

