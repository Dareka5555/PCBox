#!/bin/sh
#
# 86Box    A hypervisor and IBM PC system emulator that specializes in
#          running old operating systems and software designed for IBM
#          PC systems and compatibles from 1981 through fairly recent
#          system designs based on the PCI bus.
#
#          This file is part of the 86Box distribution.
#
#          CI packaging script.
#
#
# Authors: RichardG, <richardg867@gmail.com>
#
#          Copyright 2021-2026 RichardG.
#

#
# GitHub Actions packaging notes:
#
# - Run build.sh without parameters to see its usage
# - Any boolean CMake definitions (-D ...=ON/OFF) must be ON or OFF to ensure correct behavior
# - For Windows (MSYS MinGW) builds:
#   - Packaging requires 7-Zip on Program Files
#   - Packaging the Ghostscript DLL requires 32-bit and/or 64-bit Ghostscript on Program Files
# - For Linux builds:
#   - Only Debian and derivatives are supported
#   - dpkg and apt-get are called through sudo to manage dependencies; make sure those
#     are configured as NOPASSWD in /etc/sudoers if you're doing unattended builds
#

# Define common functions.
alias is_windows='[ -n "$MSYSTEM" ]'

make_tar() {
	# Install dependencies.
	if ! which tar xz > /dev/null 2>&1
	then
		if which apt-get > /dev/null 2>&1
		then
			sudo apt-get update
			DEBIAN_FRONTEND=noninteractive sudo apt-get install -y tar xz-utils
			sudo apt-get clean
		fi
	fi

	local tar_cmd=tar

	# Determine the best supported compression type.
	local compression_flag=
	local compression_ext=
	if which xz > /dev/null 2>&1
	then
		local compression_flag=-J
		local compression_ext=.xz
	elif which bzip2 > /dev/null 2>&1
	then
		local compression_flag=-j
		local compression_ext=.bz2
	elif which gzip > /dev/null 2>&1
	then
		local compression_flag=-z
		local compression_ext=.gz
	fi

	# Make tar verbose if requested.
	[ -n "$VERBOSE" ] && local compression_flag="$compression_flag -v"

	# tar is notorious for having many diverging implementations. For instance,
	# the flags we use to strip UID/GID metadata can be --owner/group (GNU),
	# --uid/gid (bsdtar) or even none at all (MSYS2 bsdtar). Account for such
	# flag differences by checking if they're mentioned on the help text.
	local ownership_flags=
	local tar_help=$("$tar_cmd" --help 2>&1)
	if echo $tar_help | grep -q -- --owner
	then
		local ownership_flags="--owner=0 --group=0"
	elif echo $tar_help | grep -q -- --uid
	then
		local ownership_flags="--uid 0 --gid 0"
	fi

	# Run tar.
	"$tar_cmd" -c $compression_flag -f "$1$compression_ext" $ownership_flags *
	return $?
}

# Download and extract sources separately, retrying incomplete transfers and
# keeping partially extracted sources out of the build cache.
download_source() {
	local url="$1"
	local source_dir="$2"
	local source_name=$(basename "$source_dir")
	local retry tmp_dir
	for retry in 0 5 10 20 40
	do
		sleep $retry
		tmp_dir=$(mktemp -d "$cache_dir/source.XXXXXX") || return 1
		echo "[-] Downloading sources from [$url]"
		if curl --fail --location --silent --show-error --connect-timeout 15 --max-time 120 \
			--output "$tmp_dir/source.tar.gz" "$url" &&
			tar zxf "$tmp_dir/source.tar.gz" -C "$tmp_dir" &&
			[ -d "$tmp_dir/$source_name" ] &&
			mv "$tmp_dir/$source_name" "$source_dir"
		then
			rm -rf "$tmp_dir"
			return 0
		fi
		rm -rf "$tmp_dir"
	done
	echo "[!] Source download or extraction failed for [$url]" >&2
	return 1
}

cache_dir="$HOME/86box-build-cache"
[ ! -d "$cache_dir" ] && mkdir -p "$cache_dir"
check_buildtag() {
	[ -z "$BUILD_TAG" -o "$BUILD_TAG" != "$(cat "$cache_dir/buildtag.$1" 2> /dev/null)" ]
	return $?
}
save_buildtag() {
	[ -n "$2" ] && local contents="$2" || local contents="$BUILD_TAG"
	echo "$contents" > "$cache_dir/buildtag.$1"
	return $?
}

