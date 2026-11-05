# The lake's surroundings: dock, near bank, forested shore, far ridges, reeds, lily pads.
#
#   Blender --background --factory-startup --python assets_src/make_env.py
#
# The program now plays in full daylight, where the old black spheres and cones would be
# obvious, so the shore became real terrain. Everything is vertex colored, on one material,
# merged per region so it stays a handful of draw calls.
#
# Vertex color: rgb = albedo, a = wind sway weight (reeds and treetops). UV.x = emission.
# Godot axes after export: Blender +Y is Godot -Z. The dock runs along Blender Y.
import bpy, math, os, random
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "project", "assets", "env")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.context.scene.collection
R = random.Random(11)
LAKE = np.array([0.0, 10.0])  # lake center, in Blender XY

class Batch:
    def __init__(self, name):
        self.name, self.v, self.f, self.c, self.uv = name, [], [], [], []

    def quad_grid(self, verts, colors, rows, cols, emis=0.0):
        base = len(self.v)
        for p, c in zip(verts, colors):
            self.v.append(tuple(p))
            self.c.append(tuple(c))
            self.uv.append((emis, 0.0))
        for i in range(rows - 1):
            for j in range(cols - 1):
                a = base + i * cols + j
                self.f.append((a, a + 1, a + cols + 1, a + cols))

    def box(self, cx, cy, cz, sx, sy, sz, color, emis=0.0, wobble=0.0):
        base = len(self.v)
        pts = []
        for dz in (-1, 1):
            for dy in (-1, 1):
                for dx in (-1, 1):
                    w = (R.uniform(-wobble, wobble), R.uniform(-wobble, wobble), R.uniform(-wobble, wobble)) if wobble else (0, 0, 0)
                    pts.append((cx + dx * sx / 2 + w[0], cy + dy * sy / 2 + w[1], cz + dz * sz / 2 + w[2]))
        for p in pts:
            self.v.append(p)
            self.c.append(tuple(color) + (0.0,))
            self.uv.append((emis, 0.0))
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self.f.append(tuple(base + i for i in f))

    def cylinder(self, cx, cy, z0, z1, r0, r1, color, segs=8, wind=0.0, emis=0.0, jitter=0.0):
        base = len(self.v)
        for k, (z, r) in enumerate(((z0, r0), (z1, r1))):
            for j in range(segs):
                a = 2 * math.pi * j / segs
                rr = r * (1.0 + R.uniform(-jitter, jitter))
                self.v.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, z))
                self.c.append(tuple(color) + (wind * k,))
                self.uv.append((emis, 0.0))
        for j in range(segs):
            a, b = base + j, base + (j + 1) % segs
            self.f.append((a, b, b + segs, a + segs))
        # Top cap, so a post seen from above is not hollow.
        if r1 > 0.001:
            self.f.append(tuple(base + segs + j for j in range(segs)))

    def cone(self, cx, cy, z0, z1, r, color_low, color_tip, segs=6, wind=0.0):
        base = len(self.v)
        for j in range(segs):
            a = 2 * math.pi * j / segs + 0.3
            self.v.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z0))
            self.c.append(tuple(color_low) + (0.0,))
            self.uv.append((0.0, 0.0))
        self.v.append((cx, cy, z1))
        self.c.append(tuple(color_tip) + (wind,))
        self.uv.append((0.0, 0.0))
        for j in range(segs):
            self.f.append((base + j, base + (j + 1) % segs, base + segs))

    def to_object(self):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.v, [], self.f)
        me.update()
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = self.uv[me.loops[li].vertex_index]
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        arr = np.array(self.c, dtype=float).ravel()
        ca.data.foreach_set("color", arr)
        ob = bpy.data.objects.new(self.name, me)
        col.objects.link(ob)
        print("[env]", self.name, "tris", sum(len(p.vertices) - 2 for p in me.polygons))
        return ob

def smooth_noise(x, seed):
    s = 0.0
    a = 1.0
    f = 1.0
    for k in range(5):
        s += a * math.sin(x * f + seed * (k + 1) * 1.7 + math.sin(x * f * 0.6 + seed) * 1.3)
        a *= 0.55
        f *= 1.9
    return s

def shore_radius(a):
    """Shoreline distance from the lake center at bearing a. a = +pi/2 points toward the dock."""
    toward_dock = max(math.cos(a - math.pi * -0.5), 0.0)
    r = 100.0 + 12.0 * smooth_noise(a * 2.0, 1.3)
    # The near bank comes in close behind the dock.
    return r * (1.0 - toward_dock ** 3) + 19.5 * toward_dock ** 3 + toward_dock ** 3 * 0.8 * smooth_noise(a * 6.0, 2.1)

