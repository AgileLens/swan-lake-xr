# The hero swan: a mute swan modeled from its anatomy instead of from blobs.
#
#   Blender --background --python assets_src/make_swan_hero.py -- [--no-bake]
#
# Why it looks like a bird and not a balloon animal:
#   - The body is a boat-shaped hull lofted from measured-looking cross sections, with a
#     chest keel, a raised back and an upturned pointed tail. It is not a union of spheres.
#   - The neck is a tapered S with a real head on it: flat crown, cheek, knobbed bill,
#     black lores and nail. It is a skinned bone chain, so the neck can bend, not swivel.
#   - The wings are about 120 individual feathers draped over the hull in the same rows a
#     bird has (primaries, secondaries, tertials, coverts, scapulars). Each has its own
#     curvature, so its silhouette and shadow come from geometry.
#   - Body feathering is sculpted into a high-res copy and baked to a normal map. Bill, eye
#     and occlusion under the wings go into a single baked atlas, so the body stays one
#     surface and one draw call.
#
# Output in project/assets/swan/:
#   swan_hero.glb        skinned body (bones N1..N8, Head, Jaw) and rigid WingL/WingR/Tail
#                        with Arch and Spread blend shapes on the wings
#   swan_corps_near.glb  static merged mesh, around 760 tris, for the near ranks
#   swan_corps_far.glb   static merged mesh, around 170 tris, for the far ranks
#   swan_albedo.png, swan_normal.png, feather_detail.png
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NO_BAKE = "--no-bake" in ARGV or "--fast" in ARGV
FAST = "--fast" in ARGV  # coarse skin and no sculpt, for quick looks at shape and feathers
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "project", "assets", "swan")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
col = scene.collection

# ------------------------------------------------------------------ shape tables
# Blender axes: +Y forward (head), +Z up, water plane at z = 0. Meters, life size.

def catmull(table, x):
    """Monotone-ish Catmull-Rom through (x, v...) rows sorted by x ascending."""
    t = np.asarray(table, dtype=float)
    xs = t[:, 0]
    x = float(np.clip(x, xs[0], xs[-1]))
    i = int(np.clip(np.searchsorted(xs, x) - 1, 0, len(xs) - 2))
    p0, p1, p2, p3 = t[max(i - 1, 0), 1:], t[i, 1:], t[i + 1, 1:], t[min(i + 2, len(xs) - 1), 1:]
    u = (x - xs[i]) / max(xs[i + 1] - xs[i], 1e-6)
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                  + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)

# y, half width, top z, bottom z
HULL = [
    (-0.660, 0.004, 0.292, 0.272),
    (-0.590, 0.020, 0.280, 0.226),
    (-0.500, 0.046, 0.276, 0.140),
    (-0.400, 0.086, 0.288, 0.024),
    (-0.280, 0.132, 0.312, -0.060),
    (-0.120, 0.174, 0.334, -0.115),
    (0.050, 0.188, 0.336, -0.130),
    (0.200, 0.172, 0.322, -0.120),
    (0.320, 0.134, 0.298, -0.090),
    (0.410, 0.086, 0.262, -0.040),
    (0.470, 0.038, 0.205, 0.020),
    (0.500, 0.006, 0.150, 0.080),
]

def hull_point(y, th, off=0.0, n=2.35):
    """Surface point at station y and angle th (0 top, +pi/2 at +X, pi bottom), offset outward."""
    a, zt, zb = catmull(HULL, y)
    a = max(a, 0.002)
    zc, h = (zt + zb) * 0.5, max((zt - zb) * 0.5, 0.002)
    s, c = math.sin(th), math.cos(th)
    # superellipse: flatter across the back, fuller along the flanks
    x = a * math.copysign(abs(s) ** (2.0 / n), s)
    z = h * math.copysign(abs(c) ** (2.0 / n), c)
    if off != 0.0:
        d = np.array([x / (a * a), z / (h * h)])
        d = d / (np.linalg.norm(d) + 1e-9)
        x, z = x + d[0] * off, z + d[1] * off
    return np.array([x, y, zc + z])

# The S of the neck, from inside the chest up to the back of the skull: (arc param, y, z, radius)
NECK = [
    (0.00, 0.270, 0.150, 0.098),
    (0.10, 0.362, 0.262, 0.070),
    (0.22, 0.414, 0.372, 0.050),
    (0.34, 0.410, 0.480, 0.0405),
    (0.46, 0.366, 0.578, 0.0345),
    (0.58, 0.324, 0.674, 0.0310),
    (0.70, 0.316, 0.770, 0.0295),
    (0.82, 0.350, 0.850, 0.0290),
    (0.92, 0.400, 0.894, 0.0295),
    (1.00, 0.444, 0.906, 0.0310),
]

def neck_point(u):
    v = catmull(NECK, u)
    return np.array([0.0, v[0], v[1]]), v[2]

def neck_frame(u):
    p0, _ = neck_point(max(u - 0.01, 0.0))
    p1, _ = neck_point(min(u + 0.01, 1.0))
    t = p1 - p0
    t = t / (np.linalg.norm(t) + 1e-9)
    side = np.array([1.0, 0.0, 0.0])
    up = np.cross(side, t)  # in the neck plane, the dorsal side
    return t, side, up