# Set common variables.
project=PCBox
cwd=$(pwd)

# Parse arguments.
package_name=
arch=
tarball_name=
skip_archive=0
dep_report=0
strip=0
cmake_flags=
while [ $# -gt 0 ]
do
	case $1 in
		-b)
			shift
			package_name="$1"
			shift
			arch="$1"
			shift
			;;

		-n)
			shift
			skip_archive=1
			;;

		-p)
			shift

			# Check for lddtree and install it if required.
			which lddtree > /dev/null || DEBIAN_FRONTEND=noninteractive sudo apt-get -y install pax-utils

			# Handle AppImages.
			if echo "$1" | grep -q "://"
			then
				if ! wget -O treetemp.AppImage "$1" || ! chmod +x treetemp.AppImage
				then
					rm -f treetemp.AppImage
					exit 1
				fi
				set -- treetemp.AppImage
			fi
			case "$1" in
				*.AppImage)
					# Extract AppImage.
					rm -rf squashfs-root
					"./$1" --appimage-extract
					appdir=squashfs-root
					binary=
					;;

				*)
					appdir=archive_tmp
					binary="$1"
					;;
			esac
			[ -z "$binary" ] && binary="$appdir/usr/local/bin/$project" # default to main binary

			# Run lddtree with AppImage lib directories included in the search path.
			LD_LIBRARY_PATH=$(find "$(readlink -f "$appdir")" -type d -name lib -o -name lib64 | while read dir; do find "$dir" -type d; done | tr '\n' ':') \
				lddtree "$binary"
			status=$?
			[ $appdir = "squashfs-root" ] && rm -rf treetemp.AppImage squashfs-root
			exit $status
			;;

		-s)
			shift
			tarball_name="$1"
			shift
			;;

		-t)
			shift
			strip=1
			;;

		*)
			# Consume remaining arguments as CMake flags.
			while [ $# -gt 0 ]
			do
				if echo $1 | grep -q " "
				then
					cmake_flag="\"$1\""
				else
					cmake_flag="$1"
				fi
				if [ -z "$cmake_flags" ]
				then
					cmake_flags="$cmake_flag"
				else
					cmake_flags="$cmake_flags $cmake_flag"
				fi
				shift
			done
			;;
	esac
done
cmake_flags_extra=

# Check if mandatory arguments were specified.
if [ -z "$package_name" -a -z "$tarball_name" ] || [ -n "$package_name" -a -z "$arch" ]
then
	echo '[!] Usage: build.sh -b {package_name} {architecture} [-t] [cmake_flags...]'
	echo '           build.sh -s {source_tarball_name} [-t]'
	echo 'Dep. tree: build.sh -p [archive_tmp/path/to/binary]'
	exit 100
fi

# Switch to the repository root directory.
cd "$(dirname "$0")/.."

# Make source tarball if requested.
if [ -n "$tarball_name" ]
then
	echo [-] Making source tarball [$tarball_name]

	# Clean local tree of gitignored files.
	git clean -dfX

	# Recreate working directory if it was removed by git clean.
	[ ! -d "$cwd" ] && mkdir -p "$cwd"

	# Save current HEAD commit to VERSION.
	if [ $strip -eq 0 ]
	then
		git log --stat -1 > VERSION || rm -f VERSION
	fi

	# Archive source.
	make_tar "$cwd/$tarball_name.tar"
	status=$?

	# Check if the archival succeeded.
	if [ $status -ne 0 ]
	then
		echo [!] Tarball creation failed with status [$status]
		exit 1
	else
		echo [-] Source tarball [$tarball_name] created successfully
		[ -z "$package_name" ] && exit 0
	fi
fi

echo [-] Building [$package_name] for [$arch] with flags [$cmake_flags]

# Perform platform-specific setup.
cc_binary=gcc
strip_binary=strip
if is_windows
then
	# Switch into the correct MSYSTEM if required.
	msys=UCRT$arch
	[ ! -d "/$msys" ] && msys=MINGW$arch
	[ ! -d "/$msys" ] && msys=CLANG$arch
	if [ -d "/$msys" ]
	then
		if [ "$MSYSTEM" != "$msys" ]
		then
			# Call build with the correct MSYSTEM.
			echo [-] Switching to MSYSTEM [$msys]
			cd "$cwd"
			args=
			[ $strip -ne 0 ] && args="-t $args"
			[ $skip_archive -ne 0 ] && args="-n $args"
			CHERE_INVOKING=yes MSYSTEM="$msys" bash -lc 'exec "'"$0"'" -b "'"$package_name"'" "'"$arch"'" '"$args""$cmake_flags"
			exit $?
		fi
	else
		echo [!] No MSYSTEM for architecture [$arch]
		exit 2
	fi
	echo [-] Using MSYSTEM [$MSYSTEM]

	# Install dependencies only if we're in a new build and/or architecture.
	if check_buildtag "$MSYSTEM"
	then
		# Update databases and keyring only if we're in a new build.
		if check_buildtag pacmansync
		then
			# Update keyring as well, since the package signing keys sometimes change.
			echo [-] Updating package databases and keyring
			pacman -Sy --needed --noconfirm msys2-keyring

			# Save build tag to skip pacman sync/keyring later.
			save_buildtag pacmansync
		else
			echo [-] Not updating package databases and keyring again
		fi

		# Establish general dependencies.
		pkgs="git make"

		# Gather installed architecture-specific packages for updating.
		# This prevents outdated shared libraries, unmet dependencies
		# and potentially other issues caused by the fact pacman doesn't
		# update a package's dependencies unless explicitly told to.
		pkgs="$pkgs $(pacman -Quq | grep -E "^$MINGW_PACKAGE_PREFIX-")"

		# Establish architecture-specific dependencies.
		while read pkg rest
		do
			pkgs="$pkgs $MINGW_PACKAGE_PREFIX-$(echo "$pkg" | tr -d '\r')" # CR removal required
		done < .ci/dependencies_msys.txt

		# Install or update dependencies.
		echo [-] Installing dependencies through pacman
		if ! pacman -S --needed --noconfirm $pkgs
		then
			# Install packages individually if installing them all together failed.
			for pkg in $pkgs
			do
				pacman -S --needed --noconfirm "$pkg"
			done
		fi

		# Clean pacman cache when running under Jenkins to save disk space.
		[ "$CI" = "true" ] && rm -rf /var/cache/pacman/pkg

		# Save build tag to skip this later. Doing it here (once everything is
		# in place) is important to avoid potential issues with retried builds.
		save_buildtag "$MSYSTEM"
	else
		echo [-] Not installing dependencies again
	fi
else
	# Determine Debian architecture.
	case $arch in
		x86_64)	arch_deb="amd64";;
		*)	arch_deb="$arch";;
	esac

	# Establish general dependencies.
	pkgs="cmake ninja-build pkg-config git wget p7zip-full wayland-protocols tar gzip file appstream qt6-translations-l10n python3-pip python3-venv squashfs-tools curl patchelf"
	if [ "$(dpkg --print-architecture)" = "$arch_deb" ]
	then
		pkgs="$pkgs build-essential"
	else
		# Add foreign architecture if required.
		if ! dpkg --print-foreign-architectures | grep -Fqx "$arch_deb"
		then
			sudo dpkg --add-architecture "$arch_deb"

			# Force an apt-get update.
			save_buildtag aptupdate "arch_$arch_deb"
		fi

		pkgs="$pkgs crossbuild-essential-$arch_deb"
	fi

	# Establish architecture-specific dependencies we don't want listed on the readme...
	pkgs="$pkgs linux-libc-dev:$arch_deb qt6-tools-dev:$arch_deb qt6-base-private-dev:$arch_deb"

	# ...and the ones we do want listed. Non-dev packages fill missing spots on the list.
	libpkgs=""
	longest_libpkg=0
	for pkg in libc6-dev libstdc++6 libopenal-dev libfreetype-dev libx11-dev libsdl3-dev libpng-dev librtmidi-dev qt6-declarative-dev libwayland-dev libevdev-dev libxkbcommon-x11-dev libglib2.0-dev libslirp-dev libaudio-dev libjack-jackd2-dev libpipewire-0.3-dev libsamplerate0-dev libsndio-dev libvdeplug-dev libfluidsynth-dev libsndfile1-dev libserialport-dev libvncserver-dev libzstd-dev libarchive-dev
	do
		libpkgs="$libpkgs $pkg:$arch_deb"
		length=$(echo -n $pkg | sed 's/-dev$//' | sed "s/-declarative$//" | wc -c)
		[ $length -gt $longest_libpkg ] && longest_libpkg=$length
	done

	# Determine toolchain architecture triplet.
	case $arch in
		*)	arch_triplet="$arch-linux-gnu";;
	esac

	# Determine library directory name for this architecture.
	case $arch in
		*)	libdir="$arch_triplet";;
	esac

	# Create CMake cross toolchain file.
	toolchain_file="$cache_dir/toolchain.$arch_deb.cmake"
	cat << EOF > "$toolchain_file"
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR $arch)

