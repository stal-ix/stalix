<picture>
<source media="(prefers-color-scheme: dark)" srcset="https://github.com/stal-ix/stal-ix.github.io/blob/main/images/stalix_dark.png" width="250px" height="100px">
<source media="(prefers-color-scheme: light)" srcset="https://github.com/stal-ix/stal-ix.github.io/blob/main/images/stalix_light.png" width="250px" height="100px">
<img alt="logo" src="https://raw.githubusercontent.com/adouche/stal-ix.github.io/main/images/stalix_light.png" width="250px" height="100px">
</picture>

<br>
<br>

STAtically LInked LInuX, based on IX package manager

# Download the latest release of stal/IX <!--GAMFC-->[here](https://github.com/stal-ix/stalix/releases/tag/20251212)<!--GAMFC-END-->

This repository hosts stal/IX rootfs tarballs for x86_64, built weekly using a GitHub Actions workflow ([update-rootfs.yml](.github/workflows/update-rootfs.yml)).

Also in this repository are a few scripts for working with stal/IX rootfs tarballs:
* **build-rootfs.sh** - builds a stal/IX rootfs tarball compressed using XZ from scratch, using a 2-stage process. Requires `bwrap`, `clang`, `clang++`, `clang-cpp`, `git`, `lld`, `llvm-ar`, `llvm-nm`, `llvm-ranlib`, `make`, `python3`, `su`, `tar`, `useradd`, `userdel`, and `xz`. Cross-compilation is not supported at this time.
* **update-rootfs.sh** - updates an existing stal/IX rootfs tarball to the most recent commit in the [stable branch of IX](https://github.com/stal-ix/ix). Requires `bwrap`, `tar`, and `xz`.
* **update-rootfs-gha-part1.sh** and **update-rootfs-gha-part2.sh** - intended for use on GitHub Actions only, due to time limitations. Do not use these scripts on a regular Linux system.
