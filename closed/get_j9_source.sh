#!/bin/sh

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
    
usage() {
	echo "Usage: $0 [-h|--help] [-openj9-repo=<j9vm repo url>] [-openj9-branch=<branch>] [-openj9-sha=<commit sha>] [... other OpenJ9 repositories and branches options] [-parallel=<true|false>]"
	echo "where:"
	echo "  -h|--help         print this help, then exit"
	echo "  -openj9-repo      the OpenJ9 repository url: git@github.ibm.com:runtimes/proxy-openj9.git"
	echo "                    or git@github.ibm.com:<namespace>/proxy-openj9.git"
	echo "  -openj9-branch    the OpenJ9 git branch: master"
	echo "  -openj9-sha       a commit SHA for the OpenJ9 repository"
	echo "  -omr-repo         the OpenJ9/omr repository url: git@github.ibm.com:runtimes/proxy-openj9-omr.git"
	echo "                    or git@github.ibm.com:<namespace>/proxy-openj9-omr.git"
	echo "  -omr-branch       the OpenJ9/omr git branch: java-master"
	echo "  -omr-sha           a commit SHA for the omr repository"
	echo "  -parallel         (boolean) if 'true' then the clone j9 repository commands run in parallel, default is false"
	echo ""
	exit 1
}

# require bash 4.0 or later to support associative arrays
bash_version=`bash --version | sed -n 1p`
if [[ $bash_version != *"version 4."* ]] ; then
	echo "Bash version 4.0 or later is required!"
	exit 1
fi

declare -A j9repos
declare -A branches
declare -A default_j9repos=( [openj9]=runtimes/proxy-openj9 [omr]=runtimes/proxy-openj9-omr )
declare -A default_branches=( [openj9]=master [omr]=openj9 )
declare -A commands
declare -A shas

pflag="false"
base_git_url=git@github.ibm.com

for i in "$@"
do
	case $i in
		-h | --help )
		usage
		;;

		-r=* | --revision=* )
		hgtag="${i#*=}"
		;;

		-openj9-repo=* )
		j9repos[openj9]="${i#*=}"
		;;

		-openj9-branch=* )
		branches[openj9]="${i#*=}"
		;;

		-openj9-sha=* )
		shas[openj9]="${i#*=}"
		;;

		-omr-repo=* )
		j9repos[omr]="${i#*=}"
		;;

		-omr-branch=* )
		branches[omr]="${i#*=}"
		;;

		-omr-sha=* )
		shas[omr]="${i#*=}"
		;;

		-parallel=* )
		pflag="${i#*=}"
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

git=`which git`

# clone OpenJ9 repos
date '+[%F %T] Get OpenJ9 sources'
START_TIME=$(date +%s)

for i in "${!default_j9repos[@]}" ; do
	branch=${default_branches[$i]}
	if [ ${branches[$i]+_} ]; then
		branch=${branches[$i]}
	fi

	if [ -d ${i} ]; then
		echo
		echo "Update ${i} source"
		echo

		cd ${i}
		git pull --rebase origin ${branch} || exit $?

		if [ -f .gitmodules ]; then
			git pull --rebase --recurse-submodules=yes || exit $?
			git submodule update --rebase --recursive || exit $?
		fi
		cd -
	else
		git_url=${base_git_url}:${default_j9repos[$i]}.git

		if [ ${j9repos[$i]+_} ]; then
			git_url="${j9repos[$i]}"
		fi

		git_clone_command="${git} clone --recursive -b ${branch} ${git_url} ${i}"
		commands[$i]=${git_clone_command}

		echo
		echo "Clone repository: ${i}"
		echo

		if [ ${pflag} = "true" ] ; then
			# run git clone in parallel
			( ${git_clone_command} ; echo "$?" > /tmp/${i}.pid.rc ) 2>&1 &
		else
			${git_clone_command} || exit $?
		fi
	fi
done

if [ ${pflag} = "true" ] ; then
	# Wait for all subprocesses to complete
	wait
fi

END_TIME=$(date +%s)
date "+[%F %T] OpenJ9 clone repositories finished in $(($END_TIME - $START_TIME)) seconds"

for i in "${!default_j9repos[@]}" ; do
	if [ -e /tmp/${i}.pid.rc ]; then
		# check if the git clone repository command failed
		rc=`cat /tmp/${i}.pid.rc | tr -d ' \n\r'`

		if [ "$rc" -ne "0" ]; then
			echo "ERROR: repository ${i} exited abnormally!"
			cat /tmp/${i}.pid.rc
			echo "Re-run: ${commands[$i]}"

			# clean up sources
			if [ -d ${i} ] ; then
				rm -fdr ${i}
			fi

			# clean up pid file
			rm -f /tmp/${i}.pid.rc
			exit 1
		fi
	fi

	if [ ${shas[$i]+_} ]; then
		echo
		echo "Update ${i} to commit ID: ${shas[$i]}"
		echo

		cd ${i}
		git checkout ${shas[$i]} || exit $?
		cd -
	fi
done