set(CMAKE_AR $arch_triplet-ar)
set(CMAKE_ASM_COMPILER $arch_triplet-gcc)
set(CMAKE_C_COMPILER $arch_triplet-gcc)
set(CMAKE_CXX_COMPILER $arch_triplet-g++)
set(CMAKE_LINKER $arch_triplet-ld)
set(CMAKE_OBJCOPY $arch_triplet-objcopy)
set(CMAKE_RANLIB $arch_triplet-ranlib)
set(CMAKE_SIZE $arch_triplet-size)
set(CMAKE_STRIP $arch_triplet-strip)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_LIBDIR} "/usr/lib/$libdir/pkgconfig:/usr/share/$libdir/pkgconfig:/usr/share/pkgconfig")
EOF
	cc_binary="$arch_triplet-gcc"
	strip_binary="$arch_triplet-strip"

	# Install dependencies only if we're in a new build and/or architecture.
	if check_buildtag "$arch_deb"
	then
		# Install or update dependencies.
		echo [-] Installing dependencies through apt
		if check_buildtag aptupdate
		then
			sudo apt-get update

			# Save build tag to skip apt-get update later, unless a new architecture
			# is added to dpkg, in which case, this saved tag file gets replaced.
			save_buildtag aptupdate
		fi
		DEBIAN_FRONTEND=noninteractive sudo apt-get -y install $pkgs $libpkgs
		sudo apt-get clean

		# Save build tag to skip this later. Doing it here (once everything is
		# in place) is important to avoid potential issues with retried builds.
		save_buildtag "$arch_deb"
	else
		echo [-] Not installing dependencies again
	fi

	# Enable Qt 6.
	cmake_flags_extra="$cmake_flags_extra -D USE_QT6=ON"

	# Set up the Rust environment.
	[ ! -x "$HOME/.cargo/bin/cargo" ] && curl -sSf https://sh.rustup.rs | sh -s -- -y
	export PATH="$HOME/.cargo/bin:$PATH"