HEAD_BASE, _ = neck_point(1.0)
HEAD_DIR = np.array([0.0, math.cos(math.radians(-14)), math.sin(math.radians(-14))])
HEAD_UP = np.cross(np.array([1.0, 0, 0]), HEAD_DIR)

# Head profile along its axis: (dist, half width, height above axis, depth below axis)
HEAD = [
    (-0.012, 0.0305, 0.0305, 0.0305),
    (0.010, 0.0335, 0.0345, 0.0320),
    (0.034, 0.0360, 0.0385, 0.0335),
    (0.060, 0.034, 0.038, 0.031),
    (0.085, 0.0285, 0.033, 0.026),
    (0.105, 0.0245, 0.028, 0.019),
]
# Upper bill and knob: (dist, half width, height, keel). The knob sits at the bill's root.
BILL = [
    (0.098, 0.0235, 0.0300, 0.012),
    (0.112, 0.0225, 0.0345, 0.011),
    (0.126, 0.0210, 0.0270, 0.010),
    (0.145, 0.0195, 0.0165, 0.009),
    (0.170, 0.0190, 0.0115, 0.0085),
    (0.190, 0.0180, 0.0100, 0.0080),
    (0.203, 0.0135, 0.0080, 0.0060),
    (0.210, 0.0030, 0.0030, 0.0020),
]
JAW = [
    (0.100, 0.0180, 0.0020, 0.0130),
    (0.150, 0.0165, 0.0020, 0.0095),
    (0.190, 0.0145, 0.0020, 0.0065),
    (0.204, 0.0060, 0.0015, 0.0030),
]

def head_point(d, w, h):
    return HEAD_BASE + HEAD_DIR * d + HEAD_UP * h + np.array([w, 0.0, 0.0])

BILL_FRONT = HEAD_BASE + HEAD_DIR * 0.21 + HEAD_UP * -0.008
EYE_L = HEAD_BASE + HEAD_DIR * 0.048 + HEAD_UP * 0.012

# ------------------------------------------------------------------ mesh helpers

def loft(name, rings, cap=True):
    """Rings of equal vertex count into a closed smooth mesh object."""
    n = len(rings[0])
    verts = [tuple(p) for r in rings for p in r]
    faces = []
    for i in range(len(rings) - 1):
        for j in range(n):
            a, b = i * n + j, i * n + (j + 1) % n
            c, d = (i + 1) * n + (j + 1) % n, (i + 1) * n + j
            faces.append((a, b, c, d))
    if cap:
        verts.append(tuple(np.mean(rings[0], axis=0)))
        verts.append(tuple(np.mean(rings[-1], axis=0)))
        vs, ve = len(verts) - 2, len(verts) - 1
        last = (len(rings) - 1) * n
        for j in range(n):
            faces.append((vs, (j + 1) % n, j))
            faces.append((ve, last + j, last + (j + 1) % n))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    # Voxel remesh reads normals as inside and outside: an inverted loft simply vanishes.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob

def make_body_parts():
    """Hull, neck and head as separate lofts. The caller voxel-remeshes them into one skin."""
    n = 56
    ring_ths = [2.0 * math.pi * j / n for j in range(n)]
    ys = np.concatenate([np.linspace(-0.64, -0.40, 16), np.linspace(-0.40, 0.32, 40),
                         np.linspace(0.32, 0.49, 18)])
    hull = loft("hull", [[hull_point(float(y), th) for th in ring_ths] for y in ys])
    neck_rings = []
    for u in np.linspace(0.0, 1.0, 72):
        p, r = neck_point(float(u))
        t, side, up = neck_frame(float(u))
        # Slightly deeper front to back than wide, and more so near the chest.
        k_fb = 1.0 + 0.16 * (1.0 - float(u))
        ring = []
        for th in ring_ths:
            ring.append(p + side * math.sin(th) * r * 0.94 + up * math.cos(th) * r * k_fb)
        neck_rings.append(ring)
    neck = loft("neck", neck_rings)
    head_rings = []
    for d in np.linspace(HEAD[0][0], HEAD[-1][0], 40):
        v = catmull(HEAD, float(d))
        w, ht, dp = v[0], v[1], v[2]
        ring = []
        for th in ring_ths:
            s, c = math.sin(th), math.cos(th)
            h = ht * c if c > 0 else dp * c
            ring.append(head_point(float(d), w * math.copysign(abs(s) ** 0.9, s), h))
        head_rings.append(ring)
    head = loft("head", head_rings)
    return hull, neck, head

def bill_rings(table, stations, n, upper=True):
    rings = []
    for d in np.linspace(table[0][0], table[-1][0], stations):
        v = catmull(table, float(d))
        w, ht, dp = v[0], v[1], v[2]
        ring = []
        for j in range(n):
            th = 2.0 * math.pi * j / n
            s, c = math.sin(th), math.cos(th)
            h = ht * c if c > 0 else dp * c
            # The tip of the bill turns up a touch at the nail.
            lift = 0.006 * max(float(d) - 0.17, 0.0) / 0.04
            ring.append(head_point(float(d), w * math.copysign(abs(s) ** 0.8, s),
                                   h + lift - (0.004 if upper else 0.012)))
        rings.append(ring)
    return rings

def uvsphere(name, center, radius, segs=12, rings=8):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob

def apply_mods(ob):
    bpy.context.view_layer.objects.active = ob
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)

def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]

