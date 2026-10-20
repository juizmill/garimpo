# Builds Garimpo/Data/Vendors.lua from Wowhead Classic pages.
# Item pages give the "sold-by" NPC list (zone, reaction, cost) and vendor coordinates per zone.
# When a zone's vendors are not all on the same side (or there are several spots), the NPC
# pages are read too, so every vendor gets its own coordinates and faction.
import json, re, sys, time, urllib.request, pathlib

ITEMS = [3857, 2880, 3466, 2605, 3371, 8925, 159, 1179, 2678, 2692, 3713,
         2320, 2321, 4291, 8343, 2604, 6217, 17034, 17035, 3372]
CACHE = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
CACHE.mkdir(parents=True, exist_ok=True)


def fetch(kind, ident):
    path = CACHE / f"{kind}-{ident}.html"
    legacy = CACHE / f"{ident}.html"
    if kind == "item" and legacy.exists():
        legacy.rename(path)
    if path.exists() and path.stat().st_size > 10000:
        return path.read_text(encoding="utf-8", errors="replace")
    req = urllib.request.Request(f"https://www.wowhead.com/classic/{kind}={ident}",
                                 headers={"User-Agent": "Mozilla/5.0"})
    html = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", errors="replace")
    path.write_text(html, encoding="utf-8")
    time.sleep(3)
    return html


def balanced(text, start, open_ch, close_ch):
    depth, i, in_str, esc = 0, start, False, False
    while i < len(text):
        c = text[i]
        if in_str:
            if esc: esc = False
            elif c == "\\": esc = True
            elif c == '"': in_str = False
        else:
            if c == '"': in_str = True
            elif c == open_ch: depth += 1
            elif c == close_ch:
                depth -= 1
                if depth == 0:
                    return text[start:i + 1]
        i += 1
    raise ValueError("unbalanced")


def sold_by(html):
    m = re.search(r"id:\s*'sold-by'", html)
    if not m:
        return []
    d = html.index("data:", m.end())
    return json.loads(balanced(html, html.index("[", d), "[", "]"))


def mapper(html):
    i = html.find("g_mapperData")
    if i < 0:
        return {}
    return json.loads(balanced(html, html.index("{", i), "{", "}"))


def sides(npc):
    r = npc.get("react") or [None, None]
    a = r[0] is not None and r[0] >= 0
    h = len(r) > 1 and r[1] is not None and r[1] >= 0
    return a, h


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


plan_only = len(sys.argv) > 3 and sys.argv[3] == "--plan"
items = {}
ambiguous = set()
for item in ITEMS:
    html = fetch("item", item)
    npcs, maps = sold_by(html), mapper(html)
    items[item] = (npcs, maps)
    for zone_id, entries in maps.items():
        here = [n for n in npcs if int(zone_id) in (n.get("location") or [])]
        friendly = [n for n in here if any(sides(n))]
        side_set = {sides(n) for n in friendly}
        if len(friendly) > 1 and len(side_set) > 1:
            ambiguous.update(n["id"] for n in friendly)

print("ambiguous NPCs:", len(ambiguous))
if plan_only:
    sys.exit(0)

npc_coords = {}
for npc_id in sorted(ambiguous):
    try:
        npc_coords[npc_id] = mapper(fetch("npc", npc_id))
    except Exception as e:
        print("npc FAIL", npc_id, e)

out = ["local _, ns = ...", "",
       "-- Generated from Wowhead Classic (item sold-by lists, vendor map and NPC coordinates).",
       "-- [itemID] = { price = copper, spots = { { uiMapID, x, y, alliance, horde, \"NPC name(s)\" }, ... } }",
       "-- x and y are map percentages (0-100).",
       "ns.Vendors = {"]
for item in ITEMS:
    npcs, maps = items[item]
    costs = [n["cost"][0][0] for n in npcs if n.get("cost") and n["cost"][0]]
    price = max(set(costs), key=costs.count) if costs else 0
    spots = []
    for zone_id, entries in maps.items():
        here = [n for n in npcs if int(zone_id) in (n.get("location") or [])]
        friendly = [n for n in here if any(sides(n))]
        if not friendly:
            continue
        exact = [n for n in friendly if n["id"] in npc_coords]
        if exact:
            for n in exact:
                a, h = sides(n)
                for e in npc_coords[n["id"]].get(zone_id, []):
                    if e.get("coords"):
                        x, y = e["coords"][0]
                        spots.append((e["uiMapId"], x, y, a, h, n["name"]))
        else:
            a = any(sides(n)[0] for n in friendly)
            h = any(sides(n)[1] for n in friendly)
            names = ", ".join(sorted({n["name"] for n in friendly}))
            for e in entries:
                if e.get("coords"):
                    x, y = e["coords"][0]
                    spots.append((e["uiMapId"], x, y, a, h, names))
    spots.sort()
    print(item, "price", price, "spots", len(spots))
    out.append("  [%d] = { price = %d, spots = {" % (item, price))
    for ui, x, y, a, h, name in spots:
        out.append("    { %d, %s, %s, %s, %s, %s }," % (ui, x, y, str(a).lower(), str(h).lower(), lua_str(name)))
    out.append("  } },")
out.append("}")
OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
print("wrote", OUT)