fi

# Set build thread count.
build_threads=$(cat ~/86box-build-threads.txt 2> /dev/null)
[ -z "$build_threads" ] && build_threads=$(nproc)

# Build librashader library.
prefix="$cache_dir/librashader"
if [ ! -d "$prefix/.git" ]
then
	mkdir -p "$prefix"
	git -C "$prefix" init
	git -C "$prefix" remote add origin https://github.com/SnowflakePowered/librashader.git
	git -C "$prefix" fetch origin --depth=1 f810cdf6e856e5a5215b1e84a21c978bc3367f23
	git -C "$prefix" checkout f810cdf6e856e5a5215b1e84a21c978bc3367f23
fi
case $arch in
	64)		arch_rust="x86_64";;
	*)		arch_rust="$arch";;
esac
if is_windows
then
	arch_rust="$arch_rust-pc-windows-gnu"
	case $MSYSTEM in
		CLANG*)	arch_rust="${arch_rust}llvm";;
	esac
else
	arch_rust="$arch_rust-unknown-linux-gnu"
	rustup target add "$arch_rust"
	export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
fi
(cd "$prefix" && cargo build -j $build_threads -p librashader-capi --target "$arch_rust" --profile release --no-default-features --features runtime-vulkan) || exit 99
librashader_target="$prefix/target/$arch_rust/release"
if is_windows
then
	export CMAKE_LIBRARY_PATH="$librashader_target"
	cmake_flags_extra="$cmake_flags_extra -D LIBRASHADER_STATIC=ON -D LIBRASHADER_STATIC_FIND_LIB=ON"
fi

