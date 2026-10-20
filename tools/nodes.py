# Builds Garimpo/Data/Nodes.lua from Wowhead Classic: for each ore, herb and fish, the
# objects it comes from (veins, herbs, fishing pools) and their spawn points per zone.
# Everything heavy happens here: per zone we keep the hotspot (spot with the most nodes
# around it), the node count and at most MAX_POINTS thinned points for the map pins.
import json, re, sys, time, urllib.request, pathlib, math

ITEMS = {
    "ore": [2770, 2771, 2775, 2772, 2776, 3858, 7911, 10620],
    "herb": [2447, 765, 2449, 785, 2450, 3820, 2453, 3355, 3369, 3356, 3357, 3818, 3821, 3358, 3819,
             4625, 8831, 8836, 8838, 8839, 8845, 8846, 13464, 13463, 13465, 13466, 13467, 13468],
    "fish": [6358, 6359, 13422, 13754, 13755, 13756, 13757, 13758, 13759, 13760, 13889, 4603, 8365, 6308],
}
MAX_POINTS = 40
GRID = 2.5          # thinning grid, in map percent
RADIUS = 7.0        # hotspot neighbourhood, in map percent

CACHE = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
CACHE.mkdir(parents=True, exist_ok=True)


def fetch(kind, ident):
    path = CACHE / f"{kind}-{ident}.html"
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


def object_ids(html):
    ids = set()
    for m in re.finditer(r"template:\s*'object'", html):
        d = html.find("data:", m.end())
        if d < 0:
            continue
        try:
            for o in json.loads(balanced(html, html.index("[", d), "[", "]")):
                ids.add(o["id"])
        except ValueError:
            pass
    return ids


def mapper(html):
    i = html.find("g_mapperData")
    if i < 0:
        return {}
    return json.loads(balanced(html, html.index("{", i), "{", "}"))


def hotspot(points):
    best, best_n = points[0], -1
    for a in points:
        n = sum(1 for b in points if (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 <= RADIUS ** 2)
        if n > best_n:
            best, best_n = a, n
    return best


def thin(points):
    cells = {}
    for x, y in points:
        cells.setdefault((int(x // GRID), int(y // GRID)), (x, y))
    kept = list(cells.values())
    if len(kept) > MAX_POINTS:
        step = len(kept) / MAX_POINTS
        kept = [kept[int(i * step)] for i in range(MAX_POINTS)]
    return kept


objects = {}
out = ["local _, ns = ...", "",
       "-- Generated from Wowhead Classic (object spawn points of veins, herbs and fishing pools).",
       "-- [itemID] = { [uiMapID] = { hotspotX, hotspotY, nodeCount, { x1, y1, x2, y2, ... } } }",
       "-- Coordinates are map percentages (0-100); points are thinned for the map pins.",
       "ns.NodeData = {"]
total_points = 0
for kind, items in ITEMS.items():
    for item in items:
        try:
            ids = object_ids(fetch("item", item))
        except Exception as e:
            print("item FAIL", item, e)
            continue
        per_map = {}
        for oid in sorted(ids):
            if oid not in objects:
                try:
                    objects[oid] = mapper(fetch("object", oid))
                except Exception as e:
                    print("object FAIL", oid, e)
                    objects[oid] = {}
            for entries in objects[oid].values():
                if isinstance(entries, dict):
                    entries = [entries]
                if not isinstance(entries, list):
                    continue
                for e in entries:
                    if isinstance(e, dict) and e.get("uiMapId") and e.get("coords"):
                        per_map.setdefault(e["uiMapId"], []).extend(tuple(c) for c in e["coords"])
        if not per_map:
            print(kind, item, "no spawn data")
            continue
        out.append("  [%d] = {" % item)
        for ui in sorted(per_map):
            pts = per_map[ui]
            if len(pts) < 3:
                continue
            hx, hy = hotspot(pts)
            kept = thin(pts)
            total_points += len(kept)
            flat = ", ".join("%g, %g" % p for p in kept)
            out.append("    [%d] = { %g, %g, %d, { %s } }," % (ui, hx, hy, len(pts), flat))
        out.append("  },")
        print(kind, item, "objects", len(ids), "zones", len(per_map))
out.append("}")
OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
print("wrote", OUT, "points kept", total_points, "bytes", OUT.stat().st_size)
