
cmake_minimum_required(VERSION 2.8)

find_package(Boost COMPONENTS system filesystem REQUIRED)
find_package(OpenCV REQUIRED)

add_executable(serial_base src/serial_base.cpp)

add_executable(serial_base_debug src/serial_base.cpp)

target_link_libraries(serial_base ${OpenCV_LIBS} ${Boost_LIBRARIES})
target_link_libraries(serial_base_debug ${OpenCV_LIBS} ${Boost_LIBRARIES})
set_target_properties(serial_base_debug PROPERTIES COMPILE_FLAGS "-g" )