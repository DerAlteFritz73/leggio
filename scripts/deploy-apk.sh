#!/bin/sh
#
# Deploy APK to leggio.kreilos.fr.
#
# The site is now served by nginx running in WSL on the build host itself, so
# "deploy" is a local file copy into the web root plus regenerating index.html.
# (Previously this scp'd to a Raspberry Pi at chuck@teutonia.kreilos.fr, which
# has been decommissioned.)
#
# Called automatically by the Gradle renameApk -> deployApk chain after
# `flutter build apk --release`, and by the GitHub Actions self-hosted runner.
#
# Override the destination with LEGGIO_WEB_DIR if needed.
set -e

WEB_DIR="${LEGGIO_WEB_DIR:-/var/www/prod/leggio}"

REPO_DIR="$(pwd)"

# Read version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d '\r' | cut -d'+' -f1)
APK_NAME="leggio-${VERSION}.apk"
APK_PATH="build/app/outputs/flutter-apk/${APK_NAME}"

if [ ! -f "$APK_PATH" ]; then
    echo "Error: APK not found at $APK_PATH"
    exit 1
fi

if [ ! -d "$WEB_DIR" ]; then
    echo "Error: web root $WEB_DIR does not exist (run the nginx site setup first)"
    exit 1
fi

echo "Publishing ${APK_NAME} to ${WEB_DIR}..."
cp -f "$APK_PATH" "${WEB_DIR}/${APK_NAME}"

# Publish the IMSLP database alongside the APK if present (the app downloads it
# from leggio.kreilos.fr/imslp.db).
DB_PATH="${REPO_DIR}/assets/db/imslp.db"
if [ -f "$DB_PATH" ]; then
    echo "Publishing imslp.db..."
    cp -f "$DB_PATH" "${WEB_DIR}/imslp.db"
fi

echo "Regenerating index.html..."
cd "$WEB_DIR"
ls -t *.apk | while read f; do
    d=$(stat -c %y "$f" | cut -d. -f1)
    echo "$f $d"
done | awk 'BEGIN {
    print "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Leggio APK</title>"
    print "<style>body{font-family:sans-serif;max-width:600px;margin:40px auto;padding:0 20px}"
    print "a{display:block;padding:8px 0;color:#1a73e8;text-decoration:none}"
    print "a:hover{text-decoration:underline}"
    print "span{color:#666;font-size:0.85em;margin-left:12px}</style></head><body>"
    print "<h1>Leggio</h1>"
}
{ print "<a href=\"" $1 "\">" $1 "<span>" $2 " " $3 "</span></a>" }
END { print "</body></html>" }' > index.html

echo "Deployed: https://leggio.kreilos.fr/${APK_NAME}"
