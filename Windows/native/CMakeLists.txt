cmake_minimum_required(VERSION 3.25)
project(ResenhaPinnedWhisper LANGUAGES C CXX)

if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "The native release requires the approved Windows x64 MSVC host.")
endif()
find_package(Git REQUIRED)
set(WHISPER_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/../../Vendor/whisper.cpp")
execute_process(COMMAND "${GIT_EXECUTABLE}" -C "${WHISPER_SOURCE}" rev-parse HEAD
  OUTPUT_VARIABLE WHISPER_REV OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
if(NOT WHISPER_REV STREQUAL "4979e04f5dcaccb36057e059bbaed8a2f5288315")
  message(FATAL_ERROR "The existing whisper.cpp source pin must not change.")
endif()
execute_process(COMMAND "${GIT_EXECUTABLE}" -C "${WHISPER_SOURCE}" status --porcelain --untracked-files=all
  OUTPUT_VARIABLE WHISPER_DIRTY OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
if(WHISPER_DIRTY)
  message(FATAL_ERROR "Native release source must match the unmodified whisper.cpp pin.")
endif()
# FMA and F16C are implied by the pinned MSVC AVX2 branch, not independent
# GGML_FMA/GGML_F16C options on MSVC. Host inventory and dependency inspection
# remain mandatory release gates; a preset does not constitute that evidence.
add_subdirectory("${WHISPER_SOURCE}" whisper)
