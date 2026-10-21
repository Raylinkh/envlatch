#!/usr/bin/env python3
"""Run the opt-in synthetic test helper on this Mac and the approved Studio.

The candidate must already be built at both roots. SSH controls test processes;
credential bytes travel only through the production authenticated TCP channel.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--remote-root", required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--run-id", default=str(uuid.uuid4()))
    parser.add_argument("--operation", default=str(uuid.uuid4()))
    parser.add_argument("--port", type=int, default=49271)
    args = parser.parse_args()
    uuid.UUID(args.run_id)
    uuid.UUID(args.operation)
    expected_remote_root = Path("/Users/jayden/Library/Caches/EnvLatchTransfer-01a15f0a")
    if Path(args.remote_root) != expected_remote_root:
        parser.error("remote root must be the task-owned Studio cache")
    args.evidence.mkdir(parents=True, exist_ok=False, mode=0o700)
    local_root = args.evidence / "local-public-metadata"
    local_root.mkdir(mode=0o700)
    remote_metadata = args.remote_root + "/acceptance-" + args.run_id
    base = {
        "ENVLATCH_TRANSFER_ACCEPTANCE_RUN_ID": args.run_id,
        "ENVLATCH_TRANSFER_ACCEPTANCE_OPERATION": args.operation,
        "ENVLATCH_TRANSFER_ACCEPTANCE_PORT": str(args.port),
    }
    command = [".build/transfer-acceptance"]
    receipts = []
    process_ids = {False: set(), True: set()}

    manifest_program = """
