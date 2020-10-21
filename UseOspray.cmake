if(NOT Ospray_FOUND)
  MESSAGE(FATAL_ERROR "Including UseOspray.cmake but the Ospray package was not found.")
endif()

include_directories(${SCI_OSPRAY_INCLUDE})
link_directories(${SCI_OSPRAY_LIBRARY_DIR})
