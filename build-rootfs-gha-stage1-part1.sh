#!/bin/bash
# shellcheck disable=SC2016

# build-rootfs-gha-stage1-part1.sh
# Created by Earldridge Jazzed Pineda

# Check for superuser privileges
if [ "$(id -u)" != 0 ]; then
    echo "Script must be run with superuser privileges"
    exit 1
fi

# Check for required commands
for command in clang clang++ clang-cpp git lld llvm-ar llvm-nm llvm-ranlib make python3 su tar useradd userdel usermod xz; do
    command -v $command > /dev/null || missing_commands+=" $command"
done
if [ -n "$missing_commands" ]; then
    echo "The following commands are required but are not installed:"
    for command in $missing_commands; do
        echo "$command"
    done
    exit 1
fi

# Prepare rootfs directory
mkdir stalix 
cd stalix || { echo "Failed to cd to rootfs directory"; exit 1; }
    
# Prepare some symlinks to form the future rootfs
ln -s ix/realm/system/bin bin
ln -s ix/realm/system/etc etc
ln -s / usr

mkdir -p home/root var sys proc dev

# Add a user "ix" who will own all packages in the system (note: UID 1000 is important)
useradd -ou 1000 ix
usermod -a -G docker ix

# Prepare a managed dir owned by user ix, in /ix, /ix/realm, etc
mkdir ix
chown ix ix

# Prepare the ix user home owned by ix
mkdir home/ix
chown ix home/ix

# Change the user to ix and run all commands under ix user
su ix -c '

# Fetch IX package manager, will be used later, from ix user before reboot and by root after reboot
# we do not want to change our CWD
(cd home/ix; git clone https://github.com/pg83/ix.git)

# Some quirks:
# like tmp dir, so realm symlink can be modified only by its creator/owner
# it is important who create/own system realm, because only they can operate it
# sudo chown {{username}} /ix/realm/system will help, iff one wants to transfer ownership
mkdir -m 01777 ix/realm

# Set the IX root variable
export IX_ROOT=$PWD/ix

# And run IX package manager to populate the root fs with bootstrap tools
cd home/ix/ix
export IX_EXEC_KIND=local
./ix mut system set/stalix --failsafe --mingetty etc/zram/0 || { echo "Failed to bootstrap system realm"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
' || exit 1

# Build rootfs tarball
cd ..
# Cross-compilation is not supported by this script at this time
tarball_name=stalix-$(uname -m)-$(date +%Y%m%d)-stage1-part1.tar.xz
tar -cvJf "$tarball_name" -C stalix .

# Cleanup
userdel -rf ix
unlink stalix/usr
rm -rf stalix

echo "Successfully built stal/IX stage 1 (part 1) rootfs tarball at $PWD/$tarball_name"
