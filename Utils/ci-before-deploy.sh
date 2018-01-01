#!/bin/bash

set -euxo pipefail

carthage build --no-skip-current
carthage archive SWCompression
swift build
sourcekitten doc --spm-module SWCompression > docs.json
jazzy
