import sys, pathlib
from luaparser import ast

root = pathlib.Path(sys.argv[1])
bad = 0
for f in sorted(root.rglob("*.lua")):
    src = f.read_text(encoding="utf-8")
    try:
        ast.parse(src)
        print("OK  ", f.relative_to(root))
    except Exception as e:
        bad += 1
        print("FAIL", f.relative_to(root), "->", str(e)[:400])
sys.exit(1 if bad else 0)
