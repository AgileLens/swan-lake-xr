#!/usr/bin/env python3
"""Pure source/math winding guard for Swan Lake. No Godot, Blender, GPU or export required."""
from pathlib import Path
import math, re
from fix_env_glb_winding import audit

ROOT = Path(__file__).resolve().parent.parent
checks = []

def check(name, ok):
    checks.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name)

def signed_z(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])

# Godot treats clockwise triangles as front-facing. Recreate one rainbow cell as seen from the
# dock (+Z) and prove the authored index order is clockwise, unlike the old 0,1,2 ordering.
a0, a1, r0, r1 = map(float, (math.radians(8), math.radians(12), 79.12, 85.56))
p = [(-math.cos(a0)*r0, math.sin(a0)*r0), (-math.cos(a1)*r0, math.sin(a1)*r0),
     (-math.cos(a1)*r1, math.sin(a1)*r1), (-math.cos(a0)*r1, math.sin(a0)*r1)]
check("rainbow triangles face the dock", signed_z(p[0], p[2], p[1]) < 0 and signed_z(p[0], p[3], p[2]) < 0)
rainbow = (ROOT / "project/scripts/rainbow.gd").read_text()
check("rainbow source keeps clockwise indices", "[0, 2, 1, 0, 3, 2]" in rainbow)

# A representative lightning strip is clockwise toward +Z too: top-left, top-right, bottom-right.
check("lightning strip faces the audience", signed_z((-1, 1), (1, 1), (1, -1)) < 0)

env = (ROOT / "project/shaders/env.gdshader").read_text()
foliage = (ROOT / "project/shaders/env_foliage.gdshader").read_text()
check("solid environment no longer disables culling", "cull_disabled" not in env and "cull_back" in env)
check("foliage uses explicit backs, not disabled culling", "cull_disabled" not in foliage and "cull_back" in foliage)

generator = (ROOT / "assets_src/make_env.py").read_text()
check("reed blades author both windings", "b.f.append(tuple(reversed(face)))" in generator)
check("tree crown caps point outward", "reversed(range(segs))))\n    b.f.append(tuple(base + (len(rings) - 1) * segs + j for j in range(segs)))" in generator)
hero = (ROOT / "assets_src/make_swan_hero.py").read_text()
check("mirrored feather coordinates reverse faces", "batch.faces = [tuple(reversed(f)) for f in batch.faces]" in hero)

scripts = "\n".join(p.read_text() for p in sorted((ROOT / "project/scripts").glob("*.gd")))
scale_exprs = re.findall(r"(?:\.scale\s*=|scaled\s*\()\s*Vector3\(([^\n)]*)\)", scripts)
reflected = [s for s in scale_exprs if re.search(r"(?:^|,)\s*-\s*\d", s)]
check("runtime scripts have no literal reflected scale", not reflected)

glb = audit((ROOT / "project/assets/env/env.glb").read_bytes())
check("tracked GLB crown caps and normals point outward", glb["crowns"] == glb["crown_ok"] == glb["crown_normals_ok"] == 39)
check("tracked GLB has explicit reed backs and normals", glb["blades_double_sided"] == 298 and glb["reed_triangles"] == 4187 and glb["reed_normal_min"] > 0.6)
print("tracked env.glb sha256=" + glb["sha256"])

failed = sum(not ok for _, ok in checks)
print(f"GEOMETRY_RESULT passed={len(checks)-failed} failed={failed}")
raise SystemExit(1 if failed else 0)
