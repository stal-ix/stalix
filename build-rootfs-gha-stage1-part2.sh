#!/bin/bash
# shellcheck disable=SC2016

# build-rootfs-gha-stage1-part2.sh
# Created by Earldridge Jazzed Pineda

# Check for superuser privileges
if [ "$(id -u)" != 0 ]; then
    echo "Script must be run with superuser privileges"
    exit 1
fi

# Check for required commands
for command in clang clang++ clang-cpp lld llvm-ar llvm-nm llvm-ranlib make python3 su tar useradd userdel usermod xz; do
    command -v $command > /dev/null || missing_commands+=" $command"
done
if [ -n "$missing_commands" ]; then
    echo "The following commands are required but are not installed:"
    for command in $missing_commands; do
        echo "$command"
    done
    exit 1
fi

# Check for rootfs tarball path in the arguments
if [ -z "$1" ]; then
    echo "Path to a stal/IX rootfs tarball must be provided"
    exit 1
fi

if [ ! -e "$1" ]; then
    echo "$1 does not exist"
    exit 1
fi

# Prepare rootfs directory
mkdir stalix
tar -xpvJf "$1" -C stalix
cd stalix || { echo "Failed to cd to rootfs directory"; exit 1; }

# Add a user "ix" who will own all packages in the system (note: UID 1000 is important)
useradd -ou 1000 ix
usermod -a -G docker ix

# Change the user to ix and run all commands under ix user
su ix -c '

# Set the IX root variable
export IX_ROOT=$PWD/ix

# And run IX package manager to populate the root fs with bootstrap tools
cd home/ix/ix
export IX_EXEC_KIND=local
./ix mut root set/install || { echo "Failed to bootstrap root realm"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
./ix mut boot set/boot/all || { echo "Failed to bootstrap boot realm"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
' || exit 1

# Build rootfs tarball
cd ..
# Cross-compilation is not supported by this script at this time
tarball_name=stalix-$(uname -m)-$(date +%Y%m%d)-stage1.tar.xz
tar -cvJf "$tarball_name" -C stalix .

# Cleanup
userdel -rf ix
unlink stalix/usr
rm -rf stalix

echo "Successfully built stal/IX stage 1 rootfs tarball at $PWD/$tarball_name"
