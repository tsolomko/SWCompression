#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 || $1 != "-T"  ]]; then
    echo "=> Downloading example files used for testing"

    (set -x ; git submodule update --init --recursive)
    if [ $? -ne 0 ]; then
        echo "ERROR: unable to update git submodule"
        exit 1
    fi

    (set -x; cd Tests/Test\ Files/ ; git lfs pull )
    if [ $? -ne 0 ]; then
        echo "ERROR: unable to download files using Git LFS"
        exit 1
    fi
fi

echo "=> Downloading dependency (BitByteData) using Carthage"
(set -x; carthage bootstrap)
