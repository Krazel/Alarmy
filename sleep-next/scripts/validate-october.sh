#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
command -v xcodebuild >/dev/null
command -v xcodegen >/dev/null
RUN_STAMP=$(date -u +%Y%m%dT%H%M%SZ)
RUN_DIR="$ROOT/Evidence/october-2026/native-$RUN_STAMP"
mkdir -p "$RUN_DIR"
git rev-parse HEAD > "$RUN_DIR/source.txt"
git status --short > "$RUN_DIR/working-tree.txt"
xcodebuild -version > "$RUN_DIR/xcode.txt"
xcodegen generate
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); phones=[x for ds in d["devices"].values() for x in ds if "iPhone" in x["name"]]; phones.sort(key=lambda x:x["state"]!="Booted"); print(phones[0]["udid"])')
if ! xcrun simctl list devices booted -j | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if any(x["udid"]==sys.argv[1] for ds in d["devices"].values() for x in ds) else 1)' "$DEVICE"; then
  xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b &
BOOT_PID=$!
trap 'kill "$BOOT_PID" 2>/dev/null || true' EXIT
xcodebuild -project AlarmaNext.xcodeproj -scheme AlarmaNext -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$RUN_DIR/build" \
  CODE_SIGNING_ALLOWED=NO ARCHS="$(uname -m)" build-for-testing 2>&1 | tee "$RUN_DIR/compile.log"
wait "$BOOT_PID"
FILTERS=(
  -only-testing:AlarmaNextTests/OctoberRecoveryTests
  -only-testing:AlarmaNextTests/OctoberStoreRecoveryTests
  -only-testing:AlarmaNextTests/CaptureIntegrationTests
  -only-testing:AlarmaNextTests/AcousticCaptureTests
  -only-testing:AlarmaNextTests/RepositoryTests
  -only-testing:AlarmaNextUITests/NativeFlowTests/testClipDetailPlaybackNavigationAndCorrection
)
if [[ "${VALIDATION_SCOPE:-october}" == "design" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextTests/JournalDesignTests
    -only-testing:AlarmaNextTests/JournalPreviewIsolationTests
    -only-testing:AlarmaNextUITests/NativeFlowTests/testJournalExamplesAndMoodCalendar
  )
fi
if [[ "${VALIDATION_SCOPE:-october}" == "analysis" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextTests/SleepAnalysisTests
    -only-testing:AlarmaNextTests/HealthTimelineTests
    -only-testing:AlarmaNextTests/CaptureIntegrationTests
    -only-testing:AlarmaNextUITests/NativeFlowTests/testNightModesSwipeAndStatistics
    -only-testing:AlarmaNextUITests/NativeFlowTests/testEnglishExactNightAndAnalysisDiary
  )
fi
if [[ "${VALIDATION_SCOPE:-october}" == "categories" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextTests/JournalDesignTests/testExamplesCoverFeelingsClipsAndGapsWithoutActiveAlarm
    -only-testing:AlarmaNextTests/JournalPreviewIsolationTests
    -only-testing:AlarmaNextUITests/NativeFlowTests/testClipDetailPlaybackNavigationAndCorrection
    -only-testing:AlarmaNextUITests/NativeFlowTests/testSpanishClipDetail
  )
fi
if [[ "${VALIDATION_SCOPE:-october}" == "onda" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextTests/ActiveAlarmTests
    -only-testing:AlarmaNextTests/CaptureRetimeTests
    -only-testing:AlarmaNextUITests/NativeFlowTests/testMinimalNightAndInlineAlarmEnglish
    -only-testing:AlarmaNextUITests/NativeFlowTests/testMinimalNightAndInlineAlarmSpanishSmart
    -only-testing:AlarmaNextUITests/NativeFlowTests/testNightModesSwipeAndStatistics
  )
fi
if [[ "${VALIDATION_SCOPE:-october}" == "feedback" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextTests/NightFeedbackTests
    -only-testing:AlarmaNextTests/OctoberRecoveryTests/testRetentionWriteFailurePreservesAudioAndJournal
    -only-testing:AlarmaNextTests/OctoberRecoveryTests/testRelaunchCompletesDeletionAndRemovesRecoveryReceipt
    -only-testing:AlarmaNextTests/AcousticCaptureTests/testBudgetExhaustionReportsFailureAndLeavesRecoverableData
    -only-testing:AlarmaNextUITests/NativeFlowTests/testFeedbackJournalAndStorageEnglish
    -only-testing:AlarmaNextUITests/NativeFlowTests/testFeedbackJournalAndStorageSpanish
    -only-testing:AlarmaNextUITests/NativeFlowTests/testMinimalNightAndInlineAlarmEnglish
  )
fi
if [[ "${VALIDATION_SCOPE:-october}" == "onda_time" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextTests/ActiveAlarmTests
    -only-testing:AlarmaNextTests/CaptureRetimeTests
  )
fi
if [[ "${VALIDATION_SCOPE:-october}" == "onda_visual" ]]; then
  FILTERS=(
    -only-testing:AlarmaNextUITests/NativeFlowTests/testMinimalNightAndInlineAlarmEnglish
    -only-testing:AlarmaNextUITests/NativeFlowTests/testMinimalNightAndInlineAlarmSpanishSmart
  )
fi
xcodebuild -project AlarmaNext.xcodeproj -scheme AlarmaNext \
  -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath "$RUN_DIR/build" \
  -resultBundlePath "$RUN_DIR/Tests.xcresult" -parallel-testing-enabled NO \
  "${FILTERS[@]}" \
  CODE_SIGNING_ALLOWED=NO test-without-building 2>&1 | tee "$RUN_DIR/test.log"
xcodebuild -project AlarmaNext.xcodeproj -scheme AlarmaNext -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$RUN_DIR/device" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build 2>&1 | tee "$RUN_DIR/release.log"
echo "Native evidence: $RUN_DIR"
