"""Fetch demo data from Wikidata, with a fallback when the official SPARQL service is down.

    python tools/wikidata.py query QUERY.rq            > rows.json   # SPARQL -> list of {var: value}
    python tools/wikidata.py entities Q1490 Q34600 --langs en,fr,ja > entities.json

`query` tries query.wikidata.org first, then the QLever mirror (qlever.dev/api/wikidata).
QLever needs explicit PREFIX lines (wd:, wdt:, wikibase:, ...): include them in the query.
`entities` uses the Wikidata API (wbgetentities, 50 ids per call) and returns
{id: {labels: {lang: text}, coord: [lat, lon] | null, population: int | null, sitelinks: int}}.
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = "technote-localisation/1.0 (https://github.com/; demo data for a technical note)"
ENDPOINTS = ["https://query.wikidata.org/sparql", "https://qlever.dev/api/wikidata"]


def _get(url, accept="application/json", timeout=90, retries=4):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept})
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code not in (429, 503) or attempt == retries:
                raise
            wait = int(e.headers.get("Retry-After") or 0) or 5 * 2 ** attempt
            print(f"HTTP {e.code}, retrying in {wait}s", file=sys.stderr)
            time.sleep(min(wait, 120))


def query(sparql):
    last = None
    for ep in ENDPOINTS:
        try:
            data = _get(ep + "?" + urllib.parse.urlencode({"query": sparql}),
                        accept="application/sparql-results+json")
            print(f"source: {ep}", file=sys.stderr)
            return [{k: v["value"] for k, v in b.items()} for b in data["results"]["bindings"]]
        except Exception as e:  # noqa: BLE001 - try the next endpoint
            last = e
            print(f"{ep} failed: {e}", file=sys.stderr)
    raise SystemExit(f"all endpoints failed: {last}")


def _claim_values(claims, prop):
    out = []
    for c in claims.get(prop, []):
        snak = c.get("mainsnak", {})
        if snak.get("snaktype") == "value":
            out.append((c, snak["datavalue"]["value"]))
    return out


def _population(claims):
    vals = _claim_values(claims, "P1082")
    if not vals:
        return None
    preferred = [v for c, v in vals if c.get("rank") == "preferred"]
    if preferred:
        return int(float(preferred[0]["amount"]))

    def when(c):
        q = c.get("qualifiers", {}).get("P585", [])
        return q[0]["datavalue"]["value"]["time"] if q and "datavalue" in q[0] else ""
    c, v = max(vals, key=lambda cv: when(cv[0]))
    return int(float(v["amount"]))


def entities(ids, langs):
    out = {}
    for i in range(0, len(ids), 50):
        chunk = ids[i:i + 50]
        url = "https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode({
            "action": "wbgetentities", "format": "json", "ids": "|".join(chunk),
            "props": "labels|claims|sitelinks", "languages": "|".join(langs)})
        data = _get(url)
        for qid, e in data.get("entities", {}).items():
            claims = e.get("claims", {})
            coord = _claim_values(claims, "P625")
            out[qid] = {
                "labels": {l: e.get("labels", {}).get(l, {}).get("value", "") for l in langs},
                "coord": [coord[0][1]["latitude"], coord[0][1]["longitude"]] if coord else None,
                "population": _population(claims),
                "sitelinks": len(e.get("sitelinks", {})),
            }
        time.sleep(1)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    q = sub.add_parser("query")
    q.add_argument("file")
    e = sub.add_parser("entities")
    e.add_argument("ids", nargs="+")
    e.add_argument("--langs", default="en,fr,ja")
    a = ap.parse_args()
    if a.cmd == "query":
        result = query(open(a.file, encoding="utf-8").read())
    else:
        result = entities(a.ids, a.langs.split(","))
    json.dump(result, sys.stdout, ensure_ascii=False, indent=1)
    print()


if __name__ == "__main__":
    main()
