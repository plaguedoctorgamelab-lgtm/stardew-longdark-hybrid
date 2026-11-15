"""Checks the content tables and tuning file from outside the game.

Confirms every table loads, every id is unique, every reference points at a
real row, and every text id used exists. Exits 1 on any problem.
Run: python tools/check_data.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "data", "content")
TABLES = ["items", "foods", "weather_types", "weather_odds", "structures", "landmarks", "jobs", "obstacles", "recipes", "text"]


def main():
    problems = []
    data = {}
    for t in TABLES:
        path = os.path.join(CONTENT, t + ".json")
        try:
            with open(path, encoding="utf-8") as f:
                rows = json.load(f)["rows"]
        except Exception as e:  # noqa: BLE001 - report any load failure
            problems.append("%s does not load: %s" % (t, e))
            continue
        ids = {}
        for r in rows:
            rid = r.get("id")
            if not rid:
                problems.append("%s: row without id" % t)
            elif rid in ids:
                problems.append("%s: duplicate id %s" % (t, rid))
            elif rid != rid.lower() or " " in rid:
                problems.append("%s: id %s is not lowercase_with_underscores" % (t, rid))
            ids[rid] = r
        data[t] = ids
    try:
        with open(os.path.join(ROOT, "data", "tuning", "tuning.json"), encoding="utf-8") as f:
            json.load(f)
    except Exception as e:  # noqa: BLE001
        problems.append("tuning.json does not load: %s" % e)

    def ref(table, rid, where):
        if rid not in data.get(table, {}):
            problems.append("%s points at missing %s row '%s'" % (where, table, rid))

    for r in data.get("items", {}).values():
        ref("text", r["name"], "items/%s name" % r["id"])
    for r in data.get("foods", {}).values():
        ref("items", r["item"], "foods/%s" % r["id"])
    for r in data.get("weather_types", {}).values():
        ref("text", r["name"], "weather_types/%s" % r["id"])
    weather_ids = set(data.get("weather_types", {}))
    for r in data.get("weather_odds", {}).values():
        for w in r["odds"]:
            ref("weather_types", w, "weather_odds/%s" % r["id"])
        missing = weather_ids - set(r["odds"])
        if missing:
            problems.append("weather_odds/%s lacks %s" % (r["id"], sorted(missing)))
        if abs(sum(r["odds"].values()) - 100) > 0.001:
            problems.append("weather_odds/%s does not add up to 100" % r["id"])
    for r in data.get("structures", {}).values():
        ref("text", r["name"], "structures/%s" % r["id"])
        for st in r["repair_steps"]:
            ref("text", st["name"], "structures/%s step %s" % (r["id"], st["id"]))
            for m in st["materials"]:
                ref("items", m, "structures/%s step %s" % (r["id"], st["id"]))
        for s in r.get("shelf_stock", []) + r.get("found_supplies", []):
            ref("items", s["item"], "structures/%s supplies" % r["id"])
        if "repair_tool" in r:
            ref("items", r["repair_tool"], "structures/%s repair_tool" % r["id"])
    for r in data.get("landmarks", {}).values():
        ref("text", r["name"], "landmarks/%s" % r["id"])
        ref("structures", r["id"], "landmarks/%s" % r["id"]) if r["kind"] == "cabin" else None

    for r in data.get("recipes", {}).values():
        ref("text", r["name"], "recipes/%s" % r["id"])
        ref("items", r["result"]["item"], "recipes/%s result" % r["id"])
        for m in r["inputs"]:
            ref("items", m, "recipes/%s inputs" % r["id"])
    for r in data.get("items", {}).values():
        for m in r.get("covers", {}):
            ref("items", m, "items/%s covers" % r["id"])
    for r in data.get("obstacles", {}).values():
        ref("text", r["name"], "obstacles/%s" % r["id"])
        ref("items", r["tool"], "obstacles/%s tool" % r["id"])
    for r in data.get("jobs", {}).values():
        ref("text", r["title"], "jobs/%s title" % r["id"])
        ref("text", r["offer"], "jobs/%s offer" % r["id"])
        ref("structures", r["structure"], "jobs/%s" % r["id"])
        for it in r["tools"] + r["suggested"]:
            ref("items", it, "jobs/%s" % r["id"])
    for r in data.get("structures", {}).values():
        for s in r.get("starting_chest", []):
            ref("items", s["item"], "structures/%s starting_chest" % r["id"])
    for r in data.get("landmarks", {}).values():
        if "hint" in r:
            ref("text", r["hint"]["text"], "landmarks/%s hint" % r["id"])

    # Every text id named in GDScript code must exist in the text table.
    import re
    pat = re.compile(r'text\("([a-z0-9_]+)"\s*[,)]')
    for dirpath, _, files in os.walk(os.path.join(ROOT, "scripts")):
        for fn in files:
            if fn.endswith(".gd"):
                with open(os.path.join(dirpath, fn), encoding="utf-8") as f:
                    for m in pat.finditer(f.read()):
                        ref("text", m.group(1), "scripts/%s" % fn)

    if problems:
        for p in problems:
            print("DATA PROBLEM:", p)
        sys.exit(1)
    print("data check passed: %d tables, %d rows" % (len(data), sum(len(v) for v in data.values())))


if __name__ == "__main__":
    main()
