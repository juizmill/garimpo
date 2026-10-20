import sys, re, pathlib

root = pathlib.Path(sys.argv[1])
loc = (root / "Locales.lua").read_text(encoding="utf-8")
en_part, pt_part = loc.split("local ptBR = {", 1)
key_re = re.compile(r"\b([A-Z][A-Z0-9_]+)\s*=")
en = set(key_re.findall(en_part))
pt = set(key_re.findall(pt_part.split("local strings", 1)[0]))

used = set()
for f in root.rglob("*.lua"):
    if f.name == "Locales.lua":
        continue
    src = f.read_text(encoding="utf-8")
    used |= set(re.findall(r"\bL\.([A-Z][A-Z0-9_]+)", src))
    used |= set(re.findall(r"\"([A-Z][A-Z0-9]*_[A-Z0-9_]+)\"", src))
    used |= set(re.findall(r"\"(BACK|REFRESH|POST|PRIMARY|SECONDARY|BUDGET|NONE|TODAY)\"", src))

print("missing in enUS:", sorted(used - en))
print("missing in ptBR:", sorted(used - pt))
print("only in one locale:", sorted(en ^ pt))
print("defined but unused:", sorted(en - used))
