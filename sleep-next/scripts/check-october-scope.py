"""Read-only metadata/scope checks. These do not compile Swift or run XCTest."""
import hashlib, json, pathlib, plistlib, re, subprocess
import yaml

root = pathlib.Path(__file__).resolve().parents[2]
git = ["git", "-c", "safe.directory=" + root.as_posix(), "-C", str(root)]
baseline = "7fc068e"
info = plistlib.loads((root / "sleep-next/Info.plist").read_bytes())
project = yaml.safe_load((root / "sleep-next/project.yml").read_text(encoding="utf-8"))
assert project["options"]["deploymentTarget"]["iOS"] == "16.0"
assert project["targets"]["AlarmaNext"]["settings"]["base"]["TARGETED_DEVICE_FAMILY"] == "1"
assert set(info["CFBundleLocalizations"]) == {"es", "en"}
assert info["NSHealthUpdateUsageDescription"] and info["ITSAppUsesNonExemptEncryption"] is False

words = (root / "sleep-next/Sources/Words.swift").read_text(encoding="utf-8")
matches = re.findall(r'"([A-Za-z][A-Za-z0-9]*)"\s*:\s*(\[(?:[^"\]]|"(?:\\.|[^"\\])*")*\])', words)
assert len(matches) == len(re.findall(r'"[A-Za-z][A-Za-z0-9]*"\s*:\s*\[', words))
for key, values in matches:
    values = json.loads(values)
    assert len(values) == 2 and all(values), key

resources = subprocess.check_output(git + ["ls-tree", "-r", "--name-only", baseline, "--", "sleep-next/Resources"], text=True).splitlines()
for filename in resources:
    before = subprocess.check_output(git + ["show", baseline + ":" + filename])
    after = (root / filename).read_bytes()
    # Git checks out text as CRLF on Windows; this is not an asset change.
    if pathlib.Path(filename).suffix in {".json", ".strings", ".plist", ".xcprivacy", ".txt"}:
        before, after = before.replace(b"\r\n", b"\n"), after.replace(b"\r\n", b"\n")
    assert hashlib.sha256(before).digest() == hashlib.sha256(after).digest(), filename
assert set(resources) == {p.relative_to(root).as_posix() for p in (root / "sleep-next/Resources").rglob("*") if p.is_file()}

workflow = yaml.safe_load((root / ".github/workflows/sleep-next.yml").read_text(encoding="utf-8"))
triggers = workflow.get("on", workflow.get(True))
assert "push" not in triggers
assert "repository.private == true" in workflow["jobs"]["validate"]["if"]
assert "IOS_CI_APPROVED" in workflow["jobs"]["validate"]["if"]
test_text = (root / "sleep-next/Tests/OctoberRecoveryTests.swift").read_text(encoding="utf-8")
result = {
    "scopeChecks": "passed", "nativeCompiled": False, "xctestExecuted": False,
    "regressionsPrepared": len(re.findall(r"func test\w+\(", test_text)),
    "languageEntries": len(matches), "unchangedResourceFiles": len(resources),
    "iPhoneOnly": True, "minimumIOS": "16.0", "automaticCIOnPush": False,
    "lastDeliveredVersion": "1.1 (1)", "newTestFlightUpload": False,
}
print(json.dumps(result, ensure_ascii=False, indent=2))
