#!/usr/bin/env python3
"""Drive the real /dev/tty consent helper using public synthetic identities only."""
import argparse
import errno
import json
import os
from pathlib import Path
import pty
import re
import select
import signal
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, mode=0o700, exist_ok=False)
    command = ["swift", "test", "--skip-build", "--no-parallel", "--filter", "terminalConsentNative"]
    receipts = []
    environment = dict(os.environ, ENVLATCH_TRANSFER_TERMINAL_TEST="no-tty")
    no_tty = subprocess.run(command, env=environment, capture_output=True, start_new_session=True, timeout=20)
    (args.evidence / "no-tty.log").write_bytes(no_tty.stdout + no_tty.stderr)
    receipts.append({"mode": "no-tty", "exit": no_tty.returncode})
    if no_tty.returncode or b"terminal_no_tty_refused_before_values=true" not in no_tty.stdout:
        raise RuntimeError("detached no-tty refusal failed")

    for mode in ["trust", "send", "receive"]:
        for approve in [False, True]:
            environment = dict(os.environ, ENVLATCH_TRANSFER_TERMINAL_TEST=mode,
                               ENVLATCH_TRANSFER_TERMINAL_EXPECT_APPROVED=str(approve).lower())
            child, descriptor = pty.fork()
            if child == 0:
                os.execvpe(command[0], command, environment)
            captured = bytearray()
            answered = False
            status = None
            deadline = time.monotonic() + 20
            try:
                while time.monotonic() < deadline:
                    readable, _, _ = select.select([descriptor], [], [], 0.05)
                    if readable:
                        try:
                            data = os.read(descriptor, 65536)
                        except OSError as error:
                            if error.errno == errno.EIO:
                                break
                            raise
                        if not data:
                            break
                        captured.extend(data)
                    output = captured.decode(errors="replace")
                    if "to approve: " in output and not answered:
                        if not approve:
                            answer = "cancel"
                        elif mode == "trust":
                            answer = re.search(r"Peer SHA-256 fingerprint: ([a-f0-9]{64})", output).group(1)
                        else:
                            answer = "901b3780-b39d-4db5-814b-d05833d0b9fc"
                        os.write(descriptor, (answer + "\n").encode())
                        answered = True
                    found, candidate = os.waitpid(child, os.WNOHANG)
                    if found:
                        status = candidate
                        break
                if status is None:
                    while time.monotonic() < deadline:
                        found, status = os.waitpid(child, os.WNOHANG)
                        if found:
                            break
                        time.sleep(0.01)
                    else:
                        os.killpg(child, signal.SIGTERM)
                        _, status = os.waitpid(child, 0)
                exit_code = os.waitstatus_to_exitcode(status)
            finally:
                os.close(descriptor)
            label = mode + ("-approve" if approve else "-cancel")
            path = args.evidence / (label + ".log")
            path.write_bytes(captured)
            receipts.append({"mode": label, "exit": exit_code, "prompt_answered": answered,
                             "owned_child_pid": child, "owned_child_reaped": True})
            if exit_code or not answered or b"terminal_exact_approval_matches_expected=true" not in captured:
                raise RuntimeError(label + " failed; inspect its nonsecret receipt")
    result = {"success": True, "receipts": receipts,
              "proof": "real controlling tty full fingerprint and exact operation approval/cancel; detached CLI preflight refusal",
              "limit": "terminal helper is real; positive CLI send plus two-device Keychain transfer uses separate Core proof"}
    (args.evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"success": True, "result": str(args.evidence / "result.json")}))


if __name__ == "__main__":
    main()
