cmake_minimum_required(VERSION 3.20)
project(edf-app C)
add_executable(edf-app main.c)
install(TARGETS edf-app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
