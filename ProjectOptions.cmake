include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(tiit_cpp_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(tiit_cpp_setup_options)
  option(tiit_cpp_ENABLE_HARDENING "Enable hardening" ON)
  option(tiit_cpp_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    tiit_cpp_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    tiit_cpp_ENABLE_HARDENING
    OFF)

  tiit_cpp_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR tiit_cpp_PACKAGING_MAINTAINER_MODE)
    option(tiit_cpp_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(tiit_cpp_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(tiit_cpp_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tiit_cpp_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tiit_cpp_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(tiit_cpp_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(tiit_cpp_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tiit_cpp_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(tiit_cpp_ENABLE_IPO "Enable IPO/LTO" ON)
    option(tiit_cpp_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(tiit_cpp_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(tiit_cpp_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(tiit_cpp_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tiit_cpp_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tiit_cpp_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tiit_cpp_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(tiit_cpp_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(tiit_cpp_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tiit_cpp_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      tiit_cpp_ENABLE_IPO
      tiit_cpp_WARNINGS_AS_ERRORS
      tiit_cpp_ENABLE_USER_LINKER
      tiit_cpp_ENABLE_SANITIZER_ADDRESS
      tiit_cpp_ENABLE_SANITIZER_LEAK
      tiit_cpp_ENABLE_SANITIZER_UNDEFINED
      tiit_cpp_ENABLE_SANITIZER_THREAD
      tiit_cpp_ENABLE_SANITIZER_MEMORY
      tiit_cpp_ENABLE_UNITY_BUILD
      tiit_cpp_ENABLE_CLANG_TIDY
      tiit_cpp_ENABLE_CPPCHECK
      tiit_cpp_ENABLE_COVERAGE
      tiit_cpp_ENABLE_PCH
      tiit_cpp_ENABLE_CACHE)
  endif()

  tiit_cpp_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (tiit_cpp_ENABLE_SANITIZER_ADDRESS OR tiit_cpp_ENABLE_SANITIZER_THREAD OR tiit_cpp_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(tiit_cpp_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(tiit_cpp_global_options)
  if(tiit_cpp_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    tiit_cpp_enable_ipo()
  endif()

  tiit_cpp_supports_sanitizers()

  if(tiit_cpp_ENABLE_HARDENING AND tiit_cpp_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tiit_cpp_ENABLE_SANITIZER_UNDEFINED
       OR tiit_cpp_ENABLE_SANITIZER_ADDRESS
       OR tiit_cpp_ENABLE_SANITIZER_THREAD
       OR tiit_cpp_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${tiit_cpp_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${tiit_cpp_ENABLE_SANITIZER_UNDEFINED}")
    tiit_cpp_enable_hardening(tiit_cpp_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(tiit_cpp_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(tiit_cpp_warnings INTERFACE)
  add_library(tiit_cpp_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  tiit_cpp_set_project_warnings(
    tiit_cpp_warnings
    ${tiit_cpp_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(tiit_cpp_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(tiit_cpp_options)
  endif()

  include(cmake/Sanitizers.cmake)
  tiit_cpp_enable_sanitizers(
    tiit_cpp_options
    ${tiit_cpp_ENABLE_SANITIZER_ADDRESS}
    ${tiit_cpp_ENABLE_SANITIZER_LEAK}
    ${tiit_cpp_ENABLE_SANITIZER_UNDEFINED}
    ${tiit_cpp_ENABLE_SANITIZER_THREAD}
    ${tiit_cpp_ENABLE_SANITIZER_MEMORY})

  set_target_properties(tiit_cpp_options PROPERTIES UNITY_BUILD ${tiit_cpp_ENABLE_UNITY_BUILD})

  if(tiit_cpp_ENABLE_PCH)
    target_precompile_headers(
      tiit_cpp_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(tiit_cpp_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    tiit_cpp_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(tiit_cpp_ENABLE_CLANG_TIDY)
    tiit_cpp_enable_clang_tidy(tiit_cpp_options ${tiit_cpp_WARNINGS_AS_ERRORS})
  endif()

  if(tiit_cpp_ENABLE_CPPCHECK)
    tiit_cpp_enable_cppcheck(${tiit_cpp_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(tiit_cpp_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    tiit_cpp_enable_coverage(tiit_cpp_options)
  endif()

  if(tiit_cpp_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(tiit_cpp_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(tiit_cpp_ENABLE_HARDENING AND NOT tiit_cpp_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tiit_cpp_ENABLE_SANITIZER_UNDEFINED
       OR tiit_cpp_ENABLE_SANITIZER_ADDRESS
       OR tiit_cpp_ENABLE_SANITIZER_THREAD
       OR tiit_cpp_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    tiit_cpp_enable_hardening(tiit_cpp_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
