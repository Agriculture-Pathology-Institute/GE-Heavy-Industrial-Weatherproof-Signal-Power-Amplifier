# File Path: CMakeLists.txt (Inside the Amplifier Repository Root)
cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(ge_univac_amplifier_bridge)

target_sources(app PRIVATE src/hardware/zephyr_univac_bridge.c)
