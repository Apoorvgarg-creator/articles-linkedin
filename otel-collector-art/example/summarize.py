#!/usr/bin/env python3
"""Read the two file exporters' output and print what each pipeline saw."""
import json
from collections import Counter
from pathlib import Path

out = Path(__file__).parent / "out"

def lines(name):
    p = out / name
    return [json.loads(l) for l in p.read_text().splitlines() if l.strip()] if p.exists() else []

def attrs(obj):
    return {a["key"]: next(iter(a["value"].values()), None) for a in obj.get("attributes", [])}

print("== traces/vendor (what your paid backend receives) ==")
routes = Counter()
sample = None
for batch in lines("vendor.json"):
    for rs in batch.get("resourceSpans", []):
        for ss in rs.get("scopeSpans", []):
            for span in ss.get("spans", []):
                a = attrs(span)
                routes[a.get("http.route")] += 1
                if a.get("http.route") == "/checkout" and sample is None:
                    sample = a
print("spans by route:", dict(routes))
if sample:
    print("sample /checkout attributes:")
    for k, v in sorted(sample.items()):
        print(f"  {k} = {v}")

print()
print("== metrics/counts (fed by the count connector, before filtering) ==")
totals = Counter()
for batch in lines("counts.json"):
    for rm in batch.get("resourceMetrics", []):
        for sm in rm.get("scopeMetrics", []):
            for m in sm.get("metrics", []):
                for dp in m.get("sum", {}).get("dataPoints", []):
                    totals[(m["name"], attrs(dp).get("http.route"))] += int(dp.get("asInt", 0))
for (name, route), n in sorted(totals.items()):
    print(f"{name}{{http.route=\"{route}\"}} = {n}")
