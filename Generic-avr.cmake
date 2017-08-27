# Toolchain file to support AVR microcontrolers.
#
# This script locates the GNU AVR compiler and configure its arguments based on
# the following variable:
#
#   AVR_DEFAULT_MCU (Default "atmega328p")
#   -- The target MCU for building (see 'avr-gcc --target-help' for the list of
#      targets and options). This is only used the first time the build
#      directory is created, so if you want to change it, you need to create a
#      new one.
#
# The script also uses the following variables:
#
#   AVR_PRINT_SIZE (Default ON)
#   -- If set to ON, the size of the firmware in the MCU for each build will be
#      printed.
#
#   AVR_PRINT_MCU (Default ON)
#   -- If set to ON, the target AVR MCU will be printed on CMake configurations.
#
#   AVRDUDE_OTHER_ARGS (Default "-D")
#   -- Other arguments to supply to AVRDUDE (like -V to avoid verification).
#
#   AVRDUDE_PORT (Default "/dev/ttyACM0")
#   -- The port of the programmer for AVRDUDE.
#
#   AVRDUDE_PROGRAMMER (Default "wiring")
#   -- The type of the programmer for AVRDUDE.
#
#   AVRDUDE_BITRATE (Default 115200)
#   -- The bitrate of the communication with the programmer in AVRDUDE.
#
# The script creates the following macro:
#
#   ADD_AVR_FIRMWARE( target )
#   -- Creates the following targets
#    - upload_<target>             Uploads the target to the microcontoler using
#                                  AVRDUDE.
#    - upload_<target>_EEPROM      Upload only the EEPROM using AVRDUDE.
#
#  TODO: Add license.
#
###############################################################################

#
# Set the AVR Toolchain configuration
#
option(AVR_PRINT_SIZE   "Print the firmware size after building the binary" ON)
option(AVR_PRINT_MCU    "Print the AVR MCU used o CMake configurations"     ON)
set(AVR_DEFAULT_MCU     "atmega328p"   CACHE STRING "The AVR MCU to use when configuring the build for the first time")
set(AVRDUDE_OTHER_ARGS  "-D"           CACHE STRING "Other arguments for AVRDUDE")
set(AVRDUDE_PORT        "/dev/ttyACM0" CACHE STRING "AVRDUDE upload port")
set(AVRDUDE_PROGRAMMER  "wiring"       CACHE STRING "AVRDUDE programmer")
set(AVRDUDE_BITRATE     "115200"       CACHE STRING "AVRDUDE programmer bitrate")
mark_as_advanced(AVR_DEFAULT_MCU AVRDUDE_OTHER_ARGS)

# Store the AVR_MCU in a internal cache variable
if (NOT AVR_MCU)
  # FIXME: I couldn't find a way to invalidate the already built
  # targets once the AVR_MCU variable has ben changed in the cache.
  # So we are hidding the AVR_MCU variable, trying to force the user
  # to re-create the whole build, in an attempt to avoid mixing
  # different MCU binaries, size calculations and uploads.
  set(AVR_MCU "${AVR_DEFAULT_MCU}" CACHE INTERNAL "The AVR MCU used for this build")
endif()
if (AVR_PRINT_MCU)
  message(STATUS "AVR target MCU: ${AVR_MCU}")
endif()

# Cross compilarion variables
set(CMAKE_SYSTEM_NAME       Generic)
set(CMAKE_SYSTEM_PROCESSOR  avr)
set(CMAKE_C_COMPILER        avr-gcc -mmcu=${AVR_MCU})
set(CMAKE_CXX_COMPILER      avr-g++ -mmcu=${AVR_MCU})

# Compiler and linker flags
string(TOUPPER ${AVR_MCU} _avr_mcu)
string(REPLACE "XMEGA" "xmega" _avr_mcu ${_avr_mcu})
string(REPLACE "MEGA"  "mega"  _avr_mcu ${_avr_mcu})
string(REPLACE "TINY"  "tiny"  _avr_mcu ${_avr_mcu})
set(AVR_C_MACROS                   "-DAVR -D_AVR -D__AVR_${_avr_mcu}__")
set(AVR_C_FLAGS                    "${AVR_C_MACROS} -ffunction-sections -fdata-sections")
set(AVR_LINK_FLAGS                 "-Wl,--gc-sections,--relax")

set(CMAKE_C_FLAGS_INIT             "${AVR_C_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT           "${AVR_C_FLAGS} -fno-exceptions -fno-threadsafe-statics")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${AVR_LINK_FLAGS}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${AVR_LINK_FLAGS}")

#
# Find the extra tools needed
#
find_program(AVRDUDE_BIN avrdude)
find_program(AVRSIZE_BIN avr-size)
mark_as_advanced(AVRDUDE_BIN AVRSIZE_BIN)

##########################################################################
# ADD_AVR_FIRMWARE ( TARGET )
#
# Create helper targets to upload the executable to a AVR microcontroller
# using AVRDUDE (if found)
##########################################################################
function(ADD_AVR_FIRMWARE exec_target)
  set(hex_file      "${exec_target}.hex")
  set(eeprom_image  "${exec_target}_EEPROM.hex")

  if (AVRSIZE_BIN AND AVR_PRINT_SIZE)
    # Print the size after building
    add_custom_command(TARGET ${exec_target} POST_BUILD
      COMMAND ${AVRSIZE_BIN} -C --mcu=${AVR_MCU} ${exec_target}
    )
  endif()

  add_custom_command(OUTPUT ${hex_file}
    COMMAND ${CMAKE_OBJCOPY} -j .text -j .data -O ihex ${exec_target} ${hex_file}
    DEPENDS ${exec_target}
  )

  add_custom_command(OUTPUT ${eeprom_image}
    COMMAND ${CMAKE_OBJCOPY} -j .eeprom --set-section-flags=.eeprom=alloc,load
      --change-section-lma .eeprom=0 --no-change-warnings
      -O ihex ${exec_target} ${eeprom_image}
    DEPENDS ${exec_target}
  )

  if (AVRDUDE_BIN)
    add_custom_target(upload_${exec_target}
      ${AVRDUDE_BIN} -p ${AVR_MCU} -c ${AVRDUDE_PROGRAMMER} ${AVRDUDE_OTHER_ARGS}
         -b ${AVRDUDE_BITRATE}
         -U flash:w:${hex_file}:i
         -P ${AVRDUDE_PORT}
      DEPENDS ${hex_file}
      COMMENT "Uploading ${hex_file} to ${AVR_MCU} using ${AVRDUDE_PROGRAMMER}"
      USES_TERMINAL
    )

    add_custom_target(upload_${exec_target}_EEPROM
      ${AVRDUDE_BIN} -p ${AVR_MCU} -c ${AVRDUDE_PROGRAMMER} ${AVRDUDE_OTHER_ARGS}
         -b ${AVRDUDE_BITRATE}
         -U eeprom:w:${eeprom_image}
         -P ${AVRDUDE_PORT}
      DEPENDS ${eeprom_image}
      COMMENT "Uploading ${eeprom_image} to ${AVR_MCU} using ${AVRDUDE_PROGRAMMER}"
      USES_TERMINAL
    )
  endif()
endfunction()
