#!/bin/bash
swift build -c release 2>&1 | grep -v "^$"
exec .build/arm64-apple-macosx/release/MacTimeWidget
