#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
PACKAGE_NAME="com.glorystore.keycheck"
VERSION="1.0.0"
ARCH="iphoneos-arm"

echo "=== GloryStore KeyCheck Builder ==="
echo ""

mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/lib"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/etc/keycheck"

echo "[1/4] Building library..."
cd "$PROJECT_DIR/src/libkeycheck"
make clean 2>/dev/null || true
make
make install DESTDIR="$BUILD_DIR"
cd "$PROJECT_DIR"

echo "[2/4] Copying control files..."
cp "$PROJECT_DIR/DEBIAN/control" "$BUILD_DIR/DEBIAN/"
cp "$PROJECT_DIR/DEBIAN/postinst" "$BUILD_DIR/DEBIAN/"
cp "$PROJECT_DIR/DEBIAN/prerm" "$BUILD_DIR/DEBIAN/"
chmod 755 "$BUILD_DIR/DEBIAN/postinst"
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

echo "[3/4] Copying scripts..."
cp "$PROJECT_DIR/scripts/keycheck.sh" "$BUILD_DIR/usr/bin/keycheck-wrapper"
chmod 755 "$BUILD_DIR/usr/bin/keycheck-wrapper"

echo "[4/4] Building DEB package..."
cd "$BUILD_DIR"
dpkg-deb --build . "$PROJECT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
cd "$PROJECT_DIR"

echo ""
echo "=== Build Complete ==="
echo "Package: ${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
ls -lh "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
echo ""

rm -rf "$BUILD_DIR"