def duplicate(ob, name):
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = name
    c.data.name = name
    col.objects.link(c)
    return c

# ------------------------------------------------------------------ feathers

class FeatherBatch:
    """Accumulates feather grids in three poses. All coordinates are in hull space."""
    def __init__(self):
        self.fold, self.arch, self.spread, self.faces, self.uvs, self.colors = [], [], [], [], [], []

    def add(self, fold, arch, spread, tone, root_dark):
        rows, cols = fold.shape[0], fold.shape[1]
        base = len(self.fold)
        for i in range(rows):
            v = ROW_V[i]
            for j in range(cols):
                u = j / (cols - 1)
                self.fold.append(tuple(fold[i, j]))
                self.arch.append(tuple(arch[i, j]))
                self.spread.append(tuple(spread[i, j]))
                self.uvs.append((u, v))
                # Occlusion toward the root, where the next row covers it, and a soft dark
                # line down both vane edges so overlapping feathers separate under flat light.
                shade = root_dark + (1.0 - root_dark) * (v ** 0.7)
                edge = abs(u * 2.0 - 1.0)
                shade *= 1.0 - 0.20 * edge ** 3
                self.colors.append((tone * shade, tone * shade, tone * shade * 1.002, 1.0))
        for i in range(rows - 1):
            for j in range(cols - 1):
                a = base + i * cols + j
                self.faces.append((a, a + cols, a + cols + 1, a + 1))

    def to_object(self, name, pivot, shape_keys=True):
        me = bpy.data.meshes.new(name)
        verts = [tuple(np.array(p) - pivot) for p in self.fold]
        me.from_pydata(verts, [], self.faces)
        me.update()
        for p in me.polygons:
            p.use_smooth = True
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = self.uvs[me.loops[li].vertex_index]
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(self.colors):
            ca.data[i].color = c
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        if shape_keys:
            ob.shape_key_add(name="Basis", from_mix=False)
            ka = ob.shape_key_add(name="Arch", from_mix=False)
            kb = ob.shape_key_add(name="Spread", from_mix=False)
            for i in range(len(self.fold)):
                ka.data[i].co = Vector(tuple(np.array(self.arch[i]) - pivot))
                kb.data[i].co = Vector(tuple(np.array(self.spread[i]) - pivot))
        return ob

# Rows bunch toward the tip so the rounded end is a curve, not a stair.
ROW_V = [0.0, 0.32, 0.58, 0.76, 0.88, 0.96, 1.0]
ROWS, COLS = len(ROW_V), 4

def vane_width(v, tip_round, kind):
    """Half width profile from root (v = 0) to tip (v = 1)."""
    w = min(1.0, 0.45 + 1.1 * v)
    if v > 1.0 - tip_round:
        k = (v - (1.0 - tip_round)) / tip_round
        w *= math.sqrt(max(1.0 - k * k, 0.0))
    return w

def draped_feather(y0, th0, y1, th1, off0, off1, width, tip_round, cup=0.5, rng=None):
    """A feather laid over the hull from root to tip, in fold pose. Returns ROWS x COLS x 3."""
    out = np.zeros((ROWS, COLS, 3))
    for i in range(ROWS):
        v = ROW_V[i]
        y = y0 + (y1 - y0) * v
        th = th0 + (th1 - th0) * v
        off = off0 + (off1 - off0) * v + 0.006 * math.sin(v * math.pi)
        center = hull_point(y, th, off)
        # Local across-vane direction: along the hull's circumference at this station.
        p1 = hull_point(y, th + 0.04, off)
        across = (p1 - center)
        across = across / (np.linalg.norm(across) + 1e-9)
        normal = center - np.array([0.0, y, catmull(HULL, y)[1:].mean()])
        normal = normal / (np.linalg.norm(normal) + 1e-9)
        hw = width * vane_width(v, tip_round, 0)
        for j in range(COLS):
            u = j / (COLS - 1) * 2.0 - 1.0
            # Convex across the vane, edges tucked down, so each feather catches light.
            out[i, j] = center + across * u * hw - normal * (u * u) * hw * cup * 0.35
    return out

def spread_feather(root, direction, length, width, tip_round, up, droop=0.0, cup=0.5):
    """The same feather in the open wing: straight-ish vane out of a root along a direction."""
    out = np.zeros((ROWS, COLS, 3))
    d = direction / np.linalg.norm(direction)
    across = np.cross(up, d)
    across = across / (np.linalg.norm(across) + 1e-9)
    for i in range(ROWS):
        v = ROW_V[i]
        c = root + d * length * v + up * (-droop * v * v)
        hw = width * vane_width(v, tip_round, 0)
        for j in range(COLS):
            u = j / (COLS - 1) * 2.0 - 1.0
            out[i, j] = c + across * u * hw - up * (u * u) * hw * cup * 0.3
    return out

