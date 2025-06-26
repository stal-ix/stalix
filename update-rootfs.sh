#!/bin/bash
# shellcheck disable=SC2016

# update-rootfs.sh
# Created by Earldridge Jazzed Pineda

# Check for superuser privileges
if [ "$(id -u)" != 0 ]; then
    echo "Script must be run with superuser privileges"
    exit 1
fi

# Check for required commands
for command in bwrap tar xz; do
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

# Change to stal/IX root
bwrap --bind . / --dev /dev --ro-bind /etc/resolv.conf /var/run/resolvconf/resolv.conf --perms 1777 --tmpfs /dev/shm --setenv HOME /home/root bash -c '

# Manually mount procfs at /proc
mount -t proc proc /proc

# Temporarily patch the jail script
sed -i -e '\''32icp /etc/resolv.conf etc/'\'' /bin/jail

# Set some variables
source /etc/profile
source /etc/env

cd /home/ix/ix
# Update the IX repository
git pull

# Update the world
./ix mut $(./ix list) || { echo "Failed to update the world"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*

# Regenerate the random seed
./ix mut system --seed="stal/IX" || { echo "Failed to regenerate random seed"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*

# Remove duplicate and unneeded packages
./ix gc
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
' || exit 1

# Build rootfs tarball
cd ..
# Cross-compilation is not supported by this script at this time
tarball_name=stalix-$(uname -m)-$(date +%Y%m%d).tar.xz
tar -cvJf "$tarball_name" -C stalix .

# Cleanup
unlink stalix/usr
rm -rf stalix

echo "Successfully updated stal/IX rootfs tarball at $PWD/$tarball_name"
