#!/bin/bash

# --- Ayarlar ---
# Neutron Clang'in tam yolu
TC_DIR="/home/solleo/neutron-clang"

# PATH'e ekliyoruz. Bin klasorunun varligini kontrol ediyoruz.
if [ -d "$TC_DIR/bin" ]; then
    export PATH="$TC_DIR/bin:$PATH"
else
    echo "HATA: Neutron Clang belirtilen dizinde bulunamadi: $TC_DIR/bin"
    exit 1
fi

unset ARCH
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="solleo"
export KBUILD_BUILD_HOST="kernel-build"
export KBUILD_VERBOSE=0

echo "Cleaning previous build..."
make O=out clean > /dev/null 2>&1

echo "----------------------------------------------------"
echo "Architecture: $ARCH"
echo "Toolchain: Neutron Clang"
echo "Path: $TC_DIR"
echo "----------------------------------------------------"

echo "Configuring kernel..."
make O=out ARCH=arm64 vendor/sdmsteppe-perf_defconfig > /dev/null 2>&1

if [ -f arch/arm64/configs/vendor/davinci.config ]; then
    echo "Merging davinci.config..."
    scripts/kconfig/merge_config.sh -O out out/.config arch/arm64/configs/vendor/davinci.config > /dev/null 2>&1
else
    echo "Warning: davinci.config not found"
fi

# Config dosyasini optimize ediyoruz
scripts/config --file out/.config \
    --disable CONFIG_DEBUG_INFO \
    --disable CONFIG_DEBUG_INFO_DWARF4 \
    --disable CONFIG_DEBUG_INFO_DWARF5 \
    --disable CONFIG_DEBUG_INFO_BTF

make O=out ARCH=arm64 olddefconfig > /dev/null 2>&1

echo "Building kernel with $(nproc) threads..."
echo "Started at: $(date)"

# Neutron Clang genellikle LLVM araclarini kullanmayi sever.
# Eger 'make' asamasinda hata alirsan CROSS_COMPILE satirini kontrol etmelisin.

make O=out \
    ARCH=arm64 \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    Image.gz \
    -j$(nproc) \
    2>&1 | grep -v "aarch64-linux-gnu-objdump: Warning: Unrecognized form" | \
           grep -v "Warning: DIE at offset" | \
           grep -v "objdump: Warning" | \
           tee build.log

if [ -f out/arch/arm64/boot/Image.gz ]; then
    echo "========================================="
    echo "✅ KERNEL BUILD SUCCESSFUL!"
    echo "Completed at: $(date)"
    echo "========================================="
    echo "Kernel image: out/arch/arm64/boot/Image.gz"
    ls -lh out/arch/arm64/boot/Image.gz
else
    echo "========================================="
    echo "❌ BUILD FAILED!"
    echo "Check build.log for details"
    echo "========================================="
    exit 1
fi