def wing_batch(side=1.0):
    """Build one wing on the +X side, mirrored when side = -1. Returns (batch, pivot)."""
    pivot = np.array([0.120, 0.205, 0.305])
    rng = np.random.default_rng(1234)
    batch = FeatherBatch()

    def lift_arch(fold, v_power=1.0):
        """Busked pose: the wing raised off the back and arched, as a swan does in display."""
        out = fold.copy()
        for i in range(fold.shape[0]):
            for j in range(fold.shape[1]):
                p = fold[i, j] - pivot
                rear = max(-p[1], 0.0) / 0.75
                ang = math.radians(34.0 + 22.0 * rear)
                c, s = math.cos(ang), math.sin(ang)
                # Rotate outward and up about the body axis through the shoulder.
                x, z = p[0] * c - p[2] * s * 0.2, p[0] * s + p[2] * c
                out[i, j] = pivot + np.array([x + 0.03 * rear, p[1] * (1.0 - 0.06 * rear), z + 0.11 * rear])
        return out

    # Spread wing frame, relative to the shoulder: span along +X with some dihedral.
    def arm(s):
        """Leading edge of the open wing. s = 0 at the shoulder, 1 at the wrist tip."""
        x = 0.06 + 0.86 * s
        y = 0.03 + 0.10 * math.sin(s * math.pi) - 0.02 * s
        z = 0.02 + 0.24 * s - 0.16 * s * s
        return pivot + np.array([x, y, z])

    wing_up = np.array([-0.10, 0.10, 1.0])
    wing_up = wing_up / np.linalg.norm(wing_up)

    def emit(fold, root_s, row_back, direction, length, width, tip_round, tone, root_dark, droop=0.01):
        root = arm(root_s) + np.array([0.0, -row_back, -0.003 * row_back * 10])
        spread = spread_feather(root, direction, length, width, tip_round, wing_up, droop)
        batch.add(fold, lift_arch(fold), spread, tone * float(rng.uniform(0.975, 1.0)), root_dark)

    # The folded wing is a fan. Roots gather near the shoulder and tips stair-step down and
    # back along its lower rear edge, the shape you actually see on a swan at rest. Lower
    # layers are hidden, so the visible surface reads as long smooth feathers, not plates.
    def fan(n, y0a, y0b, th0a, th0b, y1a, y1b, th1a, th1b, off0, off1, stack, width, tip,
            s_a, s_b, back, dir_x, spread_len, spread_w, tone, dark, droop=0.01):
        for k in range(n):
            f = k / max(n - 1, 1)
            y0, y1 = y0a + (y0b - y0a) * f, y1a + (y1b - y1a) * f
            t0, t1 = math.radians(th0a + (th0b - th0a) * f), math.radians(th1a + (th1b - th1a) * f)
            fold = draped_feather(y0, t0, y1, t1, off0 + stack * k * 1.15, off1 + stack * k * 1.15, width, tip, cup=0.22)
            sl = spread_len if callable(spread_len) is False else spread_len(f)
            dx = dir_x(f) if callable(dir_x) else dir_x
            emit(fold, s_a + (s_b - s_a) * f, back, np.array([dx, -1.0, 0.0]), sl, spread_w, tip, tone, dark, droop)

    # Primaries: under everything, tips crossing over the rump.
    fan(10, 0.03, -0.05, 62, 44, -0.46, -0.56, 30, 7, 0.016, 0.022, 0.0013, 0.028, 0.30,
        1.0, 0.60, 0.03, lambda f: 2.2 * (1.0 - f) ** 1.4, lambda f: 0.50 - 0.10 * f, 0.040, 0.985, 0.60, 0.02)
    # Secondaries: the big panel on the flank.
    fan(16, 0.17, 0.03, 66, 50, -0.03, -0.40, 99, 44, 0.020, 0.024, 0.0011, 0.040, 0.34,
        0.60, 0.05, 0.03, 0.03, lambda f: 0.34 - 0.02 * f, 0.036, 0.99, 0.62)
    # Tertials: long, soft plumes over the rear of the back, which give the raised sail shape.
    fan(10, 0.08, -0.10, 34, 20, -0.25, -0.47, 56, 12, 0.040, 0.050, 0.0016, 0.052, 0.40,
        0.09, 0.02, 0.03, -0.02, lambda f: 0.32 - 0.03 * f, 0.044, 1.0, 0.72)
    # Greater coverts cover the roots of the secondaries.
    fan(17, 0.215, 0.06, 68, 46, 0.075, -0.13, 82, 50, 0.034, 0.036, 0.0005, 0.034, 0.46,
        0.64, 0.04, 0.008, 0.03, lambda f: 0.16 - 0.02 * f, 0.030, 1.0, 0.72)
    # Median coverts.
    fan(20, 0.245, 0.085, 65, 42, 0.150, -0.015, 74, 45, 0.041, 0.043, 0.0002, 0.024, 0.52,
        0.68, 0.04, -0.012, 0.02, 0.105, 0.022, 1.0, 0.78)
    # Lesser coverts: the small scale pattern at the shoulder and leading edge.
    for row in range(2):
        fan(22, 0.280 - 0.016 * row, 0.105 - 0.016 * row, 60 + 7 * row, 37 + 7 * row, 0.222 - 0.016 * row, 0.05 - 0.016 * row,
            64 + 7 * row, 39 + 7 * row, 0.048 + 0.004 * row, 0.050 + 0.004 * row, 0.0001, 0.019, 0.56,
            0.72, 0.02, -0.03 - 0.02 * row, 0.02, 0.066 - 0.008 * row, 0.017, 1.0, 0.82)
    # Scapulars: broad feathers from the shoulder over the top of the back, meeting at the spine.
    fan(14, 0.285, 0.03, 34, 10, 0.05, -0.27, 42, 12, 0.056, 0.062, 0.0010, 0.052, 0.50,
        0.05, 0.01, -0.03, -0.04, lambda f: 0.20 + 0.04 * f, 0.036, 1.0, 0.76)
    if side < 0:
        for arr in (batch.fold, batch.arch, batch.spread):
            for i, p in enumerate(arr):
                arr[i] = (-p[0], p[1], p[2])
        batch.faces = [tuple(reversed(f)) for f in batch.faces]
        pivot = pivot * np.array([-1.0, 1.0, 1.0])
    return batch, pivot

