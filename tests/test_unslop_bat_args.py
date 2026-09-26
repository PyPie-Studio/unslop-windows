#!/usr/bin/env python3
"""
Test suite for unslop.bat argument validation security fix.
"""
import os
import re
import sys

def test_crlf_line_endings():
    bat_path = os.path.join(os.path.dirname(__file__), '..', 'unslop.bat')
    with open(bat_path, 'rb') as f:
        content = f.read()

    lines = content.split(b'\n')
    naked_lfs = [i + 1 for i, line in enumerate(lines[:-1]) if len(line) > 0 and not line.endswith(b'\r')]
    assert not naked_lfs, f"unslop.bat contains naked LF line endings on lines: {naked_lfs}"
    print("[PASS] unslop.bat CRLF line endings verified.")

def test_forward_and_final_args_validation():
    bat_path = os.path.join(os.path.dirname(__file__), '..', 'unslop.bat')
    with open(bat_path, 'r', encoding='utf-8') as f:
        content = f.read()

    assert "Validate forwarded arguments against strict target script switch whitelist" in content, \
        "Missing FORWARD_ARGS validation header in unslop.bat"

    assert "if defined FORWARD_ARGS (" in content, \
        "Missing defined check for FORWARD_ARGS in unslop.bat"

    assert "if defined FINAL_ARGS (" in content, \
        "Missing defined check for FINAL_ARGS in unslop.bat"

    # Verify that FORWARD_ARGS loop checks against the switch whitelist
    assert "-Undo -Restore -DryRun -WhatIf -KeepXbox -KeepOneDrive -KeepTodos -KeepSysMain -KeepSearch -KeepPhoneLink -KeepMail -KeepClock -KeepSpotify -KeepTeams -KeepStoreAutoUpdate -ClassicContextMenu -LeftTaskbar -ExcludeWUDrivers -KeepDefenderDefaults -NoRestart -ForceRestart -SkipBuildCheck" in content, \
        "Missing expected switch whitelist in unslop.bat"

    print("[PASS] FORWARD_ARGS and FINAL_ARGS validation logic verified in unslop.bat.")

if __name__ == '__main__':
    try:
        test_crlf_line_endings()
        test_forward_and_final_args_validation()
        print("All batch argument security tests passed successfully!")
    except AssertionError as e:
        print(f"[FAIL] {e}", file=sys.stderr)
        sys.exit(1)
