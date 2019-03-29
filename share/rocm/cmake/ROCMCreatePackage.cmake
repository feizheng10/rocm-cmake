################################################################################
# Copyright (C) 2017 Advanced Micro Devices, Inc.
################################################################################


include(CMakeParseArguments)
include(GNUInstallDirs)
include(CPackComponent)

find_program(MAKE_NSIS_EXE makensis)
find_program(RPMBUILD_EXE rpmbuild)
find_program(DPKG_EXE dpkg)

function(create_cpack_config filename)
  cpack_add_component("clients")
  set (CPACK_DEB_COMPONENT_INSTALL ON)
  set(CPACK_COMPONENTS_ALL clients)
  set(CPACK_COMPONENTS_IGNORE_GROUPS 1)
  #set(CPACK_PACKAGE_NAME "clients")
  #set(CPACK_PACKAGE_VENDOR "Advanced Micro Devices, Inc")
  #set(CPACK_DEBIAN_PACKAGE_MAINTAINER "sem")
  #set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
  set(CPACK_GENERATOR "DEB")

  message("***************************")
  set(CPACK_OUTPUT_CONFIG_FILE "${filename}")
  message( STATUS "debug, create cpack file: " ${filename} )
  message("***************************")
  include(CPack)
endfunction(create_cpack_config)

macro(rocm_create_package)
    set(options LDCONFIG PTH)
    set(oneValueArgs NAME DESCRIPTION SECTION MAINTAINER LDCONFIG_DIR PREFIX COMPONENT_NAME)
    set(multiValueArgs DEPENDS)

    cmake_parse_arguments(PARSE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(CPACK_PACKAGE_NAME ${PARSE_NAME})
    set(CPACK_PACKAGE_VENDOR "Advanced Micro Devices, Inc")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${PARSE_DESCRIPTION})
    set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
    set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
    set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
    set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
    
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER ${PARSE_MAINTAINER})
    set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
        
    if(PARSE_DEPENDS)
        string(REPLACE ";" ", " DEPENDS "${PARSE_DEPENDS}")
        set(CPACK_DEBIAN_PACKAGE_DEPENDS "${DEPENDS}")
        set(CPACK_RPM_PACKAGE_REQUIRES "${DEPENDS}")
    endif()
        
    if(NOT CMAKE_HOST_WIN32)
        set( CPACK_SET_DESTDIR ON CACHE BOOL "Boolean toggle to make CPack use DESTDIR mechanism when packaging" )
    endif()

    set(COMPONENT_NAME "libraries")
    if(PARSE_COMPONENT_NAME)
       set(COMPONENT_NAME ${PARSE_COMPONENT_NAME})
    endif()

    if("${COMPONENT_NAME}" STREQUAL "clients")

        create_cpack_config(CPackConfig-clients.cmake)
        add_custom_target(package_clients cpack --config ../clients/CPackConfig-clients.cmake)

    else ()
        

        set(CPACK_NSIS_MODIFY_PATH On)
        set(CPACK_NSIS_PACKAGE_NAME ${PARSE_NAME})

        set(CPACK_RPM_PACKAGE_RELOCATABLE Off)
        set( CPACK_RPM_PACKAGE_AUTOREQPROV Off CACHE BOOL "turns off rpm autoreqprov field; packages explicity list dependencies" )

        set(CPACK_GENERATOR "TGZ;ZIP")
        if(EXISTS ${MAKE_NSIS_EXE})
            list(APPEND CPACK_GENERATOR "NSIS")
        endif()

        if(EXISTS ${RPMBUILD_EXE})
            list(APPEND CPACK_GENERATOR "RPM")
        endif()

        if(EXISTS ${DPKG_EXE})
            list(APPEND CPACK_GENERATOR "DEB")
        endif()

        set(LIB_DIR ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
        if(PARSE_PREFIX)
            set(LIB_DIR ${CMAKE_INSTALL_PREFIX}/${PARSE_PREFIX}/${CMAKE_INSTALL_LIBDIR})
        endif()

        file(WRITE ${PROJECT_BINARY_DIR}/debian/postinst "")
        file(WRITE ${PROJECT_BINARY_DIR}/debian/prerm "")
        set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA "${PROJECT_BINARY_DIR}/debian/postinst;${PROJECT_BINARY_DIR}/debian/prerm")
        set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE "${PROJECT_BINARY_DIR}/debian/postinst")
        set(CPACK_RPM_PRE_UNINSTALL_SCRIPT_FILE "${PROJECT_BINARY_DIR}/debian/prerm")

        if(PARSE_LDCONFIG)
            set(LDCONFIG_DIR ${LIB_DIR})
            if(PARSE_LDCONFIG_DIR)
                set(LDCONFIG_DIR ${PARSE_LDCONFIG_DIR})
            endif()
            file(APPEND ${PROJECT_BINARY_DIR}/debian/postinst "
                echo \"${LDCONFIG_DIR}\" > /etc/ld.so.conf.d/${PARSE_NAME}.conf
                ldconfig
            ")

            file(APPEND ${PROJECT_BINARY_DIR}/debian/prerm "
                rm /etc/ld.so.conf.d/${PARSE_NAME}.conf
                ldconfig
            ")
        endif()

        if(PARSE_PTH)
            set(PYTHON_SITE_PACKAGES "/usr/lib/python3/dist-packages;/usr/lib/python2.7/dist-packages" CACHE STRING "The site packages used for packaging")
            foreach(PYTHON_SITE ${PYTHON_SITE_PACKAGES})
                file(APPEND ${PROJECT_BINARY_DIR}/debian/postinst "
                    mkdir -p ${PYTHON_SITE}
                    echo \"${LIB_DIR}\" > ${PYTHON_SITE}/${PARSE_NAME}.pth
                ")

                file(APPEND ${PROJECT_BINARY_DIR}/debian/prerm "
                    rm ${PYTHON_SITE}/${PARSE_NAME}.pth
                ")
            endforeach()
        endif()
        include(CPack)

    endif()

endmacro()