def tail_batch():
    pivot = np.array([0.0, -0.44, 0.235])
    batch = FeatherBatch()
    n = 14
    rng = np.random.default_rng(99)
    for k in range(n):
        f = k / (n - 1) * 2.0 - 1.0
        L = 0.215 - 0.05 * abs(f)
        root = np.array([f * 0.050, -0.44, 0.212 + 0.018 * (1.0 - abs(f))])
        direction = np.array([f * 0.34, -1.0, 0.20 - 0.08 * abs(f)])
        up = np.array([0.0, 0.2, 1.0])
        up = up / np.linalg.norm(up)
        grid = spread_feather(root, direction, L, 0.0235, 0.32, up, droop=-0.01)
        batch.add(grid, grid, grid, float(rng.uniform(0.97, 1.0)), 0.62)
    return batch, pivot

# ------------------------------------------------------------------ skinning

BONES = []
def build_armature():
    arm_data = bpy.data.armatures.new("SwanRig")
    arm = bpy.data.objects.new("SwanRig", arm_data)
    col.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    root = eb.new("Root")
    root.head = (0, 0.20, 0.20)
    root.tail = (0, 0.30, 0.20)
    prev = root
    N = 8
    stops = np.linspace(0.05, 1.0, N + 1)
    for i in range(N):
        b = eb.new("N%d" % (i + 1))
        b.head = tuple(neck_point(float(stops[i]))[0])
        b.tail = tuple(neck_point(float(stops[i + 1]))[0])
        b.parent = prev
        b.use_connect = i > 0
        # Lock the roll, so local X stays the swan's left-right axis along the whole chain.
        b.align_roll((0.0, 0.0, 1.0) if abs(b.vector.normalized().z) < 0.9 else (0.0, 1.0, 0.0))
        BONES.append(("N%d" % (i + 1), float(stops[i]), float(stops[i + 1])))
        prev = b
    head = eb.new("Head")
    head.head = tuple(HEAD_BASE)
    head.tail = tuple(HEAD_BASE + HEAD_DIR * 0.09)
    head.parent = prev
    head.use_connect = True
    jaw = eb.new("Jaw")
    jaw.head = tuple(head_point(0.092, 0.0, -0.016))
    jaw.tail = tuple(head_point(0.150, 0.0, -0.016))
    jaw.parent = head
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm

