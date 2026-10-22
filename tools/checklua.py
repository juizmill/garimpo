import sys, pathlib
from luaparser import ast

root = pathlib.Path(sys.argv[1])


# luaparser accepts a line break inside a "..." or '...' string, but the game doesn't
# ("unfinished string"). Walk the source and report such strings.
def broken_strings(src):
    problems, i, n, line = [], 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
        elif src.startswith("--", i):
            # Long comment --[[ ]] / --[==[ ]==], or a line comment.
            j = i + 2
            if src.startswith("[", j):
                k = j + 1
                while k < n and src[k] == "=":
                    k += 1
                if k < n and src[k] == "[":
                    close = "]" + "=" * (k - j - 1) + "]"
                    end = src.find(close, k)
                    end = n if end < 0 else end + len(close)
                    line += src.count("\n", i, end)
                    i = end
                    continue
            end = src.find("\n", i)
            i = n if end < 0 else end
        elif c == "[" and i + 1 < n and src[i + 1] in "[=":
            # Long string [[ ]] / [==[ ]==]: line breaks are fine there.
            k = i + 1
            while k < n and src[k] == "=":
                k += 1
            if k < n and src[k] == "[":
                close = "]" + "=" * (k - i - 1) + "]"
                end = src.find(close, k)
                end = n if end < 0 else end + len(close)
                line += src.count("\n", i, end)
                i = end
            else:
                i += 1
        elif c in "\"'":
            start, j = line, i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == "\n":
                    problems.append(start)
                    break
                j += 1
            line += src.count("\n", i, j)
            i = j + 1
        else:
            i += 1
    return sorted(set(problems))


bad = 0
for f in sorted(root.rglob("*.lua")):
    src = f.read_text(encoding="utf-8")
    try:
        ast.parse(src)
        lines = broken_strings(src)
        if lines:
            bad += 1
            print("FAIL", f.relative_to(root), "-> line break inside a string at line(s)", lines)
        else:
            print("OK  ", f.relative_to(root))
    except Exception as e:
        bad += 1
        print("FAIL", f.relative_to(root), "->", str(e)[:400])
sys.exit(1 if bad else 0)
