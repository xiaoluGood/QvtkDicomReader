
#
#  W A R N I N G
#  -------------
#
# This file is not part of the ITK API.  It exists purely as an
# implementation detail.  This CMake module may change from version to
# version without notice, or even be removed.
#
# We mean it.
#

# This file sets up include directories, link directories, IO settings and
# compiler settings for a project to use ITK.  It should not be
# included directly, but rather through the ITK_USE_FILE setting
# obtained from ITKConfig.cmake.


# Add compiler flags needed to use ITK.
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${ITK_REQUIRED_C_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${ITK_REQUIRED_CXX_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${ITK_REQUIRED_LINK_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${ITK_REQUIRED_LINK_FLAGS}")
set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${ITK_REQUIRED_LINK_FLAGS}")

# Add include directories needed to use ITK.
include_directories(BEFORE ${ITK_INCLUDE_DIRS})

# Add link directories needed to use ITK.
link_directories(${ITK_LIBRARY_DIRS})


#
# Introduction
# ------------
#
# ITK IO factories can be registered automatically either "statically" or "dynamically".
#
# "statically" : This is the mechanism described below and supported by UseITK.
#
# "dynamically": This corresponds to the runtime loading of shared libraries
#                exporting the "itkLoad" symbol and available in directory
#                associated with the `ITK_AUTOLOAD_PATH` environment variable.
#
#
# Overview: Static registration of ITK IO factories
# -------------------------------------------------
#
# For each factory type (Image, Transform, ...), a registration manager header
# named `itk<factory_type>IOFactoryRegisterManager.h` is configured.
#
# The registration manager header is itself included at the end of the Reader and
# Writer header of each factory types. It will ensure all the IO factories
# associated with the different file formats are registered only once by
# relying on static initialization of a global variable properly initialized
# by the loader across all translation units.
#
# By including either `itk<factory_type>FileReader.h` or `itk<factory_type>FileWriter.h`
# header in user code, the corresponding IO factories will be ensured to be
# registered globally and available across translation units.
#
# The file formats associated with each factory type are hard-coded as
# a list in a CMake variable named after `LIST_OF_<factory_type>IO_FORMATS`
# generated by this file.
#
#
# Registration manager header
# ---------------------------
#
# Configuration of the header requires two CMake variables to be set. The
# two variables `LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION` will
# respectively contain a list of function declaration and calls. The associated
# function names are of the form `<factory_name>FactoryRegister__Private`.
#
# These variables are set by iterating over the IO format lists.
#
#
# Disabling static registration
# -----------------------------
#
# Setting variable `ITK_NO_IO_FACTORY_REGISTER_MANAGER` to `OFF` prior calling
# `include(${ITK_USE_FILE})` disables the static registration. As a consequence,
# the two variables `LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION`
# are empty and no calls to "Private" function is done.
#
# IO format lists
# ---------------
#
# The IO format lists are CMake variables set to an hardcoded list of file
# format.
#
# One list will be set for each factory type.
#
# Variable name is expected to be of the form `LIST_OF_<factory_type>IO_FORMATS`
# where `<factory_type>` is the upper-cased `factory_type`.
#
# Notes:
#
#  * The order of file format matters: Since it will define in which order
#    the different factories are registered, it will by extension defines the
#    "priority" for each file format.
#
#  * This list does not indicates which factory are registered: It should be
#    considered as a hint to indicate the order in which factory should
#    registered based on which ITK modules are used or imported within a
#    given project.
#
#
# The "Private" function
# ----------------------
#
# The function is responsible to register the IO factory for a given format
# associated with a specific factory type.
#
# It is defined in the `itk<format><factory_type>IOFactory.cxx` file and should
# internally call the function `<format><factory_type>IOFactory::RegisterOneFactory()`.
#
# The factory is then effectively registered in `RegisterOneFactory()` by calling
# `ObjectFactoryBase::RegisterFactoryInternal(<format><factory_type>IOFactory::New())`.
#
# Notes:
#
#  * the function will be available in both shared or static build case. Static
#    initialiation will happen in both cases.
#
#  * the function is unique and consistently named for each IO factory. The
#    current naming convention is an implementation detail and is not part
#    of the ITK Public API.
#
#
# Generation of "Private()" function lists
# ----------------------------------------
#
# The configuration of the registration header for each factory is done
# using the convenience function `_configure_IOFactoryRegisterManager()`.
#
# It expects a list of file format associated with each factory types.
#
# By iterating over the format list, the CMake function `_configure_IOFactoryRegisterManager()`
# will itself call `ADD_FACTORY_REGISTRATION()` to generate the Private function
# names and update the `LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION`
# CMake lists.
#
# Every file format is associated with a module name and factory name set
# by iterating over the list of file format prior the call to `_configure_IOFactoryRegisterManager()`.
#
# For any given file format, it is possible to hardcode a different factory and
# module name by setting CMake variable of the form `<format>_<factory_type>_module_name`
# and `<format>_<factory_type>_factory_name` where `<factory_type>` is lower-cased.
#
# These custom associations are reported below under the "Exceptions" comments.
#
#
# Caveats
# -------
#
# Since the both include directory containing the registration manager headers
# and the `ITK_IO_FACTORY_REGISTER_MANAGER` COMPILE_DEFINITIONS are set as
# directory properties, including external project (themselves including ITK)
# after including ITK can have unintended side effects.
#



# _configure_IOFactoryRegisterManager(<factory_type> <formats>)
#
# Configure the registration manager header in the directory
# `<CMAKE_CURRENT_BINARY_DIR>/ITKIOFactoryRegistration/`.
#
# Header is named using the template `itk<factory_type>IOFactoryRegisterManager.h`
#
function(_configure_IOFactoryRegisterManager factory_type formats)
  set(LIST_OF_FACTORIES_REGISTRATION "")
  set(LIST_OF_FACTORY_NAMES "")

  string(TOLOWER ${factory_type} _qualifier)

  foreach (format ${formats})
    set(_module_name ${${format}_${_qualifier}_module_name})
    set(_factory_name ${${format}_${_qualifier}_factory_name})
    ADD_FACTORY_REGISTRATION("LIST_OF_FACTORIES_REGISTRATION" "LIST_OF_FACTORY_NAMES"
      ${_module_name} ${_factory_name})
  endforeach()

  get_filename_component(_selfdir "${CMAKE_CURRENT_LIST_FILE}" PATH)
  configure_file(${_selfdir}/itk${factory_type}IOFactoryRegisterManager.h.in
   "${CMAKE_CURRENT_BINARY_DIR}/ITKIOFactoryRegistration/itk${factory_type}IOFactoryRegisterManager.h" @ONLY)

endfunction()

# ADD_FACTORY_REGISTRATION(<registration_list_var> <names_list_var> <module_name> <factory_name>)
#
# Update variables`LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION`
# used to configure `itk<factory_type>IOFactoryRegisterManager.h`.
#
macro(ADD_FACTORY_REGISTRATION _registration_list_var _names_list_var _module_name _factory_name)
  list(FIND ITK_MODULES_REQUESTED ${_module_name} _module_was_requested)
  if(NOT ${_module_was_requested} EQUAL -1)
    # note: this is an internal CMake variable and should not be used outside ITK
    set(_abi)
    if(${_module_name}_ENABLE_SHARED AND ITK_BUILD_SHARED)
      set(_abi "ITK_ABI_IMPORT")
    endif()
    set(${_registration_list_var}
      "${${_registration_list_var}}void ${_abi} ${_factory_name}FactoryRegister__Private();")
    set(${_names_list_var} "${${_names_list_var}}${_factory_name}FactoryRegister__Private,")
  endif()
endmacro()

#-----------------------------------------------------------------------------
# ImageIO
#-----------------------------------------------------------------------------

# a list of image IOs to be registered when the corresponding modules are enabled
set(LIST_OF_IMAGEIO_FORMATS
    Nifti Nrrd Gipl HDF5 JPEG GDCM BMP LSM PNG TIFF VTK Stimulate BioRad Meta MRC GE4 GE5
    MINC
    MGH SCIFIO FDF OpenSlide
    PhilipsREC
    )

# Exceptions:

set(Nifti_image_module_name  ITKIONIFTI)

set(Nrrd_image_module_name ITKIONRRD)

set(Gipl_image_module_name ITKIOGIPL)

set(MGH_image_module_name MGHIO)

set(OpenSlide_image_module_name IOOpenSlide)

set(GE4_image_module_name ITKIOGE)
set(GE5_image_module_name ITKIOGE)

set(SCIFIO_image_module_name SCIFIO)

set(FDF_image_module_name IOFDF)

foreach(ImageFormat ${LIST_OF_IMAGEIO_FORMATS})
  if (NOT ${ImageFormat}_image_module_name )
     set(${ImageFormat}_image_module_name ITKIO${ImageFormat})
  endif()
  if (NOT ${ImageFormat}_image_factory_name)
     set(${ImageFormat}_image_factory_name ${ImageFormat}ImageIO)
  endif()
endforeach()

if(NOT ITK_NO_IO_FACTORY_REGISTER_MANAGER)
  _configure_IOFactoryRegisterManager("Image" "${LIST_OF_IMAGEIO_FORMATS}")
endif()

#-----------------------------------------------------------------------------
# TransformIO
#-----------------------------------------------------------------------------

# a list of transform IOs to be registered when the corresponding modules are enabled
set(LIST_OF_TRANSFORMIO_FORMATS
  HDF5
  Matlab
  MINC
  Txt
  )

# Exceptions:

set(Txt_transform_module_name ITKIOTransformInsightLegacy)
set(Txt_transform_factory_name TxtTransformIO)

foreach(TransformFormat ${LIST_OF_TRANSFORMIO_FORMATS})
  if (NOT ${TransformFormat}_transform_module_name )
    set(${TransformFormat}_transform_module_name ITKIOTransform${TransformFormat})
  endif()
  if (NOT ${TransformFormat}_transform_factory_name)
    set(${TransformFormat}_transform_factory_name ${TransformFormat}TransformIO)
  endif()
endforeach()

if(NOT ITK_NO_IO_FACTORY_REGISTER_MANAGER)
  _configure_IOFactoryRegisterManager("Transform" "${LIST_OF_TRANSFORMIO_FORMATS}")
endif()


#-----------------------------------------------------------------------------
if(NOT ITK_NO_IO_FACTORY_REGISTER_MANAGER)

  set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS ITK_IO_FACTORY_REGISTER_MANAGER)
  include_directories(BEFORE ${CMAKE_CURRENT_BINARY_DIR}/ITKIOFactoryRegistration)

endif()