# ===========================================================================
# (c) Copyright IBM Corp. 2017 All Rights Reserved
# ===========================================================================
#
# This code is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 only, as
# published by the Free Software Foundation.
#
# This code is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# version 2 for more details (a copy is included in the LICENSE file that
# accompanied this code).
#
# You should have received a copy of the GNU General Public License version
# 2 along with this work; if not, see <http://www.gnu.org/licenses/>.
#
# ===========================================================================

AC_DEFUN_ONCE([CUSTOM_EARLY_HOOK],
[
  JAVA_BASE_LDFLAGS="${JAVA_BASE_LDFLAGS} -L\$(SUPPORT_OUTPUTDIR)/../vm"
  OPENJDK_BUILD_JAVA_BASE_LDFLAGS="${OPENJDK_BUILD_JAVA_BASE_LDFLAGS} -L\$(SUPPORT_OUTPUTDIR)/../vm"

  # Where are the OpenJ9 sources.
  OPENJ9OMR_TOPDIR="$SRC_ROOT/omr"
  OPENJ9_TOPDIR="$SRC_ROOT/openj9"

  if ! test -d "$OPENJ9_TOPDIR" ; then
    AC_MSG_ERROR(["Cannot locate the path to OpenJ9 sources: $OPENJ9_TOPDIR! Try 'bash get_source.sh' and restart configure"])
  fi

  if ! test -d "$OPENJ9OMR_TOPDIR" ; then
    AC_MSG_ERROR(["Cannot locate the path to OMR sources: $OPENJ9OMR_TOPDIR! Try 'bash get_source.sh' and restart configure"])
  fi

  AC_SUBST(OPENJ9OMR_TOPDIR)
  AC_SUBST(OPENJ9_TOPDIR)

  OPENJ9_BASIC_SETUP_FUNDAMENTAL_TOOLS
  OPENJ9_PLATFORM_SETUP
  OPENJDK_VERSION_DETAILS
  OPENJ9_CONFIGURE_CUDA
  OPENJ9_CONFIGURE_NUMA
  OPENJ9_THIRD_PARTY_REQUIREMENTS
])

AC_DEFUN([OPENJ9_BASIC_SETUP_FUNDAMENTAL_TOOLS],
[
  BASIC_REQUIRE_PROGS(M4, m4)
])

AC_DEFUN_ONCE([OPENJ9_CONFIGURE_NUMA],
[
  if test "x$OPENJDK_TARGET_OS" = xlinux; then
    if test "x$OPENJDK_TARGET_CPU_ARCH" = xx86 -o "x$OPENJDK_TARGET_CPU_ARCH" = xppc; then
      AC_MSG_CHECKING([checking for numa])
      if test -f /usr/include/numa.h -a -f /usr/include/numaif.h; then
        AC_MSG_RESULT([yes])
      else
        AC_MSG_RESULT([no])
        HELP_MSG_MISSING_DEPENDENCY([numa])
        AC_MSG_ERROR([Could not find numa! $HELP_MSG])
      fi
    fi
  fi
])

AC_DEFUN([OPENJ9_CONFIGURE_CUDA],
[
  AC_ARG_WITH(cuda, [AS_HELP_STRING([--with-cuda], [use this directory as CUDA_HOME])],
    [
      if test -d "$with_cuda" ; then
        OPENJ9_CUDA_HOME=$with_cuda
      else
        AC_MSG_ERROR([CUDA not found at $with_cuda])
      fi
    ]
  )

  AC_ARG_WITH(gdk, [AS_HELP_STRING([--with-gdk], [use this directory as GDK_HOME])],
    [
      if test -d "$with_gdk" ; then
        OPENJ9_GDK_HOME=$with_gdk
      else
        AC_MSG_ERROR([GDK not found at $with_gdk])
      fi
    ]
  )

  AC_MSG_CHECKING([for cuda])
  AC_ARG_ENABLE([cuda], [AS_HELP_STRING([--enable-cuda], [enable CUDA support @<:@disabled@:>@])])
  if test "x$enable_cuda" = xyes ; then
    AC_MSG_RESULT([yes (explicitly set)])
    OPENJ9_ENABLE_CUDA=true
  elif test "x$enable_cuda" = xno ; then
    AC_MSG_RESULT([no])
    OPENJ9_ENABLE_CUDA=false
  elif test "x$enable_cuda" = x ; then
    AC_MSG_RESULT([no (default)])
    OPENJ9_ENABLE_CUDA=false
  else
    AC_MSG_ERROR([--enable-cuda accepts no argument])
  fi

  AC_SUBST(OPENJ9_ENABLE_CUDA)
  AC_SUBST(OPENJ9_CUDA_HOME)
  AC_SUBST(OPENJ9_GDK_HOME)
])

