#!/bin/zsh
set -eu
repo_root=${0:A:h:h}
cd "$repo_root"
mkdir -p .build
swiftc -parse-as-library -swift-version 6 -module-name EnvLatchTransferAcceptance \
  -o .build/transfer-acceptance \
  Sources/EnvLatchCore/*.swift \
  Tests/EnvLatchCoreTests/NativeTransferAcceptanceHarness.swift \
  scripts/transfer-acceptance-main.swift \
  -framework Security
