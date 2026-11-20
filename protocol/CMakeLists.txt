cmake_minimum_required(VERSION 3.16)
project(Mbox2ProtocolCore LANGUAGES CXX)

add_library(mbox2_protocol INTERFACE)
target_include_directories(mbox2_protocol INTERFACE include)
target_compile_features(mbox2_protocol INTERFACE cxx_std_17)

add_executable(mbox2_protocol_tests tests/protocol_tests.cpp)
target_link_libraries(mbox2_protocol_tests PRIVATE mbox2_protocol)

enable_testing()
add_test(NAME mbox2_protocol_tests COMMAND mbox2_protocol_tests)
