# Builds Garimpo/Data/Trainers.lua from Wowhead Classic:
#   - every trainer of each profession (skill page "trainers" list) with its position;
#   - the named NPCs of the route milestones (trainers, book vendors, quest givers), found
#     by name when they are not trainers.
# Usage: python trainers.py <cache dir> <Data/Professions.lua> <Data/Trainers.lua>
import json, re, sys, time, urllib.request, urllib.parse, pathlib

SKILLS = {
    "blacksmithing": 164, "mining": 186, "herbalism": 182, "skinning": 393, "alchemy": 171,
    "enchanting": 333, "engineering": 202, "leatherworking": 165, "tailoring": 197,
    "firstaid": 129, "cooking": 185, "fishing": 356,
}
CACHE = pathlib.Path(sys.argv[1])
PROFS_LUA = pathlib.Path(sys.argv[2])
OUT = pathlib.Path(sys.argv[3])
CACHE.mkdir(parents=True, exist_ok=True)


def get(url, cache_name):
    path = CACHE / cache_name
    if path.exists() and path.stat().st_size > 5000:
        return path.read_text(encoding="utf-8", errors="replace")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
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


def listview(html, lv_id):
    m = re.search(r"id:\s*'" + re.escape(lv_id) + "'", html)
    if not m:
        return []
    d = html.index("data:", m.end())
    return json.loads(balanced(html, html.index("[", d), "[", "]"))


def mapper(html):
    i = html.find("g_mapperData")
    if i < 0:
        return {}
    return json.loads(balanced(html, html.index("{", i), "{", "}"))


def spots(npc_id):
    """First coordinate of the NPC in each zone: [(uiMapID, x, y)]."""
    try:
        data = mapper(get(f"https://www.wowhead.com/classic/npc={npc_id}", f"npc-{npc_id}.html"))
    except Exception as e:
        print("npc FAIL", npc_id, e)
        return []
    out = []
    for entries in data.values():
        if isinstance(entries, dict):
            entries = [entries]
        for e in entries if isinstance(entries, list) else []:
            if isinstance(e, dict) and e.get("uiMapId") and e.get("coords"):
                x, y = e["coords"][0]
                out.append((e["uiMapId"], x, y))
    return out


def sides(npc):
    r = npc.get("react") or [None, None]
    a = r[0] is not None and r[0] >= 0
    h = len(r) > 1 and r[1] is not None and r[1] >= 0
    return a, h


def find_npc(name):
    """Looks an NPC up by name; returns its id or None."""
    url = "https://www.wowhead.com/classic/search?q=" + urllib.parse.quote(name)
    html = get(url, "search-" + re.sub(r"[^A-Za-z0-9]+", "_", name) + ".html")
    for npc in listview(html, "npcs"):
        if npc.get("name", "").lower() == name.lower():
            return npc["id"]
    # The results link to npc=<id>; the NPC page title confirms the name.
    ids = []
    for m in re.finditer(r"npc=(\d+)", html):
        if m.group(1) not in ids:
            ids.append(m.group(1))
    for npc_id in ids[:5]:
        page = get(f"https://www.wowhead.com/classic/npc={npc_id}", f"npc-{npc_id}.html")
        title = re.search(r"<title>(.*?)</title>", page)
        if title and title.group(1).lower().startswith(name.lower() + " "):
            return int(npc_id)
    return None


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


trainers, names_done = {}, set()
for key, skill in SKILLS.items():
    html = get(f"https://www.wowhead.com/classic/skill={skill}", f"skill-{skill}.html")
    rows = []
    for npc in listview(html, "trainers"):
        a, h = sides(npc)
        if not (a or h):
            continue
        for ui, x, y in spots(npc["id"]):
            rows.append((ui, x, y, a, h, npc["name"]))
        names_done.add(npc["name"].lower())
    trainers[key] = rows
    print(key, len(rows), "trainer spots")

# Named NPCs of the milestones that are not trainers (book vendors, quest givers...).
named = {}
for name in sorted(set(re.findall(r'\{\s*"([^"]+)",\s*\d{4}\s*\}', PROFS_LUA.read_text(encoding="utf-8")))):
    npc_id = find_npc(name)
    if not npc_id:
        print("not found:", name)
        continue
    named[name] = spots(npc_id)
    print("named", name, len(named[name]))

out = ["local _, ns = ...", "",
       "-- Generated from Wowhead Classic (profession trainer lists and NPC positions).",
       "-- ns.Trainers[profession] = { { uiMapID, x, y, alliance, horde, \"name\" }, ... }",
       "-- ns.NPCs[name] = { { uiMapID, x, y }, ... }   (milestone NPCs: trainers, book vendors, quests)",
       "-- x and y are map percentages (0-100).",
       "ns.Trainers = {"]
for key, rows in trainers.items():
    out.append("  %s = {" % key)
    for ui, x, y, a, h, name in sorted(rows):
        out.append("    { %d, %s, %s, %s, %s, %s }," % (ui, x, y, str(a).lower(), str(h).lower(), lua_str(name)))
    out.append("  },")
out.append("}")
out.append("")
out.append("ns.NPCs = {")
for name, rows in named.items():
    pts = ", ".join("{ %d, %s, %s }" % r for r in rows)
    out.append("  [%s] = { %s }," % (lua_str(name), pts))
out.append("}")
OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
print("wrote", OUT, OUT.stat().st_size, "bytes")