# Point CMake at the toolchain file.
[ -e "$toolchain_file" ] && cmake_flags_extra="$cmake_flags_extra -D \"CMAKE_TOOLCHAIN_FILE=$toolchain_file\""

# Clean workspace.
echo [-] Cleaning workspace
rm -rf build

# Add ARCH to skip the arch_detect process.
case $arch in
	64)	cmake_flags_extra="$cmake_flags_extra -D ARCH=x86_64";;
	*)	cmake_flags_extra="$cmake_flags_extra -D \"ARCH=$arch\"";;
esac

# Add git hash.
git_hash=$(git rev-parse --short HEAD 2> /dev/null)
if [ "$CI" = "true" ]
then
	# Backup strategy when running under Jenkins.
	[ -z "$git_hash" ] && git_hash=$(echo $GIT_COMMIT | cut -c 1-8)
elif [ -n "$git_hash" ]
then
	# Append + to denote a dirty tree.
	git diff --quiet 2> /dev/null || git_hash="$git_hash+"
fi
[ -n "$git_hash" ] && cmake_flags_extra="$cmake_flags_extra -D \"EMU_GIT_HASH=$git_hash\""

# Add copyright year.
year=$(date +%Y)
[ -n "$year" ] && cmake_flags_extra="$cmake_flags_extra -D \"EMU_COPYRIGHT_YEAR=$year\""

# Run CMake.
echo [-] Running CMake with flags [$cmake_flags $cmake_flags_extra]
eval cmake -G Ninja $cmake_flags $cmake_flags_extra -S . -B build
status=$?
if [ $status -ne 0 ]
then
	echo [!] CMake failed with status [$status]
	exit 3
fi

# Run actual build, unless we're running a dry build to precondition a node.
if [ "$BUILD_TAG" != "precondition" ]
then
	echo [-] Running build
	cmake --build build -j $build_threads
	status=$?
	if [ $status -ne 0 ]
	then
		echo [!] Build failed with status [$status]
		exit 4
	fi
else
	# Copy dummy binary into place.
	echo [-] Preconditioning build node
	mkdir -p build/src
	if is_windows
	then
		cp "$(which cp)" "build/src/$project.exe"
	else
		cp "$(which cp)" "build/src/$project"
	fi
fi
grep -qiE "^CMAKE_BUILD_TYPE:[^=]+=.*Debug.*" build/CMakeCache.txt && cmake_build_type=Debug || cmake_build_type=Release

# Determine architecture name for self-built library build directories.
case $arch in
	64)		arch_build="x86_64";;
	*)		arch_build="$arch";;
esac

# Create temporary directory for archival.
echo [-] Gathering archive files
rm -rf archive_tmp
mkdir archive_tmp
if [ ! -d "archive_tmp" ]
then
	echo [!] Archive directory creation failed
	exit 5
fi

# Download assets if we're making a release build.
git_repo=$(git remote get-url origin 2> /dev/null)
if [ "$CI" = "true" ]
then
	# Backup strategy when running under Jenkins.
	[ -z "$git_repo" ] && git_repo=$GIT_URL