def skin_body(ob, arm, jaw_verts):
    """Weights from the neck curve. Body vertices stay on Root, chest blending into N1."""
    groups = {}
    for name in ["Root", "Head", "Jaw"] + ["N%d" % (i + 1) for i in range(8)]:
        groups[name] = ob.vertex_groups.new(name=name)
    samples = np.linspace(0.0, 1.0, 241)
    pts = np.array([neck_point(float(u))[0] for u in samples])
    rad = np.array([neck_point(float(u))[1] for u in samples])
    stops = np.linspace(0.05, 1.0, 9)
    cos = np.array([v.co[:] for v in ob.data.vertices])
    for vi, p in enumerate(cos):
        if vi in jaw_verts:
            groups["Jaw"].add([vi], 1.0, "REPLACE")
            continue
        # head region: anything forward of the head base plane
        d_head = float(np.dot(p - HEAD_BASE, HEAD_DIR))
        if d_head > 0.0 and np.linalg.norm(p - (HEAD_BASE + HEAD_DIR * d_head)) < 0.075:
            k = min(d_head / 0.016, 1.0)
            groups["Head"].add([vi], k, "REPLACE")
            if k < 1.0:
                groups["N8"].add([vi], 1.0 - k, "REPLACE")
            continue
        d = np.linalg.norm(pts - p, axis=1)
        ks = np.argmin(d / rad)
        u = samples[ks]
        ratio = d[ks] / rad[ks]
        if ratio > 1.65 or u < 0.05 or p[2] < 0.22 and u < 0.2:
            groups["Root"].add([vi], 1.0, "REPLACE")
            continue
        # Fade to the body as the skin spreads onto the chest.
        body_w = float(np.clip((ratio - 1.15) / 0.5, 0.0, 1.0)) * float(np.clip((0.26 - u) / 0.2, 0.0, 1.0))
        body_w = max(body_w, float(np.clip((0.16 - u) / 0.11, 0.0, 1.0)))
        # Blend across the two nearest bones, on the middles of the bones.
        x = float(np.clip((u - stops[0]) / (stops[-1] - stops[0]) * 8.0 - 0.5, 0.0, 7.0))
        i0 = int(math.floor(x))
        i1 = min(i0 + 1, 7)
        f = x - i0
        groups["N%d" % (i0 + 1)].add([vi], (1.0 - f) * (1.0 - body_w), "REPLACE")
        if f > 0.001:
            groups["N%d" % (i1 + 1)].add([vi], f * (1.0 - body_w), "REPLACE")
        if body_w > 0.001:
            groups["Root"].add([vi], body_w, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    ob.parent = arm

# ------------------------------------------------------------------ sculpted plumage

def displace_plumage(ob):
    """Overlapping feather relief in flow coordinates, sculpted into the high-res skin."""
    me = ob.data
    n = len(me.vertices)
    co = np.zeros(n * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    me.calc_loop_triangles()
    nor = np.zeros(n * 3)
    me.vertices.foreach_get("normal", nor)
    nor = nor.reshape(-1, 3)
    samples = np.linspace(0.0, 1.0, 301)
    pts = np.array([neck_point(float(u))[0] for u in samples])
    rad = np.array([neck_point(float(u))[1] for u in samples])
    arc = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    out = np.zeros(n)
    # Chunks: the nearest-point search is N x M.
    for start in range(0, n, 40000):
        chunk = co[start:start + 40000]
        d = np.linalg.norm(chunk[:, None, :] - pts[None, :, :], axis=2)
        ratio = d / rad[None, :]
        k = np.argmin(ratio, axis=1)
        rr = ratio[np.arange(len(chunk)), k]
        neck_w = np.clip((1.45 - rr) / 0.35, 0.0, 1.0) * np.clip((samples[k] - 0.10) / 0.12, 0.0, 1.0)
        # Neck: fine rows flowing from head to body.
        s_neck = (arc[-1] - arc[k]) / 0.0105
        rel = chunk - pts[k]
        ang = np.arctan2(rel[:, 0], rel[:, 2])
        w_neck = ang * rad[k] / 0.0105
        h_neck = _scallop(s_neck, w_neck)
        # Body: larger scales flowing rearward along the hull, grading larger along the flanks.
        zc = 0.13
        s_body = -chunk[:, 1] / 0.0165
        ang_b = np.arctan2(chunk[:, 0], chunk[:, 2] - zc)
        w_body = ang_b * 0.21 / 0.0165
        h_body = _scallop(s_body, w_body)
        # The head is smooth, and the face feathering is very fine.
        d_head = np.sum((chunk - HEAD_BASE) * HEAD_DIR, axis=1)
        head_fade = np.clip((0.0 - d_head) / 0.04, 0.0, 1.0)
        amp_neck = 0.0005 * head_fade
        amp_body = 0.0007
        h = h_neck * amp_neck * neck_w + h_body * amp_body * (1.0 - neck_w)
        # Fine barb grain over everything except the bill.
        grain = np.sin(chunk[:, 1] * 900.0 + chunk[:, 0] * 500.0) * np.sin(chunk[:, 2] * 700.0 + chunk[:, 0] * 300.0)
        h += grain * 0.00007 * head_fade
        out[start:start + 40000] = h
    co = co + nor * out[:, None]
    me.vertices.foreach_set("co", co.ravel())
    me.update()

def _scallop(s, w):
    """Height of overlapping rounded scales. s runs from root to tip, w runs across."""
    r = np.floor(s)
    x = w + 0.5 * np.mod(r, 2.0)
    u = x - np.floor(x)
    cu = (2.0 * u - 1.0)
    # Scale edge is curved: the tip bulges rearward at the center of each feather.
    v = (s + 0.42 * cu * cu)
    v = v - np.floor(v)
    return v ** 1.4 * (1.0 - 0.35 * cu * cu)

# ------------------------------------------------------------------ build

print("[swan] modeling body")
hull, neck, head = make_body_parts()
joined = join([hull, neck, head], "SkinHigh")
rem = joined.modifiers.new("v", "REMESH")
rem.mode = "VOXEL"
rem.voxel_size = 0.009 if FAST else 0.0026
rem.use_smooth_shade = True
apply_mods(joined)
# Soften the voxel crease where the neck leaves the chest, without shrinking the bird.
sm = joined.modifiers.new("s", "CORRECTIVE_SMOOTH")
sm.factor = 0.5
sm.iterations = 24
sm.smooth_type = "SIMPLE"
apply_mods(joined)
print("[swan] skin verts", len(joined.data.vertices))

# Low-res skin first, from the smooth surface, so the bake has the relief to capture.
low = duplicate(joined, "SkinLow")
print("[swan] sculpting plumage")
if not FAST:
    displace_plumage(joined)

# Quadric collapse keeps density where curvature is high, which is the head, bill and neck.
dec = low.modifiers.new("d", "DECIMATE")
dec.decimate_type = "COLLAPSE"
dec.ratio = min(1.0, 3400.0 / max(len(low.data.polygons), 1))
apply_mods(low)
print("[swan] low skin tris", sum(len(p.vertices) - 2 for p in low.data.polygons))

# Bill, jaw, eyes: added to both copies. These are kept as clean lofts, never voxelized.
def add_face_parts(target):
    parts = []
    parts.append(loft("bill", bill_rings(BILL, 22, 16, True)))
    jaw_ob = loft("jaw", bill_rings(JAW, 10, 12, False))
    for side in (1.0, -1.0):
        c = EYE_L + np.array([0.0345 * side, 0.0, 0.0])
        parts.append(uvsphere("eye", c, 0.0072))
    base_verts = len(target.data.vertices)
    jaw_verts = len(jaw_ob.data.vertices)
    for p in parts:
        pass
    bpy.ops.object.select_all(action="DESELECT")
    # jaw first, so its vertex indices are known and contiguous
    jaw_ob.select_set(True)
    for p in parts:
        p.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return base_verts, jaw_verts

base_low, jaw_n = add_face_parts(low)
jaw_set = set(range(base_low, base_low + jaw_n))
add_face_parts(joined)

# Color goes on the high-res copy as a vertex color. The atlas bake picks it up.
def paint_colors(ob):
    me = ob.data
    ca = me.color_attributes.new("Paint", "FLOAT_COLOR", "POINT")
    feather = np.array([0.93, 0.925, 0.905])
    arr = np.tile(np.array([feather[0], feather[1], feather[2], 1.0]), (len(me.vertices), 1))
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    rel = co - HEAD_BASE
    d = rel @ HEAD_DIR
    h = rel @ HEAD_UP
    w = np.abs(rel[:, 0])
    ax = np.sqrt(h * h + w * w)
    orange = np.array([0.78, 0.235, 0.035, 1.0])
    black = np.array([0.012, 0.012, 0.014, 1.0])
    # The bill.
    is_bill = (d > 0.092) & (ax < 0.052)
    arr[is_bill] = orange
    # Knob, and a thin black edge at the root of the bill.
    knob = (d > 0.094) & (d < 0.130) & (h > 0.014) & (w < 0.021) & (ax < 0.052)
    arr[knob] = black
    root_edge = (d > 0.092) & (d < 0.1005) & (ax < 0.044) & (h > -0.018)
    arr[root_edge] = black
    # Nail at the tip, and a black line along the cutting edge.
    nail = d > 0.192
    arr[nail & is_bill] = black
    edge = (d > 0.100) & (np.abs(h + 0.009) < 0.0018) & is_bill
    arr[edge] = black
    # Lores: a narrow black wedge from the bill to the eye, on the sides of the face only.
    span = np.clip((d - 0.044) / 0.050, 0.0, 1.0)
    upper = 0.0135 + 0.006 * span
    lower = 0.0075 - 0.018 * span
    lore = (d > 0.044) & (d < 0.098) & (h < upper) & (h > lower) & (w > 0.0125)
    arr[lore] = black
    # Eye.
    for side in (1.0, -1.0):
        c = EYE_L + np.array([0.0345 * side, 0.0, 0.0])
        arr[np.linalg.norm(co - c, axis=1) < 0.0074] = np.array([0.006, 0.005, 0.005, 1.0])
    # Warm tint on the head and upper neck, as real plumage has from the water it feeds in.
    u_neck = np.clip((co[:, 2] - 0.72) / 0.18, 0.0, 1.0)
    warm = (~is_bill) & (arr[:, 0] > 0.5)
    arr[warm, 2] *= 1.0 - 0.05 * u_neck[warm]
    ca.data.foreach_set("color", arr.ravel())
    me.color_attributes.active_color_index = me.color_attributes.find("Paint")
    return ca

paint_colors(joined)
paint_colors(low)

# Feathers.
print("[swan] laying feathers")
batch_r, pivot_r = wing_batch(1.0)
batch_l, pivot_l = wing_batch(-1.0)
batch_t, pivot_t = tail_batch()
wing_r = batch_r.to_object("WingR", pivot_r)
wing_l = batch_l.to_object("WingL", pivot_l)
tail = batch_t.to_object("TailFan", pivot_t, shape_keys=False)
print("[swan] wing tris", len(batch_r.faces) * 2, "tail tris", len(batch_t.faces) * 2)

# Temporarily in place, so they occlude the body during the AO bake.
for ob_, p in ((wing_r, pivot_r), (wing_l, pivot_l), (tail, pivot_t)):
    ob_.location = Vector(p)

# UV atlas for the body.
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.006, area_weight=0.0)
bpy.ops.object.mode_set(mode="OBJECT")

def new_image(name, size, is_data):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "Non-Color" if is_data else "sRGB"
    return img

def bake_setup():
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 8
    scene.render.bake.margin_type = "EXTEND"

def make_bake_material(ob, img, attr=None):
    m = bpy.data.materials.new("bake_" + img.name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if attr:
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = attr
        nt.links.new(a.outputs[0], b.inputs["Base Color"])
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.nodes.active = t
    ob.data.materials.clear()
    ob.data.materials.append(m)
    return m

if not NO_BAKE:
    bake_setup()
    print("[swan] baking normal")
    img_n = new_image("swan_normal", 2048, True)
    make_bake_material(low, img_n)
    make_bake_material(joined, new_image("_unused", 8, True), "Paint")
    # The bake samples the high copy's surface.
    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.012
    scene.render.bake.max_ray_distance = 0.03
    scene.render.bake.normal_space = "TANGENT"
    low.data.materials[0].node_tree.nodes.active = next(n for n in low.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
    bpy.ops.object.bake(type="NORMAL", margin=8)
    img_n.filepath_raw = os.path.join(OUT, "swan_normal.png")
    img_n.file_format = "PNG"
    img_n.save()

    print("[swan] baking color")
    img_c = new_image("swan_color", 1024, False)
    make_bake_material(low, img_c)
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE", margin=8)

    print("[swan] baking occlusion")
    img_ao = new_image("swan_ao", 1024, True)
    make_bake_material(low, img_ao)
    scene.render.bake.use_selected_to_active = False
    joined.select_set(False)
    joined.hide_render = True
    scene.cycles.samples = 96
    bpy.ops.object.bake(type="AO", margin=8)

    # Albedo = paint x occlusion, so the bird has form even under flat night ambient.
    c = np.array(img_c.pixels[:]).reshape(1024, 1024, 4)
    ao = np.array(img_ao.pixels[:]).reshape(1024, 1024, 4)[:, :, 0]
    ao = np.clip(ao, 0.0, 1.0)
    shade = 0.62 + 0.38 * ao ** 0.8  # gentle: wings can open, so the flank must survive being seen
    c[:, :, :3] = c[:, :, :3] * shade[:, :, None]
    out = new_image("swan_albedo", 1024, False)
    out.pixels = c.ravel().tolist()
    out.filepath_raw = os.path.join(OUT, "swan_albedo.png")
    out.file_format = "PNG"
    out.save()

# Back to true local transforms for export.
for ob_ in (wing_r, wing_l, tail):
    ob_.location = Vector((0.0, 0.0, 0.0))

# High-res copy is finished.
bpy.data.objects.remove(joined)

# Corps meshes, before the rig goes on: fold-pose bird merged and decimated.
def corps_mesh(name, tris, wing_tris_ratio):
    objs = []
    body = duplicate(low, name + "_b")
    body.data.materials.clear()
    wl = bpy.data.objects.new(name + "_wl", bpy.data.meshes.new(name + "_wl"))
    col.objects.link(wl)
    w1 = batch_r.to_object(name + "_r", pivot_r * 0.0, shape_keys=False)
    w2 = batch_l.to_object(name + "_l", pivot_l * 0.0, shape_keys=False)
    t1 = batch_t.to_object(name + "_t", pivot_t * 0.0, shape_keys=False)
    bpy.data.objects.remove(wl)
    # The body's vertex colors become the merged color attribute.
    for o in (body, w1, w2, t1):
        me = o.data
        if "Col" not in me.color_attributes:
            me.color_attributes["Paint"].name = "Col"
    merged = join([body, w1, w2, t1], name)
    for attr in list(merged.data.color_attributes):
        if attr.name != "Col":
            merged.data.color_attributes.remove(attr)
    merged.data.color_attributes.active_color_index = 0
    d = merged.modifiers.new("d", "DECIMATE")
    d.decimate_type = "COLLAPSE"
    d.ratio = tris / max(sum(len(p.vertices) - 2 for p in merged.data.polygons), 1)
    d.use_collapse_triangulate = True
    apply_mods(merged)
    print("[swan]", name, "tris", sum(len(p.vertices) - 2 for p in merged.data.polygons))
    return merged

near = corps_mesh("SwanCorpsNear", 760, 1.0)
far = corps_mesh("SwanCorpsFar", 170, 1.0)

def export(objs, path, skins=False, morph=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=False,
        export_yup=True, export_tangents=True, export_normals=True, export_texcoords=True,
        export_skins=skins, export_morph=morph, export_morph_normal=morph, export_morph_tangent=False,
        export_animations=False, export_materials="NONE", export_vertex_color="ACTIVE",
        export_all_vertex_colors=False)

near.location = Vector((0, 0, 0))
export([near], os.path.join(OUT, "swan_corps_near.glb"))
export([far], os.path.join(OUT, "swan_corps_far.glb"))
bpy.data.objects.remove(near)
bpy.data.objects.remove(far)

# Rig the hero.
print("[swan] rigging")
arm = build_armature()
skin_body(low, arm, jaw_set)
low.name = "Body"
low.data.materials.clear()
# Wings and tail hang off rigid empties at their pivots: the existing flap code rotates those.
wing_r.location = Vector(pivot_r)
wing_l.location = Vector(pivot_l)
tail.location = Vector(pivot_t)

objs = [arm, low, wing_r, wing_l, tail]
export(objs, os.path.join(OUT, "swan_hero.glb"), skins=True, morph=True)

# A small feather detail map: rachis and barbs, tiled once per feather via its 0-1 UV.
W, H = 64, 256
fd = bpy.data.images.new("feather_detail", W, H, alpha=False)
fd.colorspace_settings.name = "Non-Color"
px = np.zeros((H, W, 4))
u = (np.arange(W) + 0.5) / W
v = (np.arange(H) + 0.5) / H
uu, vv = np.meshgrid(u, v)
x = uu * 2.0 - 1.0
# Height field: a raised shaft plus slanting barbs that follow the vane.
shaft = np.exp(-(x / 0.05) ** 2) * (1.0 - 0.75 * vv)
barbs = np.sin((vv * 90.0 - np.abs(x) * 36.0) * 2.0) * 0.5 + 0.5
height = shaft * 0.9 + barbs * 0.035
gx = np.gradient(height, axis=1) * 8.0
gy = np.gradient(height, axis=0) * 8.0
nz = np.ones_like(gx)
ln = np.sqrt(gx * gx + gy * gy + nz * nz)
px[:, :, 0] = (-gx / ln) * 0.5 + 0.5
px[:, :, 1] = (-gy / ln) * 0.5 + 0.5
px[:, :, 2] = nz / ln * 0.5 + 0.5
px[:, :, 3] = 1.0
fd.pixels = px.ravel().tolist()
fd.filepath_raw = os.path.join(OUT, "feather_detail.png")
fd.file_format = "PNG"
fd.save()

print("[swan] DONE")
