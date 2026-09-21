#!/bin/bash
set -e

REPO="Azizulakbar89/e-Learning-Final-Bos"
# Ambil token dari environment atau Keychain macOS
TOKEN="${GITHUB_TOKEN:-$(security find-internet-password -s github.com -w 2>/dev/null || true)}"

if [ -z "$TOKEN" ]; then
  echo "Error: Token GitHub tidak ditemukan. Silakan set GITHUB_TOKEN."
  exit 1
fi

TAG="v1.1.0"
VERSION="1.1.0"
BUILD_DIR="/Users/azizul/ProjectLaravel/e-Learning/build/app/outputs/flutter-apk"

echo "=== Memulai Proses Rilis GitHub $TAG ==="

# 1. Cek apakah release sudah ada
RELEASE_INFO=$(curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO/releases/tags/$TAG")

RELEASE_ID=$(echo "$RELEASE_INFO" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')

if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
  echo "Membuat Release baru $TAG di GitHub..."
  RELEASE_PAYLOAD=$(cat <<EOF
{
  "tag_name": "$TAG",
  "target_commitish": "main",
  "name": "v$VERSION - Pembaruan Fitur Chat, Notifikasi & Streak Share",
  "body": "### Pembaruan v$VERSION\n\n- ✨ **Perbaikan Tampilan Chat**: Teks chat lebih rapi, typography Google Fonts Outfit, spacing & alignment responsif.\n- 👥 **Manajemen Grup Chat**: Admin dapat mengedit/mengubah anggota dan menghapus grup chat.\n- 🚫 **Filter Pesan Sendiri**: Bubble pesan sendiri diatur secara tepat dan bersih di daftar obrolan.\n- 🔔 **Notifikasi Otomatis**: Notifikasi langsung untuk siswa saat tugas dinilai & untuk guru saat siswa mengumpulkan tugas.\n- 🔥 **Streak Share TikTok-Style**: Bagikan pencapaian streak belajar (kelipatan 10 hari) ke Instagram Story dan WhatsApp.",
  "draft": false,
  "prerelease": false
}
EOF
)

  CREATE_RES=$(curl -s -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/$REPO/releases \
    -d "$RELEASE_PAYLOAD")

  RELEASE_ID=$(echo "$CREATE_RES" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')
  echo "Release dibuat dengan ID: $RELEASE_ID"
else
  echo "Release $TAG sudah ada dengan ID: $RELEASE_ID"
fi

# 2. Upload APK Files
echo "=== Mengunggah APK ke GitHub Release ==="
UPLOAD_URL="https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets"

# Pastikan app-release.apk tersedia untuk tautan unduhan default di Firestore
if [ ! -f "$BUILD_DIR/app-release.apk" ]; then
  if [ -f "$BUILD_DIR/app-arm64-v8a-release.apk" ]; then
    echo "Menyalin app-arm64-v8a-release.apk -> app-release.apk untuk kompatibilitas tautan update..."
    cp "$BUILD_DIR/app-arm64-v8a-release.apk" "$BUILD_DIR/app-release.apk"
  fi
fi

for APK_FILE in "$BUILD_DIR"/app*.apk; do
  if [ -f "$APK_FILE" ]; then
    FILE_NAME=$(basename "$APK_FILE")
    echo "Mengunggah $FILE_NAME..."
    
    # Hapus asset lama jika ada nama yang sama
    EXISTING_ASSET_ID=$(curl -s -H "Authorization: token $TOKEN" \
      "https://api.github.com/repos/$REPO/releases/$RELEASE_ID/assets" | \
      grep -B 2 "\"name\": \"$FILE_NAME\"" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')
      
    if [ -n "$EXISTING_ASSET_ID" ]; then
      echo "Menghapus asset lama ($FILE_NAME: $EXISTING_ASSET_ID)..."
      curl -s -X DELETE \
        -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO/releases/assets/$EXISTING_ASSET_ID"
    fi

    # Upload asset baru
    UPLOAD_RES=$(curl -s -X POST \
      -H "Authorization: token $TOKEN" \
      -H "Content-Type: application/vnd.android.package-archive" \
      --data-binary @"$APK_FILE" \
      "$UPLOAD_URL?name=$FILE_NAME")
      
    echo "Upload $FILE_NAME selesai."
  fi
done

echo "=== Memperbarui Versi di Firestore ==="
cd /Users/azizul/ProjectLaravel/e-Learning
dart run tool/update_firestore_version.dart

echo "=== Rilis Berhasil Selesai! ==="