def height_at(a, d):
    """Terrain height at bearing a, d meters inland from the shoreline."""
    base = 1.0 + 0.05 * d + 0.0022 * d * d
    hills = (smooth_noise(a * 3.1, 4.1) * 0.5 + 0.5) * 16.0 * min(d / 40.0, 1.0)
    return base + hills

GRASS_NEAR = (0.150, 0.235, 0.085)
FOREST = (0.055, 0.105, 0.060)
SAND = (0.34, 0.31, 0.24)
PINE_A = (0.030, 0.075, 0.048)
PINE_B = (0.045, 0.100, 0.052)
TIP = (0.070, 0.135, 0.070)
DECID_A = (0.085, 0.145, 0.055)
DECID_B = (0.150, 0.170, 0.060)

def build_terrain():
    b = Batch("Terrain")
    SEG = 180
    STEPS = [-1.2, 0.0, 0.8, 2.0, 5.0, 12.0, 24.0, 44.0, 70.0, 110.0]
    verts, cols = [], []
    for j in range(SEG + 1):
        a = 2 * math.pi * j / SEG
        rs = shore_radius(a)
        for d in STEPS:
            r = rs + d
            x, y = LAKE[0] + math.cos(a) * r, LAKE[1] + math.sin(a) * r
            if d <= 0.0:
                z = d * 0.4
            else:
                z = height_at(a, d)
            n = 0.5 + 0.5 * smooth_noise(a * 11.0 + d * 0.13, 7.7)
            if d <= 0.9:
                c = SAND
            elif d <= 2.5:
                t = (d - 0.9) / 1.6
                c = tuple(SAND[k] * (1 - t) + GRASS_NEAR[k] * t for k in range(3))
            else:
                t = min((d - 2.5) / 12.0, 1.0)
                c = tuple(GRASS_NEAR[k] * (1 - t) + FOREST[k] * t for k in range(3))
            c = tuple(c[k] * (0.85 + 0.3 * n) for k in range(3))
            verts.append((x, y, z))
            cols.append(c + (0.0,))
    b.quad_grid(verts, cols, SEG + 1, len(STEPS))
    return b

def build_ridges():
    """Layered far mountains. Scene fog gives them aerial perspective."""
    b = Batch("Ridges")
    SEG = 120
    for layer, (r, hmin, hmax, seed, tone) in enumerate(((250.0, 26.0, 68.0, 3.3, (0.070, 0.110, 0.095)), (340.0, 48.0, 118.0, 5.1, (0.080, 0.105, 0.115)))):
        verts, cols = [], []
        for j in range(SEG + 1):
            a = 2 * math.pi * j / SEG
            n = smooth_noise(a * 4.0, seed) * 0.5 + 0.5 + 0.12 * smooth_noise(a * 19.0, seed + 1)
            h = hmin + (hmax - hmin) * max(n, 0.0)
            for t, rad_k in ((0.0, 0.84), (0.72, 0.97), (1.0, 1.0)):
                rr = r * rad_k
                verts.append((LAKE[0] + math.cos(a) * rr, LAKE[1] + math.sin(a) * rr, h * t))
                k = 0.7 + 0.5 * t
                cols.append((tone[0] * k, tone[1] * k, tone[2] * k, 0.0))
        b.quad_grid(verts, cols, SEG + 1, 3)
    return b

def conifer(b, x, y, z, h, tone_k):
    w = h * 0.26
    b.cylinder(x, y, z - 0.2, z + h * 0.15, h * 0.03, h * 0.02, (0.08, 0.06, 0.045), segs=4)
    c = tuple(v * tone_k for v in (PINE_A if R.random() < 0.5 else PINE_B))
    t = tuple(v * tone_k for v in TIP)
    b.cone(x, y, z + h * 0.12, z + h * 0.62, w, c, t, segs=6, wind=0.0)
    b.cone(x, y, z + h * 0.36, z + h * 0.82, w * 0.74, c, t, segs=6, wind=0.0)
    b.cone(x, y, z + h * 0.58, z + h, w * 0.5, c, t, segs=5, wind=0.6)

