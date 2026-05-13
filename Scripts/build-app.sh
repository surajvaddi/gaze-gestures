#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"

case "${CONFIGURATION}" in
  debug|release)
    ;;
  *)
    echo "Usage: Scripts/build-app.sh [debug|release]" >&2
    exit 64
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="GestureGaze"
EXECUTABLE_NAME="GazeGestures"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST="${ROOT_DIR}/Sources/GazeGesturesApp/Resources/Info.plist"
BUILD_CONFIGURATION_DIR="${CONFIGURATION}"

if [[ "${CONFIGURATION}" == "release" ]]; then
  swift build --package-path "${ROOT_DIR}" -c release
else
  swift build --package-path "${ROOT_DIR}"
fi

BUILT_EXECUTABLE="${ROOT_DIR}/.build/${BUILD_CONFIGURATION_DIR}/${EXECUTABLE_NAME}"

if [[ ! -x "${BUILT_EXECUTABLE}" ]]; then
  echo "Expected executable not found: ${BUILT_EXECUTABLE}" >&2
  exit 66
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILT_EXECUTABLE}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
cp "${INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

codesign --force --deep --sign - "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"

echo "Built ${APP_DIR}"
echo "Run with: open \"${APP_DIR}\""
