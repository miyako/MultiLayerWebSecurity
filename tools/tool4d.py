#!/usr/bin/env python3
"""Run a 4D test method headlessly with tool4d, on a temporary copy of a project.

The repository copy is never modified. The test method must write its results
to File("/PACKAGE/agent-test.txt") and end with QUIT 4D; this script prints
that file.

  python tools/tool4d.py demo/MyProject --compile          # syntax check (Compile project)
  python tools/tool4d.py demo/MyProject test.4dm           # run a test method
  python tools/tool4d.py demo/MyProject test.4dm --data    # with a copy of Data/

tool4d is looked up in $TOOL4D, then /Applications/tool4d/*/*/tool4d.app.
Download: https://developer.4d.com/docs/Admin/cli#tool4d
Token rule: write command names without :Cnnn suffixes unless verified in the project.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

COMPILE = '''//%attributes = {}
var $result : Object
$result:=Compile project({targets: []})
File("/PACKAGE/agent-test.txt").setText(JSON Stringify($result; *))
QUIT 4D
'''


def find_tool4d():
    if os.environ.get("TOOL4D"):
        return os.environ["TOOL4D"]
    found = sorted(glob.glob("/Applications/tool4d/*/*/tool4d.app/Contents/MacOS/tool4d")
                   + glob.glob("/Applications/tool4d*.app/Contents/MacOS/tool4d")
                   + glob.glob(os.path.expanduser("~/tool4d/**/tool4d"), recursive=True))
    if not found and shutil.which("tool4d"):
        return shutil.which("tool4d")
    if not found:
        sys.exit("tool4d not found; set TOOL4D=/path/to/tool4d")
    return found[-1]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project", help="folder containing Project/ (e.g. demo/MyProject)")
    ap.add_argument("method", nargs="?", help=".4dm file with the test method")
    ap.add_argument("--compile", action="store_true")
    ap.add_argument("--data", action="store_true", help="copy Data/ and open it")
    args = ap.parse_args()
    src = Path(args.project).resolve()
    proj = next(src.glob("Project/*.4DProject"), None)
    if not proj:
        sys.exit(f"No Project/*.4DProject in {src}")
    code = COMPILE if args.compile or not args.method else Path(args.method).read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="tool4d-") as tmp:
        tmp = Path(tmp)
        for part in ("Project", "Resources") + (("Data",) if args.data else ()):
            if (src / part).exists():
                shutil.copytree(src / part, tmp / part, ignore=shutil.ignore_patterns("DerivedData"))
        (tmp / "Project/Sources/Methods").mkdir(parents=True, exist_ok=True)
        (tmp / "Project/Sources/Methods/agentTest.4dm").write_text(code, encoding="utf-8")
        cmd = [find_tool4d(), f"--project={tmp / 'Project' / proj.name}", "--startup-method=agentTest",
               "--skip-onstartup"]
        cmd += [f"--data={tmp / 'Data' / 'data.4DD'}"] if args.data else ["--dataless"]
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        out = tmp / "agent-test.txt"
        if not out.exists():
            print(run.stdout[-2000:], run.stderr[-2000:], sep="\n", file=sys.stderr)
            sys.exit("tool4d produced no agent-test.txt (did the method write it and QUIT 4D?)")
        print(out.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
