#!/usr/bin/env python3
"""Download the program's source recordings from Wikimedia Commons / Internet Archive,
verifying each file's SHA-1 against the Commons API, and record the license wikitext
that was read at download time. Output: assets_src/downloads/ and rights_manifest.json."""
import hashlib, json, pathlib, re, sys, urllib.parse, urllib.request
UA = {"User-Agent": "PicoSwanLakeCreditsCheck/1.0 (info@agilelens.com)"}
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets_src" / "downloads"
COMMONS = [
    ("grieg_morning", "Musopen - Morning.ogg"),
    ("handel_hornpipe", "Handel's Water Music - 12. Alla hornpipe - Chamber Orchestra - United States Marine Band.opus"),
    ("beethoven_storm", "Ludwig van Beethoven - symphony no. 6 in f major 'pastoral', op. 68 - iv. allegro.ogg"),
    ("beethoven_shepherd", "Ludwig van Beethoven - symphony no. 6 in f major 'pastoral', op. 68 - v. allegretto.ogg"),
    ("saintsaens_bokor", "Judith Bokor plays Le Cygne by Saint-Saëns.flac"),
    ("saintsaens_whitehouse", "20091104 Alisa Weilerstein and Jason Yoder - Saint Saëns' The Swan.ogg"),
    ("smetana_vltava", "Smetana, Má vlast - Vltava - The Moldau.ogg"),
    ("tchaikovsky_1812", "1812 Overture - United States Marine Band.opus"),
]
def api(**p):
    p.update(format="json")
    u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(p)
    return json.load(urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60))
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for key, title in COMMONS:
        r = api(action="query", titles="File:" + title, prop="imageinfo|revisions",
                iiprop="url|sha1|size|extmetadata", rvprop="content", rvslots="main")
        pg = next(iter(r["query"]["pages"].values()))
        if "imageinfo" not in pg:
            print("MISSING", title); continue
        ii = pg["imageinfo"][0]
        ext = pathlib.Path(title).suffix
        path = OUT / (key + ext)
        if not path.exists() or hashlib.sha1(path.read_bytes()).hexdigest() != ii["sha1"]:
            path.write_bytes(urllib.request.urlopen(urllib.request.Request(ii["url"], headers=UA), timeout=300).read())
        sha = hashlib.sha1(path.read_bytes()).hexdigest()
        wt = pg["revisions"][0]["slots"]["main"]["*"]
        manifest[key] = {"title": pg["title"], "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(pg["title"].replace(" ", "_")),
            "url": ii["url"].split("?")[0], "sha1": sha, "sha1_ok": sha == ii["sha1"], "license_short": ii["extmetadata"].get("LicenseShortName", {}).get("value", ""),
            "license_templates": re.findall(r"\{\{\s*((?:PD|Cc|CC|cc)[^}]*)\}\}", wt), "wikitext": wt[:1500]}
        print(key, sha == ii["sha1"], path.stat().st_size)
    (OUT / "rights_manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False))
main()
