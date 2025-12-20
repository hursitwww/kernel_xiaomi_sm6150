#!/bin/bash
# anykernel-package.sh - Otomatik AnyKernel3 paketleme script'i
# Kernel derlemesi sonrası otomatik olarak flashlanabilir zip oluşturur

echo "========================================="
echo "   AnyKernel3 Otomatik Paketleme        "
echo "========================================="

# Değişkenler
KERNEL_OUT="out/arch/arm64/boot"
AK3_DIR="AnyKernel3"
KERNEL_NAME="Sun"
VERSION="v1.0"
DATE=$(date +"%Y%m%d_%H%M")
ZIP_NAME="${KERNEL_NAME}_${VERSION}_${DATE}.zip"

# AnyKernel3 dizini kontrolü
if [ ! -d "$AK3_DIR" ]; then
    echo "AnyKernel3 dizini bulunamadı. İndiriliyor..."
    git clone https://github.com/osm0sis/AnyKernel3.git
    echo "AnyKernel3 indirildi!"
elif [ ! -f "$AK3_DIR/tools/ak3-core.sh" ]; then
    echo "AnyKernel3 tools eksik. Güncelleniyor..."
    cd $AK3_DIR
    git pull
    cd ..
fi

# Kernel image kontrolü
if [ ! -f "$KERNEL_OUT/Image.gz-dtb" ] && [ ! -f "$KERNEL_OUT/Image" ] && [ ! -f "$KERNEL_OUT/Image.gz" ]; then
    echo "❌ Hata: Kernel image bulunamadı!"
    echo "Önce kernel'i derleyin: ./build.sh"
    exit 1
fi

echo "Kernel dosyaları kontrol ediliyor..."

# Hangi kernel image var kontrol et
KERNEL_IMAGE=""
if [ -f "$KERNEL_OUT/Image.gz-dtb" ]; then
    KERNEL_IMAGE="Image.gz-dtb"
    echo "✅ Image.gz-dtb bulundu"
elif [ -f "$KERNEL_OUT/Image.gz" ]; then
    KERNEL_IMAGE="Image.gz"
    echo "✅ Image.gz bulundu"
elif [ -f "$KERNEL_OUT/Image" ]; then
    KERNEL_IMAGE="Image"
    echo "✅ Image bulundu"
fi

# AnyKernel3 dizinine geç
cd $AK3_DIR

# Eski kernel dosyalarını temizle
echo "Eski dosyalar temizleniyor..."
rm -f Image* zImage* *.dtb *.dtbo modules.order modules.builtin

# AnyKernel3 yapılandırması (anykernel.sh)
echo "AnyKernel3 yapılandırılıyor..."

cat > anykernel.sh << 'EOF'
### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
### AnyKernel setup
# global properties
properties() { '
kernel.string=Flashing Kernel ...
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=davinci
device.name2=davinciin
supported.versions=11 - 16
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties
# boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;
# boot install
dump_boot;
write_boot;
## end boot install
EOF

# Kernel image'ı kopyala
echo "Kernel image kopyalanıyor: $KERNEL_IMAGE"
cp "../$KERNEL_OUT/$KERNEL_IMAGE" .

# DTB dosyalarını kontrol et ve kopyala
DTB_COUNT=0
if [ -d "../$KERNEL_OUT/dts/qcom" ]; then
    DTB_COUNT=$(find "../$KERNEL_OUT/dts/qcom" -name "*.dtb" 2>/dev/null | wc -l)
    if [ $DTB_COUNT -gt 0 ]; then
        echo "✅ $DTB_COUNT DTB dosyası bulundu, kopyalanıyor..."
        cp "../$KERNEL_OUT/dts/qcom"/*.dtb . 2>/dev/null
    fi
fi

# DTBO dosyalarını kontrol et
DTBO_COUNT=0
if [ -f "../$KERNEL_OUT/dtbo.img" ]; then
    echo "✅ DTBO dosyası bulundu, kopyalanıyor..."
    cp "../$KERNEL_OUT/dtbo.img" .
    DTBO_COUNT=1
fi

# Modülleri kontrol et
MODULE_COUNT=0
if [ -f "../out/modules.order" ]; then
    echo "✅ Kernel modülleri bulundu, kopyalanıyor..."
    cp "../out/modules.order" . 2>/dev/null
    cp "../out/modules.builtin" . 2>/dev/null
    
    # .ko dosyalarını bul ve kopyala
    find "../out" -name "*.ko" -exec cp {} . \; 2>/dev/null
    MODULE_COUNT=$(ls *.ko 2>/dev/null | wc -l)
    
    if [ $MODULE_COUNT -gt 0 ]; then
        # anykernel.sh'da modül yüklemesini aktif et
        sed -i 's/do.modules=0/do.modules=1/g' anykernel.sh
        echo "✅ $MODULE_COUNT kernel modülü eklendi"
    fi
fi

# Zip dosyasını oluştur
echo ""
echo "Flashlanabilir zip oluşturuluyor: $ZIP_NAME"
zip -r9 "../$ZIP_NAME" . -x .git\* .gitignore\* README.md\* placeholder

cd ..

# Sonuçları göster
echo "========================================="
echo "✅ AnyKernel3 PAKETİ HAZIR!"
echo "========================================="
echo "📦 Zip dosyası: $ZIP_NAME"
echo "📱 Kernel: $KERNEL_IMAGE"
echo "🔧 DTB dosyaları: $DTB_COUNT"
echo "📋 DTBO dosyası: $([ $DTBO_COUNT -gt 0 ] && echo "Evet" || echo "Hayır")"
echo "🔌 Modüller: $MODULE_COUNT"
echo ""
echo "Flash komutu:"
echo "adb push $ZIP_NAME /sdcard/"
echo "# Recovery'de flash edin veya:"
echo "# fastboot flash boot <boot.img>"
echo ""

# Dosya boyutunu göster
ls -lh "$ZIP_NAME"

echo "✅ Kernel paketleme tamamlandı!"