fi
if grep -qiE "^BUILD_TYPE:[^=]+=release" build/CMakeCache.txt 2> /dev/null
then
	if [ -n "$git_repo" ]
	then
		echo [-] Downloading assets
		cd archive_tmp
		if ! git clone --depth 1 "$(dirname "$git_repo")/assets.git" assets
		then
			echo [!] Assets download failed
			exit 7
		fi
		# Remove dot directories (including .git) and top level files.
		rm -rf assets/.* 2> /dev/null
		rm -f assets/* 2> /dev/null
		cd ..
	fi
fi

# Build mdsx library.
prefix="$cache_dir/mdsx"
if [ -e "$prefix/src/Makefile" ]
then
	if ! check_buildtag mdsx
	then
		git -C "$prefix" clean -dfx
		git -C "$prefix" reset --hard HEAD
		for retry in 0 5 10 20 40
		do
			sleep $retry
			git -C "$prefix" pull && break
		done
		save_buildtag mdsx
	fi
else
	rm -rf "$prefix"
	for retry in 0 5 10 20 40
	do
		sleep $retry
		git clone --depth 1 "$(dirname "$git_repo")/mdsx.git" "$prefix" && break
	done
fi
[ "$cmake_build_type" = "Debug" ] && debug_args=DEBUG=y || debug_args=
make -C "$prefix/src" -j $build_threads CC="$cc_binary" STRIP="$strip_binary" $debug_args || exit 99
find "$prefix/src" -name '*.[oa]' -delete
mv "$prefix/src/mdsx."* archive_tmp/ || exit 99

# Build libaaruformat library.
prefix="$cache_dir/libaaruformat"
if [ -e "$prefix/src/close.c" ]
then
	if ! check_buildtag libaaruformat
	then
		git -C "$prefix" clean -dfx
		git -C "$prefix" reset --recurse-submodules --hard HEAD
		for retry in 0 5 10 20 40
		do
			sleep $retry
			git -C "$prefix" pull && break
		done
		save_buildtag libaaruformat
	fi
else
	rm -rf "$prefix"
	for retry in 0 5 10 20 40
	do
		sleep $retry
		git clone --recurse-submodules --no-shallow-submodules --remote-submodules https://github.com/aaru-dps/libaaruformat.git "$prefix" && break
	done
fi
prefix_build="$prefix/build-$arch_build"
cmake -G Ninja -D AARU_BUILD_PACKAGE=ON -D "CMAKE_BUILD_TYPE=$cmake_build_type" \
	-D "CMAKE_TOOLCHAIN_FILE=$toolchain_file" -B "$prefix_build" -S "$prefix" || exit 99
cmake --build "$prefix_build" -j $build_threads || exit 99
find "$prefix_build" -name '*.[oa]' -delete
cp "$prefix_build/libaaruformat."* archive_tmp/ || exit 99

# Archive librashader library built earlier if applicable.
if ! is_windows
then
	src=$(echo "$librashader_target/liblibrashader_capi."??*)
	cp "$src" "archive_tmp/librashader.${src##*.}" || exit 99
fi

# Archive the executable and its dependencies.
# The executable should always be archived last for the check after this block.
status=0
if is_windows
then
	# Determine Program Files directory for Ghostscript and 7-Zip.
	# Manual checks because MSYS is bad at passing the ProgramFiles variables.
	pf="/c/Program Files"
	sevenzip="$pf/7-Zip/7z.exe"
	[ "$arch" = "32" -a -d "/c/Program Files (x86)" ] && pf="/c/Program Files (x86)"

	# Archive Ghostscript DLL from local official distribution installation.
	rm -rf "$cache_dir/appimage-builder-"* # remove old versions
	python3 -m venv "$appimage_builder_dir" # venv to solve some Debian setuptools headaches
	"$appimage_builder_dir/bin/pip" install -U "git+https://github.com/AppImageCrafters/appimage-builder.git@$appimage_builder_commit" 'setuptools<81'

	# Symlink appimage-builder global cache directory.
	rm -rf appimage-builder.AppImage appimage-builder-cache "$project-"*".AppImage" # also remove any dangling AppImages which may interfere with the renaming process
	mkdir -p "$cache_dir/appimage-builder-cache"
	ln -s "$cache_dir/appimage-builder-cache" appimage-builder-cache

	# Work around appimage-builder issue in newer Debian.
	touch "$HOME/.cargo/bin/apt-key"
	chmod +x "$HOME/.cargo/bin/apt-key"

	# Run appimage-builder from the virtual environment created above.
	# --appdir is a workaround for appimage-builder issue 270 reported by us.
	for retry in 1 2 3 4 5
	do
		project="$project" project_id="$project_id" project_version="$project_version" project_icon="$project_icon" libdir="$libdir" arch_deb="$arch_deb" \
			arch_appimage="$arch_appimage" appimage_path="$cwd/$package_name.AppImage" "$appimage_builder_dir/bin/appimage-builder" \
			--recipe AppImageBuilder-generated.yml --appdir "$(grep -oP '^\s+path: \K(.+)' AppImageBuilder-generated.yml)"
		status=$?
		[ $status -eq 0 ] && break
	done

	# Remove appimage-builder binary on failure, just in case it's corrupted.
	[ $status -ne 0 ] && rm -f "$appimage_builder_binary"
fi

# Check if the archival succeeded.
if [ $status -ne 0 ]
then
	echo [!] Artifact archive creation failed with status [$status]
	exit 7
fi

# All good.
echo [-] Build of [$package_name] for [$arch] with flags [$cmake_flags] successful
exit $status
