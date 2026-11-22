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
TABLES = ["items", "foods", "weather_types", "weather_odds", "structures", "landmarks", "jobs", "obstacles", "recipes", "sites", "notes", "text", "spoiler_finds", "spoiler_text", "art_variety", "forage", "skills", "specialties", "magic_variants", "ideas", "spoiler_magic", "facilities", "placeables", "catalog", "income_sources", "visitor_types", "staff_roles", "staff_people", "badger_mischief", "suggestion_cards", "chief_letters", "pads", "spoiler_pads", "spoiler_cards", "job_types", "givers", "job_steps", "rewards", "job_templates", "job_spots", "spoiler_jobs", "spoiler_job_spots", "noticeables", "spoiler_more", "music", "townsfolk", "town_places", "routines", "gift_tastes", "dialogue", "spoiler_dialogue", "shops", "town_interiors", "books"]


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

    # The hidden things' text is kept apart but read like any other text.
    for rid, r in data.get("spoiler_text", {}).items():
        if rid in data.get("text", {}):
            problems.append("text %s is in both text tables" % rid)
        data.setdefault("text", {})[rid] = r

    def ref(table, rid, where):
        if rid not in data.get(table, {}):
            problems.append("%s points at missing %s row '%s'" % (where, table, rid))

    for r in data.get("items", {}).values():
        ref("text", r["name"], "items/%s name" % r["id"])
    for r in data.get("art_variety", {}).values():
        if len(r["pictures"]) != len(r["weights"]) or min(r["weights"]) <= 0:
            problems.append("art_variety/%s: one positive weight per picture" % r["id"])
        for n in r["pictures"] + r.get("details", []):
            if not any(os.path.exists(os.path.join(ROOT, "art", d, n + ".png")) for d in ("final", "placeholder")):
                problems.append("art_variety/%s: no picture %s" % (r["id"], n))
    for r in data.get("structures", {}).values():
        inside = r.get("interior")
        if not inside:
            continue
        names = [inside[k] for k in ("floor", "wall", "wall_base", "trim") if k in inside]
        names += [d["sprite"] for d in inside.get("decor", []) + inside.get("rugs", []) + inside["furniture"]]
        for n in names:
            if not any(os.path.exists(os.path.join(ROOT, "art", d, n + ".png")) for d in ("final", "placeholder")):
                problems.append("structures/%s interior: no picture %s" % (r["id"], n))
        w, h = inside["size"]
        wh = inside.get("wall_height", 1)
        for f in inside["furniture"]:
            x, y = f["pos"]
            fw, fh = f["size"]
            if f["kind"] == "exit":
                if not (y == h - 1 and 0 < x < w - 1):
                    problems.append("structures/%s interior: the door must be in the bottom border" % r["id"])
            elif x < 1 or y < wh or x + fw > w - 1 or y + fh > h - 1:
                problems.append("structures/%s interior: %s is outside the floor" % (r["id"], f["id"]))
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

    for r in data.get("spoiler_finds", {}).values():
        ref("text", r["text"], "spoiler_finds/%s" % r["id"])
        for g in r.get("gives", []):
            ref("items", g["item"], "spoiler_finds/%s gives" % r["id"])
        if "item" in r:
            ref("items", r["item"], "spoiler_finds/%s item" % r["id"])
    for r in data.get("notes", {}).values():
        ref("text", r["text"], "notes/%s" % r["id"])
        ref("structures", r["at"], "notes/%s at" % r["id"])
        ref("structures", r["needs_open"], "notes/%s needs_open" % r["id"])
        for lm in r["rumors"]:
            ref("landmarks", lm, "notes/%s rumors" % r["id"])
    # Phase 3: the park.
    def pic(n, where):
        if not any(os.path.exists(os.path.join(ROOT, "art", d, n + ".png")) for d in ("final", "placeholder")):
            problems.append("%s: no picture %s" % (where, n))
    for r in data.get("facilities", {}).values():
        ref("text", r["name"], "facilities/%s name" % r["id"])
        pic(r["sprite"], "facilities/%s" % r["id"])
        if "sprite_badger" in r:
            pic(r["sprite_badger"], "facilities/%s" % r["id"])
    for t in ("pads", "spoiler_pads"):
        for r in data.get(t, {}).values():
            ref("facilities", r["facility"], "%s/%s facility" % (t, r["id"]))
            if r["site"] != "gate":
                ref("sites", r["site"], "%s/%s site" % (t, r["id"]))
    for r in data.get("placeables", {}).values():
        ref("items", r["item"], "placeables/%s item" % r["id"])
        for k in ("sprite", "sprite_full", "sprite_tipped", "sprite_lit"):
            if k in r:
                pic(r[k], "placeables/%s" % r["id"])
    for r in data.get("catalog", {}).values():
        ref("text", r["name"], "catalog/%s name" % r["id"])
        if r["kind"] == "kit":
            ref("facilities", r["facility"], "catalog/%s facility" % r["id"])
        else:
            ref("items", r["item"], "catalog/%s item" % r["id"])
        if int(r["price"]) <= 0:
            problems.append("catalog/%s: needs a price" % r["id"])
    for r in data.get("income_sources", {}).values():
        ref("text", r["name"], "income_sources/%s name" % r["id"])
    for r in data.get("visitor_types", {}).values():
        ref("text", r["name"], "visitor_types/%s name" % r["id"])
    for r in data.get("staff_roles", {}).values():
        ref("text", r["name"], "staff_roles/%s name" % r["id"])
    for r in data.get("staff_people", {}).values():
        for k in ("name", "line", "goodbye"):
            ref("text", r[k], "staff_people/%s %s" % (r["id"], k))
        ref("staff_roles", r["suits"], "staff_people/%s suits" % r["id"])
    for t in ("badger_mischief", "suggestion_cards", "chief_letters", "spoiler_cards"):
        for r in data.get(t, {}).values():
            ref("text", r["text"], "%s/%s text" % (t, r["id"]))
    for r in data.get("items", {}).values():
        if r.get("kind") == "gift" and int(r.get("sell", 0)) <= 0:
            problems.append("items/%s: a gift good needs a selling price" % r["id"])

    for r in data.get("sites", {}).values():
        ref("text", r["name"], "sites/%s" % r["id"])
        if r["structure"] != "":
            ref("structures", r["structure"], "sites/%s structure" % r["id"])
        elif "spot" not in r:
            problems.append("sites/%s: a site with no building needs a spot" % r["id"])
        ref("landmarks", r["landmark"], "sites/%s landmark" % r["id"])
    items = data.get("items", {})

    def pic(name, where):
        if not any(os.path.exists(os.path.join(ROOT, "art", d, name + ".png")) for d in ("final", "placeholder")):
            problems.append("%s: no picture %s" % (where, name))

    def effects(list_, where):
        for e in list_:
            if "key" not in e or sum(op in e for op in ("set", "add", "mult")) != 1:
                problems.append("%s: an effect needs a key and exactly one of set, add or mult" % where)

    for r in data.get("recipes", {}).values():
        ref("text", r["name"], "recipes/%s" % r["id"])
        for m in r["inputs"]:
            ref("items", m, "recipes/%s inputs" % r["id"])
        if r["station"] not in ("anywhere", "workbench", "fire"):
            problems.append("recipes/%s: station must be anywhere, workbench or fire" % r["id"])
        if r.get("learned") not in ("start", "skill", "idea"):
            problems.append("recipes/%s: learned must be start, skill or idea" % r["id"])
        if "tool" in r:
            ref("items", r["tool"], "recipes/%s tool" % r["id"])
        if "refit" in r:
            if not any(i.get("family") == r["refit"] for i in items.values()):
                problems.append("recipes/%s: no tool of family %s" % (r["id"], r["refit"]))
            if not any(v["recipe"] == r["id"] for v in data.get("magic_variants", {}).values()):
                problems.append("recipes/%s: a refit needs a magic_variants row" % r["id"])
        elif "item" in r["result"]:
            ref("items", r["result"]["item"], "recipes/%s result" % r["id"])
        elif r["result"].get("effect") != "pack_frame":
            problems.append("recipes/%s: result needs an item or the pack_frame effect" % r["id"])
    for r in data.get("magic_variants", {}).values():
        ref("recipes", r["recipe"], "magic_variants/%s recipe" % r["id"])
        ref("items", r["ingredient"], "magic_variants/%s ingredient" % r["id"])
        ref("items", r["result"], "magic_variants/%s result" % r["id"])
        if items.get(r["ingredient"], {}).get("kind") != "magic":
            problems.append("magic_variants/%s: %s is not a magical ingredient" % (r["id"], r["ingredient"]))
    taught = set()
    for r in data.get("ideas", {}).values():
        if "item" in r:
            ref("items", r["item"], "ideas/%s item" % r["id"])
        elif r.get("trigger") not in ("gift_shelf",):
            problems.append("ideas/%s: needs an item or a known trigger" % r["id"])
        ref("text", r["text"], "ideas/%s text" % r["id"])
        for rid in r["recipes"]:
            ref("recipes", rid, "ideas/%s recipes" % r["id"])
            taught.add(rid)
    seasons = {"spring", "summer", "autumn", "winter"}
    for r in data.get("forage", {}).values():
        ref("items", r["item"], "forage/%s item" % r["id"])
        src = r.get("source", "ground")
        if src not in ("ground", "object", "buried"):
            problems.append("forage/%s: source must be ground, object or buried" % r["id"])
        if src == "ground":
            pic(r["sprite"], "forage/%s" % r["id"])
        if "overlay" in r:
            pic(r["overlay"], "forage/%s overlay" % r["id"])
        if not set(r["seasons"]) <= seasons or not r["seasons"]:
            problems.append("forage/%s: seasons must be some of %s" % (r["id"], sorted(seasons)))
        if r.get("magic"):
            if items.get(r["item"], {}).get("kind") != "magic":
                problems.append("forage/%s: a magic row must give a magical ingredient" % r["id"])
            if r["id"] not in data.get("spoiler_magic", {}):
                problems.append("forage/%s: a magic row needs its places in spoiler_magic" % r["id"])
            ref("text", "find_" + r["item"], "forage/%s find" % r["id"])
        elif src == "ground":
            for k in ("where", "chance", "active_share", "bake_share"):
                if k not in r:
                    problems.append("forage/%s: a ground row needs %s" % (r["id"], k))
        elif src == "object" and not ("objects" in r and "refresh" in r):
            problems.append("forage/%s: an object row needs objects and refresh" % r["id"])
    for r in data.get("skills", {}).values():
        ref("text", r["name"], "skills/%s" % r["id"])
        for p in r["perks"]:
            ref("text", p["text"], "skills/%s perk %d" % (r["id"], p["level"]))
            effects(p.get("effects", []), "skills/%s perk %d" % (r["id"], p["level"]))
            for rid in p.get("recipes", []):
                ref("recipes", rid, "skills/%s perk %d" % (r["id"], p["level"]))
                taught.add(rid)
        n = sum(1 for sp in data.get("specialties", {}).values() if sp["skill"] == r["id"])
        if n != 2:
            problems.append("skills/%s: two specialties, found %d" % (r["id"], n))
    for r in data.get("specialties", {}).values():
        ref("skills", r["skill"], "specialties/%s" % r["id"])
        ref("text", r["name"], "specialties/%s" % r["id"])
        ref("text", r["desc"], "specialties/%s desc" % r["id"])
        effects(r["effects"], "specialties/%s" % r["id"])
    for r in data.get("recipes", {}).values():
        if r["learned"] != "start" and r["id"] not in taught:
            problems.append("recipes/%s: learned by %s, but nothing teaches it" % (r["id"], r["learned"]))
    for r in items.values():
        if "family" in r and r["family"] not in items:
            problems.append("items/%s: family %s is not an item" % (r["id"], r["family"]))
        if r["kind"] == "food" and r["id"] not in data.get("foods", {}):
            problems.append("items/%s: a food needs a foods row" % r["id"])
        if r["kind"] == "placeable" and "sprite" in r:
            pic(r["sprite"], "items/%s" % r["id"])
        pic(r["icon"], "items/%s icon" % r["id"])
    for r in data.get("items", {}).values():
        for m in r.get("covers", {}):
            ref("items", m, "items/%s covers" % r["id"])
    for r in data.get("obstacles", {}).values():
        ref("text", r["name"], "obstacles/%s" % r["id"])
        ref("items", r["tool"], "obstacles/%s tool" % r["id"])
    # Jobs: every name, note and step label is text; every type, giver,
    # reward kind and step kind is a real row; handy things are items.
    texts_all = dict(data.get("text", {}))
    texts_all.update(data.get("spoiler_text", {}))
    for table in ("jobs", "spoiler_jobs"):
        for r in data.get(table, {}).values():
            for k in ("name", "note"):
                if r[k] not in texts_all:
                    problems.append("%s/%s: no text %s" % (table, r["id"], r[k]))
            ref("job_types", r["type"], "%s/%s type" % (table, r["id"]))
            ref("givers", r.get("giver", data["job_types"][r["type"]]["giver"]) if r["type"] in data.get("job_types", {}) else r["type"], "%s/%s giver" % (table, r["id"]))
            for it in r.get("handy", []):
                ref("items", it, "%s/%s handy" % (table, r["id"]))
            for st in r["steps"]:
                ref("job_steps", st["kind"], "%s/%s step" % (table, r["id"]))
                if st["label"] not in texts_all:
                    problems.append("%s/%s: no text %s" % (table, r["id"], st["label"]))
            for rw in r["rewards"]:
                ref("rewards", rw["kind"], "%s/%s reward" % (table, r["id"]))
                if rw["kind"] == "job" and rw["job"] not in data.get("jobs", {}):
                    problems.append("%s/%s: reward job %s is not a job" % (table, r["id"], rw["job"]))
                if rw["kind"] == "xp":
                    ref("skills", rw["skill"], "%s/%s reward" % (table, r["id"]))
            if r.get("more") and r["more"] not in data.get("spoiler_more", {}):
                problems.append("%s/%s: no something more %s" % (table, r["id"], r["more"]))
    for r in data.get("job_templates", {}).values():
        if r["name"] not in texts_all:
            problems.append("job_templates/%s: no text %s" % (r["id"], r["name"]))
        for n in r["notes"]:
            if n not in texts_all:
                problems.append("job_templates/%s: no text %s" % (r["id"], n))
        for st in r["steps"]:
            ref("job_steps", st["kind"], "job_templates/%s step" % r["id"])
    for r in data.get("noticeables", {}).values():
        if r["job"] not in data.get("spoiler_jobs", {}):
            problems.append("noticeables/%s: no job %s" % (r["id"], r["job"]))
    for r in data.get("structures", {}).values():
        for s in r.get("starting_chest", []):
            ref("items", s["item"], "structures/%s starting_chest" % r["id"])
    for r in data.get("landmarks", {}).values():
        if "hint" in r:
            ref("text", r["hint"]["text"], "landmarks/%s hint" % r["id"])

    # Phase 4, step 5: shops, their rooms and the library's books.
    for r in data.get("shops", {}).values():
        if r["id"] not in data.get("town_places", {}):
            problems.append("shops/%s: not a town place" % r["id"])
        for it in r.get("sells", []):
            ref("items", it["item"], "shops/%s sells" % r["id"])
            if it.get("here") and it["item"] not in data.get("foods", {}):
                problems.append("shops/%s: %s is eaten here but is not a food" % (r["id"], it["item"]))
        for it in r.get("buys", {}).get("prices", {}):
            ref("items", it, "shops/%s buys" % r["id"])
        if r["id"] not in data.get("town_interiors", {}):
            problems.append("shops/%s: no room in town_interiors" % r["id"])
    for r in data.get("town_interiors", {}).values():
        if r["id"] not in data.get("town_places", {}):
            problems.append("town_interiors/%s: not a town place" % r["id"])
    for r in data.get("books", {}).values():
        if r.get("teaches"):
            ref("recipes", r["teaches"], "books/%s teaches" % r["id"])

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
