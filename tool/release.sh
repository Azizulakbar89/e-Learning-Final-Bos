#!/usr/bin/env bash
set -e

# ==============================================================================
# Script Otomatis Rilis & Pembaruan "e-learning spemdalas"
# Penggunaan:
#   ./tool/release.sh [versi_baru] [catatan_rilis]
# Contoh:
#   ./tool/release.sh 1.0.3 "Fitur baru kuis & perbaikan bug"
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================================"
echo "  🚀 Rilis Otomatis: e-learning spemdalas"
echo "========================================================"

# 1. Baca versi saat ini dari pubspec.yaml
CURRENT_PUBSPEC_VER=$(grep '^version:' pubspec.yaml | sed 's/version: //')
CURRENT_NAME=$(echo "$CURRENT_PUBSPEC_VER" | cut -d'+' -f1)
CURRENT_CODE=$(echo "$CURRENT_PUBSPEC_VER" | cut -d'+' -f2)

echo "📌 Versi saat ini di pubspec.yaml: $CURRENT_NAME (Kode Build: $CURRENT_CODE)"

# 2. Tentukan versi baru
NEW_VERSION="$1"
if [ -z "$NEW_VERSION" ]; then
  # Auto-increment patch jika tidak diisi
  IFS='.' read -r major minor patch <<< "$CURRENT_NAME"
  NEW_PATCH=$((patch + 1))
  NEW_VERSION="${major}.${minor}.${NEW_PATCH}"
  echo "👉 Versi baru tidak diisi, menggunakan rekomendasi: $NEW_VERSION"
fi

NEW_CODE=$((CURRENT_CODE + 1))
RELEASE_NOTES="$2"
if [ -z "$RELEASE_NOTES" ]; then
  RELEASE_NOTES="Pembaruan aplikasi e-learning spemdalas v${NEW_VERSION}: peningkatan performa, perbaikan bug, dan stabilitas aplikasi."
fi

echo "✨ Versi rilis baru: $NEW_VERSION (Kode Build: $NEW_CODE)"
echo "📝 Catatan rilis: $RELEASE_NOTES"
echo "--------------------------------------------------------"

# 3. Update pubspec.yaml
sed -i '' "s/^version: .*/version: ${NEW_VERSION}+${NEW_CODE}/" pubspec.yaml
echo "✅ pubspec.yaml diperbarui menjadi ${NEW_VERSION}+${NEW_CODE}"

# 4. Build APK Release
echo "🔨 Membangun APK Release (flutter build apk --release)..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "❌ Error: File APK tidak ditemukan di $APK_PATH!"
  exit 1
fi
APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
echo "✅ APK Release selesai dibuild! Ukuran: $APK_SIZE"

# 5. Git Commit & Push
echo "📦 Menyimpan perubahan kode ke Git..."
git add pubspec.yaml lib/ tool/
git commit -m "chore(release): bump version to v${NEW_VERSION} (build ${NEW_CODE})" || true
git tag "v${NEW_VERSION}" || true

echo "🌐 Mendorong (push) ke GitHub repository..."
git push origin main
git push origin "v${NEW_VERSION}"

# 6. Upload APK ke GitHub Releases menggunakan Python & Git Credential Helper
echo "🚀 Mengunggah APK ke GitHub Releases..."
python3 -c "
import subprocess, urllib.request, json, os, sys

# Dapatkan GitHub token dari osxkeychain atau env
token = os.environ.get('GITHUB_TOKEN')
if not token:
    proc = subprocess.Popen(['git', 'credential-osxkeychain', 'get'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    stdout, _ = proc.communicate(b'protocol=https\nhost=github.com\n\n')
    for line in stdout.decode().splitlines():
        if line.startswith('password='):
            token = line.split('=', 1)[1]

if not token:
    print('❌ Tidak dapat menemukan GitHub Token untuk upload release.')
    sys.exit(1)

headers = {
    'Authorization': f'Bearer {token}',
    'User-Agent': 'SpemdalasReleaseScript',
    'Accept': 'application/vnd.github+json'
}

tag = 'v${NEW_VERSION}'
create_url = 'https://api.github.com/repos/Azizulakbar89/e-Learning-Final-Bos/releases'
body = json.dumps({
    'tag_name': tag,
    'target_commitish': 'main',
    'name': f'e-learning spemdalas {tag}',
    'body': '''${RELEASE_NOTES}''',
    'draft': False,
    'prerelease': False
}).encode('utf-8')

release = None
req = urllib.request.Request(create_url, data=body, headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        release = json.loads(resp.read().decode())
        print(f'✅ GitHub Release {tag} berhasil dibuat! ID: {release[\"id\"]}')
except urllib.error.HTTPError as e:
    req2 = urllib.request.Request(f'https://api.github.com/repos/Azizulakbar89/e-Learning-Final-Bos/releases/tags/{tag}', headers=headers)
    with urllib.request.urlopen(req2) as resp:
        release = json.loads(resp.read().decode())
        print(f'ℹ️ GitHub Release {tag} sudah ada, menggunakan rilis ID: {release[\"id\"]}')

upload_url_template = release['upload_url'].split('{?')[0]
apk_path = '${PROJECT_DIR}/build/app/outputs/flutter-apk/app-release.apk'
apk_size = os.path.getsize(apk_path)

with open(apk_path, 'rb') as f:
    apk_data = f.read()

upload_url = f'{upload_url_template}?name=app-release.apk'
req = urllib.request.Request(upload_url, data=apk_data, headers={
    'Authorization': f'Bearer {token}',
    'User-Agent': 'SpemdalasReleaseScript',
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Length': str(len(apk_data))
})

try:
    with urllib.request.urlopen(req) as resp:
        asset_res = json.loads(resp.read().decode())
        print('✅ File APK berhasil diunggah ke GitHub Releases!')
        print('🔗 Download URL:', asset_res.get('browser_download_url'))
except Exception as e:
    print('⚠️ Catatan upload asset:', e)
"

# 7. Update Firestore system_info/app_version
echo "🔥 Memperbarui konfigurasi versi di Firestore..."
python3 -c "
import json, re

# Update file tool/update_firestore_version.dart dengan versi baru
with open('tool/update_firestore_version.dart', 'r') as f:
    code = f.read()

code = re.sub(r\"'latest_version': \{'stringValue': '.*?'\}\", \"'latest_version': {'stringValue': '${NEW_VERSION}'}\", code)
code = re.sub(r\"'version_code': \{'integerValue': '.*?'\}\", \"'version_code': {'integerValue': '${NEW_CODE}'}\", code)
code = re.sub(r\"download/.*?/app-release\.apk\", f\"download/v${NEW_VERSION}/app-release.apk\", code)

with open('tool/update_firestore_version.dart', 'w') as f:
    f.write(code)
"

dart run tool/update_firestore_version.dart

echo "========================================================"
echo "  🎉 RILIS BERHASIL! Versi ${NEW_VERSION} (Kode ${NEW_CODE})"
echo "  📱 Pengguna aplikasi lama akan otomatis mendapatkan"
echo "     notifikasi pembaruan saat membuka aplikasi."
echo "  🔗 Unduh langsung: https://github.com/Azizulakbar89/e-Learning-Final-Bos/releases/download/v${NEW_VERSION}/app-release.apk"
echo "========================================================"
