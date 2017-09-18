#!/bin/sh

#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This code is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 only, as
# published by the Free Software Foundation.  Oracle designates this
# particular file as subject to the "Classpath" exception as provided
# by Oracle in the LICENSE file that accompanied this code.
#
# This code is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# version 2 for more details (a copy is included in the LICENSE file that
# accompanied this code).
#
# You should have received a copy of the GNU General Public License version
# 2 along with this work; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
# or visit www.oracle.com if you need additional information or have any
# questions.
#

usage() {
	echo "Usage: $0 [-h|--help] [... other j9 options] [-parallel=<true|false>]"
	echo "where:"
	echo "  -h|--help         print this help, then exit"
	echo " "
	echo "  -openj9-repo      the OpenJ9 repository url: https://github.com/eclipse/openj9.git"
	echo "                    or git@github.com:<namespace>/openj9.git"
	echo "  -openj9-branch    the OpenJ9 git branch: master"
	echo "  -openj9-sha       a commit SHA for the OpenJ9 repository"
	echo "  -omr-repo         the OpenJ9/omr repository url: https://github.com/eclipse/openj9-omr.git"
	echo "                    or git@github.com:<namespace>/openj9-omr.git"
	echo "  -omr-branch       the OpenJ9/omr git branch: openj9"
	echo "  -omr-sha           a commit SHA for the omr repository"
	echo "  -parallel         (boolean) if 'true' then the clone j9 repository commands run in parallel, default is false"
	echo " "
	exit 1
}

j9options=""

for i in "$@" ; do
	case $i in
		-h | --help )
			usage
			;;

		-openj9-repo=* | -openj9-branch=* | -openj9-sha=* | -omr-repo=* | -omr-branch=* | -omr-sha=* | -parallel=* )
			j9options="${j9options} ${i}"
			;;

		'--' ) # no more options
			usage
			;;

		-*) # bad option
			usage
			;;

		*) # bad option
			usage
			;;
	esac
done

# Get clones of OpenJ9 absent repositories
bash closed/get_j9_source.sh ${j9options}

