cmake_minimum_required(VERSION 3.5.0)
project(ClashMate)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

add_library(entry SHARED napi_init.cpp)
target_link_libraries(entry PUBLIC libace_napi.z.so)