def round_tree(b, x, y, z, h, tone_k):
    # A faceted crown. Reads as broadleaf at shoreline distance for few triangles.
    b.cylinder(x, y, z - 0.2, z + h * 0.45, h * 0.035, h * 0.022, (0.09, 0.07, 0.05), segs=4)
    c = tuple(v * tone_k for v in (DECID_A if R.random() < 0.55 else DECID_B))
    t = tuple(min(v * tone_k * 1.5, 1) for v in (DECID_B))
    rad = h * 0.30
    zc = z + h * 0.62
    base = len(b.v)
    segs = 6
    rings = [(-0.9, 0.42), (-0.3, 0.98), (0.35, 0.90), (0.85, 0.42)]
    for ri, (zk, rk) in enumerate(rings):
        for j in range(segs):
            a = 2 * math.pi * j / segs + ri * 0.5
            b.v.append((x + math.cos(a) * rad * rk * R.uniform(0.9, 1.1), y + math.sin(a) * rad * rk * R.uniform(0.9, 1.1), zc + zk * rad))
            shade = 0.55 + 0.45 * (ri / 3.0)
            cc = tuple(c[k] * (1 - ri / 3.0) + t[k] * (ri / 3.0) for k in range(3))
            b.c.append((cc[0] * shade, cc[1] * shade, cc[2] * shade, 0.25 * ri / 3.0))
            b.uv.append((0.0, 0.0))
    for ri in range(len(rings) - 1):
        for j in range(segs):
            a, bb = base + ri * segs + j, base + ri * segs + (j + 1) % segs
            b.f.append((a, bb, bb + segs, a + segs))
    # Bottom faces down, top faces up. These were reversed and only visible because the shared
    # environment shader disabled culling for the entire scene.
    b.f.append(tuple(base + j for j in reversed(range(segs))))
    b.f.append(tuple(base + (len(rings) - 1) * segs + j for j in range(segs)))

def build_trees():
    b = Batch("Trees")
    for j in range(560):
        a = R.uniform(0, 2 * math.pi)
        d = R.uniform(3.0, 34.0) * R.uniform(0.5, 1.0)
        rs = shore_radius(a)
        x, y = LAKE[0] + math.cos(a) * (rs + d), LAKE[1] + math.sin(a) * (rs + d)
        z = height_at(a, d)
        # Keep clear of the end of the dock, so the near bank has a little clearing.
        if math.hypot(x, y + 4.8) < 7.0:
            continue
        h = R.uniform(8.0, 18.0)
        k = R.uniform(0.8, 1.15)
        if R.random() < 0.94:
            conifer(b, x, y, z, h, k)
        else:
            round_tree(b, x, y, z, h * 0.8, k)
    return b

def reed(b, x, y, h, lean, tone):
    """One tapered blade: two quads with a bend, with sway weight rising along it."""
    dirx, diry = math.cos(lean), math.sin(lean)
    px, py = -diry, dirx
    w = R.uniform(0.008, 0.014)
    base = len(b.v)
    for k in range(4):
        t = k / 3.0
        cx = x + dirx * t * t * h * 0.18
        cy = y + diry * t * t * h * 0.18
        z = -0.03 + t * h
        ww = w * (1.0 - t * 0.85)
        for s in (-1, 1):
            b.v.append((cx + px * ww * s, cy + py * ww * s, z))
            light = 0.65 + 0.5 * t
            b.c.append((tone[0] * light, tone[1] * light, tone[2] * light, t * t))
            b.uv.append((0.0, 0.0))
    for k in range(3):
        a = base + k * 2
        face = (a, a + 1, a + 3, a + 2)
        # A reed is a zero-thickness blade, not a closed solid. Author both sides explicitly so
        # its two-sided intent is geometry-local instead of a global culling workaround.
        b.f.append(face)
        b.f.append(tuple(reversed(face)))

def cattail(b, x, y, h, tone):
    reed(b, x, y, h, R.uniform(0, 6.28), tone)
    b.cylinder(x, y, h * 0.70, h * 0.86, 0.016, 0.016, (0.17, 0.095, 0.045), segs=5, wind=0.8)

def build_reeds():
    b = Batch("Reeds")
    reed_a = (0.17, 0.26, 0.09)
    reed_b = (0.24, 0.30, 0.11)
    clumps = [(-2.6, 0.2, 18), (2.9, -0.4, 16), (-3.8, 2.4, 22), (3.6, 2.2, 22), (-5.4, 4.4, 30), (5.2, 4.7, 26),
              (-8.8, 5.8, 32), (8.4, 6.2, 32), (-4.6, -3.4, 14), (6.6, -5.8, 18), (-12.0, 4.2, 34), (12.4, 3.6, 34)]
    for cx, cy, n in clumps:
        for i in range(n):
            x = cx + R.gauss(0, 0.42)
            y = cy + R.gauss(0, 0.42)
            h = R.uniform(0.75, 1.45)
            tone = reed_a if R.random() < 0.5 else reed_b
            if R.random() < 0.14:
                cattail(b, x, y, h * 1.15, tone)
            else:
                reed(b, x, y, h, R.uniform(0, 6.28), tone)
    return b

