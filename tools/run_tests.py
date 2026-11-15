"""Runs every automated test from one command and exits with pass or fail.

1. The data check (tables, ids, references).
2. The bake check: baking twice gives identical chunks, matching the ones in
   the repository.
3. The Godot tests, headless, with no window.

Run: python tools/run_tests.py [--godot PATH] [filter]
The Godot path can also be set with the GODOT environment variable.
"""
import argparse
import filecmp
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.dirname(os.path.abspath(__file__))
DEFAULT_GODOT = r"C:\Godot\Godot_v4.7.2-stable_win64_console.exe"


def bake_check():
    a = tempfile.mkdtemp(prefix="bake_a_")
    b = tempfile.mkdtemp(prefix="bake_b_")
    try:
        for d in (a, b):
            r = subprocess.run([sys.executable, "-I", os.path.join(TOOLS, "bake_world.py"), "--out", d, "--quiet"])
            if r.returncode != 0:
                print("bake check FAILED: the bake reported problems")
                return False
        names = sorted(os.listdir(os.path.join(a, "chunks")))
        same, diff, err = filecmp.cmpfiles(os.path.join(a, "chunks"), os.path.join(b, "chunks"), names, shallow=False)
        if diff or err or not filecmp.cmp(os.path.join(a, "world.json"), os.path.join(b, "world.json"), shallow=False):
            print("bake check FAILED: two bakes differ:", diff, err)
            return False
        repo = os.path.join(ROOT, "data", "world")
        same, diff, err = filecmp.cmpfiles(os.path.join(a, "chunks"), os.path.join(repo, "chunks"), names, shallow=False)
        if diff or err or not filecmp.cmp(os.path.join(a, "world.json"), os.path.join(repo, "world.json"), shallow=False):
            print("bake check FAILED: the stored chunks are out of date; run python tools/bake_world.py", diff[:5], err[:5])
            return False
        print("bake check passed: two bakes identical, %d chunks match the repository" % len(names))
        return True
    finally:
        shutil.rmtree(a, ignore_errors=True)
        shutil.rmtree(b, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    ap.add_argument("filter", nargs="?", default="")
    args = ap.parse_args()
    ok = True

    print("== data check")
    ok &= subprocess.run([sys.executable, "-I", os.path.join(TOOLS, "check_data.py")]).returncode == 0
    print("== bake check")
    ok &= bake_check()
    print("== godot tests")
    subprocess.run([args.godot, "--headless", "--path", ROOT, "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
    cmd = [args.godot, "--headless", "--path", ROOT, "-s", "tests/run_tests.gd"]
    if args.filter:
        cmd += ["--", args.filter]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1200)
    noise = ("leaked", "PagedAllocator", "Unreferenced static", "Thread object", "wait_to_finish", "   at: ")
    for line in (r.stdout + r.stderr).splitlines():
        if line.strip() and not any(n in line for n in noise):
            print(line)
    ok &= r.returncode == 0
    print("== ALL TESTS PASSED" if ok else "== TESTS FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
