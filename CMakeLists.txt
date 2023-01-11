## Copyright 2009 Intel Corporation
## SPDX-License-Identifier: Apache-2.0


CMAKE_MINIMUM_REQUIRED(VERSION 3.6 FATAL_ERROR)

IF(POLICY CMP0043)
  CMAKE_POLICY(SET CMP0043 OLD)
ENDIF()
IF(POLICY CMP0054)
  CMAKE_POLICY(SET CMP0054 NEW)
ENDIF()

PROJECT(SCIOspray)

OPTION(ENABLE_OSPRAY_SUPERBUILD "Use Ospray Superbuild directly" OFF)

IF(ENABLE_OSPRAY_SUPERBUILD)
  INCLUDE(${CMAKE_SOURCE_DIR}/scripts/superbuild/CMakeLists.txt)
ELSE()
  INCLUDE(${CMAKE_SOURCE_DIR}/OriginalOsprayCMake.cmake)
ENDIF()

set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

##############################################################
# Establish project
##############################################################

include(cmake/ospray_version.cmake)

project(OSPRay VERSION ${OSPRAY_VERSION} LANGUAGES C CXX)

##############################################################
# CMake modules and macro files
##############################################################

list(APPEND CMAKE_MODULE_PATH
  ${PROJECT_SOURCE_DIR}/cmake
  ${PROJECT_SOURCE_DIR}/cmake/compiler
)

include(ospray_macros)
include(ospray_options)
include(package)
include(ispc)

if (OSPRAY_INSTALL_DEPENDENCIES)
  include(ospray_redistribute_deps)
endif()

##############################################################
# Add library and executable targets
##############################################################

## Main OSPRay library ##
add_subdirectory(ospray)

## Modules ##
add_subdirectory(modules)

## OSPRay sample apps ##
add_subdirectory(apps)

## Regression test images target ##
add_subdirectory(test_image_data)

## Clang-format target ##
if (OSPRAY_ENABLE_TARGET_CLANGFORMAT)
  include(clang-format)
endif()

# Must be last
include(CPack)
