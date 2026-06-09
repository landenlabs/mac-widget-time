#!/bin/bash
pkill -x MacWidgetTime 2>/dev/null && sleep 0.5
swift build -c release 2>&1 | grep -v "^$"
.build/arm64-apple-macosx/release/MacWidgetTime &
disown