def build_lilies():
    b = Batch("Lilies")
    pad = (0.070, 0.175, 0.070)
    petals = [(0.95, 0.95, 0.92), (0.96, 0.78, 0.84)]
    for cx, cy, n in ((-2.0, -1.6, 7), (2.3, -2.0, 8), (-3.4, -3.0, 6), (3.6, -3.4, 7), (-5.5, 1.2, 9), (5.0, 0.8, 8)):
        for i in range(n):
            x = cx + R.gauss(0, 0.65)
            y = cy + R.gauss(0, 0.65)
            r = R.uniform(0.09, 0.20)
            segs = 9
            notch = R.uniform(0, 6.28)
            base = len(b.v)
            b.v.append((x, y, 0.016))
            b.c.append((pad[0] * 1.15, pad[1] * 1.15, pad[2] * 1.15, 0.0))
            b.uv.append((0.0, 0.0))
            for j in range(segs):
                a = notch + 0.3 + (2 * math.pi - 0.6) * j / (segs - 1)
                b.v.append((x + math.cos(a) * r, y + math.sin(a) * r, 0.016))
                b.c.append((pad[0], pad[1], pad[2], 0.0))
                b.uv.append((0.0, 0.0))
            for j in range(segs - 1):
                b.f.append((base, base + 1 + j, base + 2 + j))
            if R.random() < 0.28:
                p = petals[R.randrange(2)]
                fb = len(b.v)
                pn = 7
                for j in range(pn):
                    a = 2 * math.pi * j / pn
                    b.v.append((x + math.cos(a) * 0.055, y + math.sin(a) * 0.055, 0.075))
                    b.c.append(p + (0.0,))
                    b.uv.append((0.0, 0.0))
                b.v.append((x, y, 0.035))
                b.c.append((0.85, 0.70, 0.20, 0.0))
                b.uv.append((0.0, 0.0))
                for j in range(pn):
                    b.f.append((fb + j, fb + (j + 1) % pn, fb + pn))
    return b

def build_dock():
    b = Batch("Dock")
    # Planks across a deck 2.4 m wide. Godot z runs 2.6 .. -1.4, Blender y -2.6 .. 1.4.
    TOP = 0.35
    y = -6.4
    while y < 1.4:
        w = R.uniform(0.15, 0.19)
        k = R.uniform(0.78, 1.14)
        tone = (0.235 * k, 0.165 * k, 0.105 * k)
        b.box(R.uniform(-0.01, 0.01), y + w / 2, TOP - 0.022 + R.uniform(-0.003, 0.003), 2.40 + R.uniform(-0.05, 0.05), w - 0.010, 0.044, tone, wobble=0.0015)
        y += w
    # Stringers and cross bracing below the deck.
    for sx in (-1.0, 0.0, 1.0):
        b.box(sx, -2.5, TOP - 0.11, 0.09, 7.9, 0.13, (0.13, 0.095, 0.065))
    # Posts with a slight lean, darker and wet near the waterline.
    for py in (1.25, -0.8, -2.85, -4.9, -6.3):
        for sx in (-1.18, 1.18):
            b.cylinder(sx, py, -0.5, TOP + 0.34, 0.082, 0.072, (0.15, 0.105, 0.070), segs=9, jitter=0.03)
            b.cylinder(sx, py, -0.5, 0.05, 0.088, 0.086, (0.055, 0.050, 0.040), segs=9)
    # Rope wrap on the two front posts, then a coil on the deck.
    for sx in (-1.18, 1.18):
        for k in range(4):
            b.cylinder(sx, 1.25, TOP + 0.13 + k * 0.024, TOP + 0.13 + k * 0.024 + 0.021, 0.094, 0.094, (0.46, 0.38, 0.26), segs=9)
    for k in range(3):
        rr = 0.17 - k * 0.018
        b.cylinder(-0.86, 0.72, TOP + k * 0.024, TOP + k * 0.024 + 0.024, rr, rr, (0.44, 0.36, 0.25), segs=12)
    # Lanterns on the front posts. Emissive panes via UV.x.
    for sx in (-1.18, 1.18):
        z = TOP + 0.34
        b.box(sx, 1.25, z + 0.012, 0.13, 0.13, 0.024, (0.03, 0.03, 0.03))
        b.box(sx, 1.25, z + 0.095, 0.092, 0.092, 0.14, (1.0, 0.72, 0.36), emis=0.55)
        b.box(sx, 1.25, z + 0.18, 0.13, 0.13, 0.024, (0.03, 0.03, 0.03))
        b.cone(sx, 1.25, z + 0.19, z + 0.25, 0.09, (0.03, 0.03, 0.03), (0.03, 0.03, 0.03), segs=4)
    return b

objs = [o.to_object() for o in (build_terrain(), build_ridges(), build_trees(), build_reeds(), build_lilies(), build_dock())]
for o in objs:
    for p in o.data.polygons:
        p.use_smooth = o.name in ("Terrain", "Ridges")
    # Sharp facets for built things and trees: the data has per-vertex shared normals otherwise.
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "env.glb"), export_format="GLB", use_selection=True,
    export_yup=True, export_normals=True, export_texcoords=True, export_materials="NONE",
    export_vertex_color="ACTIVE", export_animations=False)
print("[env] DONE")