import hashlib,json,platform,subprocess
from pathlib import Path
paths=[Path('Package.swift')]+[p for root in ['Sources','Tests','scripts'] for p in Path(root).rglob('*') if p.is_file()]
manifest={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
identity=hashlib.sha256(json.dumps(manifest,sort_keys=True,separators=(',',':')).encode()).hexdigest()
print(json.dumps({'source_manifest':identity,'file_count':len(manifest),'architecture':platform.machine(),'macos':subprocess.check_output(['sw_vers','-productVersion'],text=True).strip(),'swift':subprocess.check_output(['swift','--version'],text=True).strip()}))
"""

    def platform_manifest(remote=False):
        argv = ["python3", "-c", manifest_program]
        if remote:
            argv = ["ssh", "studio", "cd " + shlex.quote(args.remote_root) + " && " + shlex.join(argv)]
        result = subprocess.run(argv, capture_output=True, text=True, timeout=20, check=True)
        return json.loads(result.stdout)

    identities = {"source": platform_manifest(), "target": platform_manifest(True)}
    if identities["source"]["source_manifest"] != identities["target"]["source_manifest"]:
        raise RuntimeError("candidate source manifests differ across Macs")
    (args.evidence / "candidate-platforms.json").write_text(json.dumps(identities, indent=2) + "\n")

    def remember_processes(output, remote):
        process_ids[remote].update(int(pid) for pid in re.findall(r"^native_(?:pid|reaped_child_pid)=(\d+)$", output, re.M))

    def prepare(mode, remote=False, peer=None):
        values = dict(base, ENVLATCH_TRANSFER_ACCEPTANCE_MODE=mode,
                      ENVLATCH_TRANSFER_ACCEPTANCE_ROOT=remote_metadata if remote else str(local_root))
        if peer:
            values.update(ENVLATCH_TRANSFER_PEER_PUBLIC_KEY=peer,
                          ENVLATCH_TRANSFER_PEER_ADDRESS="100.102.186.35" if remote else "100.85.4.100",
                          ENVLATCH_TRANSFER_BIND_ADDRESS="100.85.4.100" if remote else "100.102.186.35")
        if remote:
            invocation = ["env"] + [key + "=" + value for key, value in values.items()] + command
            return ["ssh", "studio", "cd " + shlex.quote(args.remote_root) + " && " + shlex.join(invocation)], None
        return command, dict(os.environ, **values)

    def run(stage, mode, remote=False, peer=None):
        argv, environment = prepare(mode, remote, peer)
        path = args.evidence / (stage + ".log")
        with path.open("wb") as log:
            result = subprocess.run(argv, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=60)
        receipts.append({"stage": stage, "exit": result.returncode, "log": str(path)})
        remember_processes(path.read_text(), remote)
        if result.returncode:
            raise RuntimeError(stage + " failed; inspect its nonsecret log")
        for name in ["native_default_keychain_unchanged", "native_searchlist_unchanged"]:
            if field(path.read_text(), name) != "true":
                raise RuntimeError(stage + " changed Keychain authority")
        return path.read_text()

    def field(output, name):
        match = re.search(r"^" + re.escape(name) + r"=(\S+)$", output, re.M)
        if not match:
            raise RuntimeError("missing native helper receipt: " + name)
        return match.group(1)

    def exchange(stage, source_public, target_public):
        argv, environment = prepare("receive", True, source_public)
        target_path = args.evidence / (stage + "-target.log")
        target_log = target_path.open("wb")
        target = subprocess.Popen(argv, env=environment, stdout=target_log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                if "native_listener=ready" in target_path.read_text():
                    break
                if target.poll() is not None:
                    raise RuntimeError("target exited before listener readiness")
                time.sleep(0.05)
            else:
                raise RuntimeError("target did not become ready")
            source = run(stage + "-source", "send", peer=target_public)
            target.wait(timeout=55)
            receipts.append({"stage": stage + "-target", "exit": target.returncode, "log": str(target_path)})
            if target.returncode:
                raise RuntimeError("target helper failed")
            target_output = target_path.read_text()
            remember_processes(target_output, True)
            for output in [source, target_output]:
                if field(output, "native_result") != "committed":
                    raise RuntimeError("noncommitted operation")
                if field(output, "native_operation").lower() != args.operation.lower():
                    raise RuntimeError("operation mismatch")
            for name in ["native_target_only_selected", "native_selected_exact", "native_unselected_absent"]:
                if field(target_output, name) != "true":
                    raise RuntimeError("target selected-key receipt failed")
        finally:
            # The production listener/session has a 45-second deadline. Let its owned process settle.
            if target.poll() is None:
                try:
                    target.wait(timeout=55)
                except subprocess.TimeoutExpired:
                    target.terminate()
                    target.wait(timeout=5)
            target_log.close()
            remember_processes(target_path.read_text(), True)

    failure = None
    try:
        source = run("source-identity", "identity")
        target = run("target-identity", "identity", remote=True)
        source_public = field(source, "native_public_key")
        target_public = field(target, "native_public_key")
        if source_public == target_public:
            raise RuntimeError("source and target identities are not distinct")
        run("source-seed", "seed")
        exchange("first-transfer", source_public, target_public)
        run("source-unchanged", "verify")
        exchange("committed-reconnect", source_public, target_public)
        run("source-unchanged-after-reconnect", "verify")
    except Exception as error:
        failure = str(error)
    finally:
        for stage, remote in [("target-cleanup", True), ("source-cleanup", False)]:
            try:
                output = run(stage, "cleanup", remote=remote)
                if field(output, "native_isolated_keychain_deleted") != "true":
                    raise RuntimeError("isolated Keychain cleanup unproved")
            except Exception as error:
                failure = (failure + "; " if failure else "") + str(error)
        for stage, remote in [("source-public-metadata-scan", False), ("target-public-metadata-scan", True)]:
            try:
                output = run(stage, "scan", remote=remote)
                for name in ["native_no_synthetic_value_in_public_metadata", "native_no_unexpected_staging_files"]:
                    if field(output, name) != "true":
                        raise RuntimeError("public metadata scan failed")
            except Exception as error:
                failure = (failure + "; " if failure else "") + str(error)
        sentinel_source = Path("Tests/EnvLatchCoreTests/NativeTransferAcceptanceHarness.swift").read_text()
        sentinel = re.search(r'private static let syntheticSentinel = "([^"\n]+)"', sentinel_source).group(1).encode()
        no_value_in_logs = all(sentinel not in path.read_bytes() for path in args.evidence.glob("*.log"))
        if not no_value_in_logs:
            failure = (failure + "; " if failure else "") + "synthetic bytes appeared in a diagnostic log"
        process_check = """
import json,os,sys
live=[]
for pid in json.loads(sys.argv[1]):
 try: os.kill(pid,0);live.append(pid)
 except ProcessLookupError: pass
print(json.dumps({'owned_processes_inactive':not live,'live_owned_pids':live}))
"""
        quiescence = {}
        for remote in [False, True]:
            argv = ["python3", "-c", process_check, json.dumps(sorted(process_ids[remote]))]
            if remote:
                argv = ["ssh", "studio", shlex.join(argv)]
            checked = subprocess.run(argv, capture_output=True, text=True, timeout=15, check=True)
            quiescence["target" if remote else "source"] = json.loads(checked.stdout)
            if not quiescence["target" if remote else "source"]["owned_processes_inactive"]:
                failure = (failure + "; " if failure else "") + "owned native test process still active"
        result = {"run_id": args.run_id, "operation": args.operation, "receipts": receipts,
                  "candidate_platforms": identities, "no_synthetic_value_in_logs": no_value_in_logs,
                  "owned_process_quiescence": quiescence,
                  "proof": "Core TransferSession, real TCP authenticated HPKE, isolated encrypted file Keychain and selected-key child",
                  "consent": "injected exact-binding test consent; production tty approval is separate",
                  "limit": "Studio default-Keychain SSH identity creation returned -25308; default GUI and signed app acceptance remain unverified",
                  "success": failure is None, "failure": failure}
        (args.evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"success": failure is None, "result": str(args.evidence / "result.json"), "failure": failure}))
    return 1 if failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
