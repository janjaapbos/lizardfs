#!/usr/bin/env bash
set -eux

# Directories used by this script
output_dir=$(pwd)
source_dir=$(dirname "$0")
working_dir=/tmp/lizardfs_deb_working_directory

os_release="$(lsb_release -si)/$(lsb_release -sr)"

# Systemd is added by default, except for the following systems
case "$os_release" in
  Debian*/7*)  use_systemd=0 ;;
  Ubuntu*/12*) use_systemd=0 ;;
  Ubuntu*/14*) use_systemd=0 ;;
  *) use_systemd=1 ;;
esac

# Create an empty working directory and clone sources there to make
# sure there are no additional files included in the source package
rm -rf "$working_dir"
mkdir "$working_dir"
git clone "$source_dir" "$working_dir/lizardfs"

# Build packages.
cd "$working_dir/lizardfs"

git checkout v3.10.4-opt

# Move service files to debian/
cp rpm/service-files/* debian/

if [[ ${BUILD_NUMBER:-} && ${OFFICIAL_RELEASE:-} == "false" ]] ; then
	# Jenkins has called us. Add build number to the package version
	# and add information about commit to changelog.
	lizard_version=$(dpkg-parsechangelog | awk '/^Version:/{print $2}')
	version="${lizard_version}.${BUILD_NUMBER}"
	dch -D "unstable" -v "$version" "Automatic jenkins build ${BUILD_URL:-}"
	dch -D "unstable" -a "commit: ${GIT_COMMIT:-}"
	dch -D "unstable" -a "refspec: ${GERRIT_REFSPEC:-}"
fi

if [[ $use_systemd == 0 ]]; then
	dpkg-buildpackage -uc -us -F -R'debian/rules-nosystemd'
else
	dpkg-buildpackage -uc -us -F
fi

# Copy all the created files and clean up
cp "$working_dir"/lizardfs?* "$output_dir"
rm -rf "$working_dir"
