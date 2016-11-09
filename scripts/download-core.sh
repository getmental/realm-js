#!/bin/bash

set -e
set -o pipefail

# Set to "latest" for the latest build.
: ${REALM_CORE_VERSION:=2.1.4}
: ${REALM_SYNC_VERSION:=1.0.0-BETA-3.3}

if [ "$1" = '--version' ]; then
    echo "$REALM_CORE_VERSION"
    exit 0
fi

# The 'node' argument will result in realm-node build being downloaded.
if [ "$1" = 'node' ]; then
    CORE_DIR="core-node"
    SYNC_DIR='node-sync'

    if [ "$(uname)" = 'Darwin' ]; then
        PLATFORM_TAG="node-osx-"
        SYNC_PLATFORM_TAG="node-cocoa-"
        CORE_DOWNLOAD_FILE="realm-core-node-osx-$REALM_CORE_VERSION.tar.gz"
    else
        PLATFORM_TAG="node-linux-"
        SYNC_PLATFORM_TAG="node-cocoa-"
        CORE_DOWNLOAD_FILE="realm-core-node-linux-$REALM_CORE_VERSION.tar.gz"
    fi
    SYNC_DOWNLOAD_FILE="realm-sync-$SYNC_PLATFORM_TAG$REALM_SYNC_VERSION.zip"
    SYNC_EXTRACT="unzip"
    EXTRACTED_DIR="realm-sync-node-cocoa-$REALM_SYNC_VERSION"
else
    CORE_DIR='core'
    PLATFORM_TAG=""
    SYNC_DIR='sync'
    CORE_DOWNLOAD_FILE="realm-core-$PLATFORM_TAG$REALM_CORE_VERSION.tar.xz"
    SYNC_DOWNLOAD_FILE="realm-sync-cocoa-$SYNC_PLATFORM_TAG$REALM_SYNC_VERSION.tar.xz"
    SYNC_EXTRACT="tar -xvf"
    EXTRACTED_DIR="core"
fi

# Start current working directory at the root of the project.
cd "$(dirname "$0")/.."

die() {
    echo "$@" >&2
    exit 1
}

download_core() {
    local DIR=$1
    local VERSION=$2
    local DOWNLOAD_FILE=$3
    local SERVER_DIR=$4
    local UNTAR=$5
    local UNTARRED_DIR=$6
    echo "Downloading dependency: $DIR $VERSION"

    local TMP_DIR="${TMPDIR:-/tmp}/$DIR"
    local TAR="$TMP_DIR/$DOWNLOAD_FILE"
    local TMP_TAR="$TAR.tmp"

    mkdir -p "$TMP_DIR"

    if [ ! -f "$TAR" ]; then
	echo  "https://static.realm.io/downloads/$SERVER_DIR/$DOWNLOAD_FILE"
        curl -f -L -s "https://static.realm.io/downloads/$SERVER_DIR/$DOWNLOAD_FILE" -o "$TMP_TAR" ||
            die "Downloading $DIR failed. Please try again once you have an Internet connection."
        mv "$TMP_TAR" "$TAR"
    else
        echo "Using cached $DIR from TMPDIR"
    fi

    (
        cd "$TMP_DIR"
        rm -rf "$DIR"
        eval "$UNTAR" "$TAR"
        mv "$UNTARRED_DIR" "$DIR-$VERSION"
    )

    (
        cd vendor
        rm -rf "$DIR-$VERSION" "$DIR"
        mv "$TMP_DIR/$DIR-$VERSION" .
        ln -s "$DIR-$VERSION" "$DIR"
    )
}

check_release_notes() {
    grep -Fqi "$REALM_CORE_VERSION RELEASE NOTES" "$@"
}

if [ ! -e "vendor/$CORE_DIR" ]; then
    download_core $CORE_DIR $REALM_CORE_VERSION $CORE_DOWNLOAD_FILE core "tar -xzf" core
elif [ -d "vendor/$CORE_DIR" -a -d ../realm-core -a ! -L "vendor/$CORE_DIR" ]; then
    # Allow newer versions than expected for local builds as testing
    # with unreleased versions is one of the reasons to use a local build
    if ! check_release_notes "vendor/$CORE_DIR/CHANGELOG.txt"; then
        die "Local build of core is out of date."
    else
        echo "The core library seems to be up to date."
    fi
elif [ ! -L "vendor/$CORE_DIR" ]; then
    echo "vendor/$CORE_DIR is not a symlink. Deleting..."
    rm -rf "vendor/$CORE_DIR"
    download_core $CORE_DIR $REALM_CORE_VERSION $CORE_DOWNLOAD_FILE core "tar -xzf" core
# With a prebuilt version we only want to check the first non-empty
# line so that checking out an older commit will download the
# appropriate version of core if the already-present version is too new
elif ! grep -m 1 . "vendor/$CORE_DIR/CHANGELOG.txt" | check_release_notes; then
    download_core $CORE_DIR $REALM_CORE_VERSION $CORE_DOWNLOAD_FILE core "tar -xzf" core
else
    echo "The core library seems to be up to date."
fi


if [ ! -e "vendor/$SYNC_DIR" ]; then
    download_core $SYNC_DIR $REALM_SYNC_VERSION $SYNC_DOWNLOAD_FILE sync "$SYNC_EXTRACT" $EXTRACTED_DIR
elif [ -d "vendor/$SYNC_DIR" -a -d ../realm-sync -a ! -L "vendor/$SYNC_DIR" ]; then
    # Allow newer versions than expected for local builds as testing
    # with unreleased versions is one of the reasons to use a local build
    if ! check_release_notes "vendor/$SYNC_DIR/version.txt"; then
        die "Local build of sync is out of date."
    else
        echo "The sync library seems to be up to date."
    fi
elif [ ! -L "vendor/$SYNC_DIR" ]; then
    echo "vendor/$SYNC_DIR is not a symlink. Deleting..."
    rm -rf "vendor/$SYNC_DIR"
    download_core $SYNC_DIR $REALM_SYNC_VERSION $SYNC_DOWNLOAD_FILE sync "$SYNC_EXTRACT" $EXTRACTED_DIR
# With a prebuilt version we only want to check the first non-empty
# line so that checking out an older commit will download the
# appropriate version of core if the already-present version is too new
elif ! grep -m 1 . "vendor/$SYNC_DIR/version.txt" | check_release_notes; then
    download_core $SYNC_DIR $REALM_SYNC_VERSION $SYNC_DOWNLOAD_FILE sync "$SYNC_EXTRACT" $EXTRACTED_DIR
else
    echo "The sync library seems to be up to date."
fi