AC_DEFUN([OPENJ9_PLATFORM_EXTRACT_VARS_FROM_CPU],
[
  # Convert openjdk cpu names to openj9 names
  case "$1" in
    x86_64)
      OPENJ9_CPU=x86-64
      ;;
    powerpc64le)
      OPENJ9_CPU=ppc-64_le
      ;;
    s390x)
      OPENJ9_CPU=390-64
      ;;
    *)
      AC_MSG_ERROR([unsupported OpenJ9 cpu $1])
      ;;
  esac
])

AC_DEFUN_ONCE([OPENJ9_PLATFORM_SETUP],
[
  OPENJ9_PLATFORM_EXTRACT_VARS_FROM_CPU($build_cpu)
  OPENJ9_BUILDSPEC="${OPENJDK_BUILD_OS}_${OPENJ9_CPU}_cmprssptrs"

  if test "x$OPENJ9_CPU" = xx86-64; then
    if test "x$OPENJDK_BUILD_OS" = xlinux; then
      OPENJ9_PLATFORM_CODE=xa64
    elif test "x$OPENJDK_BUILD_OS" = xwindows; then
      OPENJ9_PLATFORM_CODE=wa64
      OPENJ9_BUILDSPEC="win_x86-64_cmprssptrs"
    else
      AC_MSG_ERROR([Unsupported OpenJ9 platform ${OPENJDK_BUILD_OS}, contact support team!])
    fi
  elif test "x$OPENJ9_CPU" = xppc-64_le; then
    OPENJ9_PLATFORM_CODE=xl64
    OPENJ9_BUILDSPEC="${OPENJDK_BUILD_OS}_ppc-64_cmprssptrs_le_gcc"
  elif test "x$OPENJ9_CPU" = x390-64; then
    OPENJ9_PLATFORM_CODE=xz64
  else
    AC_MSG_ERROR([Unsupported OpenJ9 cpu ${OPENJ9_CPU}, contact support team!])
  fi

  AC_SUBST(OPENJ9_BUILDSPEC)
  AC_SUBST(OPENJ9_PLATFORM_CODE)
  AC_SUBST(COMPILER_VERSION_STRING)
])

AC_DEFUN_ONCE([OPENJDK_VERSION_DETAILS],
[
  OPENJDK_SHA=`git -C $SRC_ROOT rev-parse --short HEAD`
  OPENJDK_TAG=`git -C $SRC_ROOT describe --abbrev=0 --tags "${OPENJDK_SHA}"`
  AC_SUBST(OPENJDK_SHA)
  AC_SUBST(OPENJDK_TAG)
])

AC_DEFUN_ONCE([OPENJ9_THIRD_PARTY_REQUIREMENTS],
[
  # check 3rd party library requirement for UMA
  AC_MSG_CHECKING([that freemarker location is set])
  AC_ARG_WITH(freemarker-jar, [AS_HELP_STRING([--with-freemarker-jar],
      [path to freemarker.jar (used to build OpenJ9 build tools)])])

  if test "x$with_freemarker_jar" == x; then
    AC_MSG_RESULT([no])
    printf "\n"
    printf "The FreeMarker library is required to build the OpenJ9 build tools\n"
    printf "and has to be provided during configure process.\n"
    printf "\n"
    printf "Download the FreeMarker library and unpack it into an arbitrary directory:\n"
    printf "\n"
    printf "wget https://sourceforge.net/projects/freemarker/files/freemarker/2.3.8/freemarker-2.3.8.tar.gz/download -O freemarker-2.3.8.tar.gz\n"
    printf "\n"
    printf "tar -xzf freemarker-2.3.8.tar.gz\n"
    printf "\n"
    printf "Then run configure with '--with-freemarker-jar=<freemarker_jar>'\n"
    printf "\n"

    AC_MSG_NOTICE([Could not find freemarker.jar])
    AC_MSG_ERROR([Cannot continue])
  else
    AC_MSG_RESULT([yes])
    AC_MSG_CHECKING([checking that '$with_freemarker_jar' exists])
    if test -f "$with_freemarker_jar"; then
      AC_MSG_RESULT([yes])
    else
      AC_MSG_RESULT([no])
      AC_MSG_ERROR([freemarker.jar not found at '$with_freemarker_jar'])
    fi
  fi

  if test "x$OPENJDK_BUILD_OS_ENV" = xwindows.cygwin; then
    FREEMARKER_JAR=`$CYGPATH -m "$with_freemarker_jar"`
  else
    FREEMARKER_JAR=$with_freemarker_jar
  fi

  AC_SUBST(FREEMARKER_JAR)
])

AC_DEFUN_ONCE([CUSTOM_LATE_HOOK],
[
  CLOSED_AUTOCONF_DIR="$SRC_ROOT/closed/autoconf"

  # Create the custom-spec.gmk
  AC_CONFIG_FILES([$OUTPUT_ROOT/custom-spec.gmk:$CLOSED_AUTOCONF_DIR/custom-spec.gmk.in])

  # explicitly disable classlist generation
  ENABLE_GENERATE_CLASSLIST="false"
])
