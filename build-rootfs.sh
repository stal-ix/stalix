#!/bin/bash
# shellcheck disable=SC2016

# build-rootfs.sh
# Created by Earldridge Jazzed Pineda

# Check for command-line options
help() {
    echo "Usage: $0 [option...]
    
Options:
-g Enable fix for GitHub Actions
-h Show this help message"
}

while getopts gh opt; do
    case $opt in
        g) gha_fix=1;;
        h) help; exit;;
        ?) help; exit 1;;
    esac
done

# Check for superuser privileges
if [ "$(id -u)" != 0 ]; then
    echo "Script must be run with superuser privileges"
    exit 1
fi

# Check for required commands
for command in bwrap clang clang++ clang-cpp git lld llvm-ar llvm-nm llvm-ranlib python3 su tar useradd userdel xz; do
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
    
if [ ! -e .stage1 ]; then
    echo "Running stage 1"
    
    # Prepare some symlinks to form the future rootfs
    ln -s ix/realm/system/bin bin
    ln -s ix/realm/system/etc etc
    ln -s / usr

    mkdir -p home/root var sys proc dev

    # Add a user "ix" who will own all packages in the system (note: UID 1000 is important)
    useradd -ou 1000 ix
    if [ -n "$gha_fix" ]; then
        usermod -a -G docker ix
    fi

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
    (cd home/ix; git clone https://github.com/stal-ix/ix.git)

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
    ./ix mut root set/install || { echo "Failed to bootstrap root realm"; exit 1; }
    ./ix gc lnk url
    chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
    ./ix mut boot set/boot/all || { echo "Failed to bootstrap boot realm"; exit 1; }
    ./ix gc lnk url
    chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
    ' || exit 1

    touch .stage1
    echo "Stage 1 is complete"
    echo "To restart stage 1, remove $PWD/.stage1"
fi

echo "Running stage 2"

# Fix broken symbolic links
mkdir -p "${PWD#/}"
ln -s /ix "${PWD#/}"/ix

# Allow read access to resolv.conf as UID 1000
mkdir -p var/run/resolvconf

# Change to stal/IX root
bwrap --bind . / --dev /dev --ro-bind /etc/resolv.conf /var/run/resolvconf/resolv.conf --perms 1777 --tmpfs /dev/shm bash -c '

# Manually mount procfs at /proc
mount -t proc proc /proc

# Temporarily patch the jail script
sed -i -e '\''8imkdir -p ${where}'"$PWD"\'' -e '\''8iln -s /ix ${where}'"$PWD"'/ix'\'' -e '\''32icp /etc/resolv.conf etc/'\'' /bin/jail

# Set some variables
export IX_ROOT=/ix
export IX_EXEC_KIND=system

cd /home/ix/ix
# very important step, rebuild system realm
./ix mut system || { echo "Failed to rebuild system realm"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*

# Rebuild the world
./ix mut $(./ix list) || { echo "Failed to rebuild the world"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*

# Add some uniqueness into system, without this some packages refuse to install
./ix mut system --seed="$(cat /dev/random | head -c 1000 | base64)" || { echo "Failed to add random seed"; exit 1; }
./ix gc lnk url
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*

# Remove duplicate and unneeded packages
./ix gc
chmod u+w -R $IX_ROOT/build/* $IX_ROOT/trash/*; rm -rf $IX_ROOT/build/* $IX_ROOT/trash/*
' || exit 1

echo "Stage 2 is complete"

# Cleanup rootfs
unlink "${PWD#/}"/ix
rmdir -p "${PWD#/}"
rm -f .stage1

# Build rootfs tarball
cd ..
# Cross-compilation is not supported by this script at this time
tarball_name=stalix-$(uname -m)-$(date +%Y%m%d).tar.xz
tar -cvJf "$tarball_name" -C stalix .

# Cleanup
userdel -rf ix
unlink stalix/usr
rm -rf stalix

echo "Successfully built stal/IX rootfs tarball at $PWD/$tarball_name"
