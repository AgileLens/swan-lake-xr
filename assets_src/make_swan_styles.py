# Swan style ladder: 4 GLBs, same node contract (Body root > NeckHead/WingL/WingR/TailFan).
# 0 origami (flat-shaded blocky) · 1 lowpoly (charming stitched spheres, the v1 look)
# 2 organic (smooth metaballs)   · 3 detailed (dense metaballs + layered feather wings)
# Every style is scale-normalized so the Body spans the same length -> flock scale is stable.
# Run: Blender --background --python make_swan_styles.py
import bpy, bmesh, math
from mathutils import Vector, Euler

OUTDIR = "/Users/alex/dev/swan-lake-xr/project/assets"
TARGET_BODY_LEN = 0.92  # meters along Y (Blender forward) before glTF conversion

bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.context.scene.collection

def mat(name, rgba, rough=0.6, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    return m

WHITE = mat("SwanWhite", (0.985, 0.975, 0.95, 1.0), 0.75)
ORANGE = mat("Beak", (0.88, 0.44, 0.10, 1.0), 0.45)
DARK = mat("EyeDark", (0.02, 0.02, 0.025, 1.0), 0.35)

def link(ob, parent=None, loc=(0, 0, 0)):
    col.objects.link(ob)
    if parent: ob.parent = parent
    ob.location = Vector(loc)
    return ob

def shade(me, smooth=True):
    for p in me.polygons: p.use_smooth = smooth

def add_prim(bm_target, make, translate, rot=None, scale=None):
    b2 = bmesh.new(); make(b2)
    if scale: bmesh.ops.scale(b2, vec=Vector(scale), verts=b2.verts)
    if rot: bmesh.ops.rotate(b2, cent=(0, 0, 0), matrix=rot.to_matrix(), verts=b2.verts)
    bmesh.ops.translate(b2, vec=Vector(translate), verts=b2.verts)
    tmp = bpy.data.meshes.new("tmp"); b2.to_mesh(tmp); b2.free()
    bm_target.from_mesh(tmp); bpy.data.meshes.remove(tmp)

def attach_face(neck_me, head, smooth=True, glint=False):
    """Append beak + eyes into a NeckHead mesh, assign material slots."""
    bm = bmesh.new(); bm.from_mesh(neck_me)
    beak_p = head + Vector((0, 0.135, -0.005))
    segs = 5 if not smooth else 12
    add_prim(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=segs, radius1=0.040, radius2=0.007, depth=0.15),
             beak_p, rot=Euler((-math.pi / 2, 0, 0)))
    for sx in (+1, -1):
        add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=8, v_segments=6, radius=0.016),
                 head + Vector((sx * 0.052, 0.055, 0.028)))
    bm.to_mesh(neck_me); bm.free()
    shade(neck_me, smooth)
    neck_me.materials.append(ORANGE)
    neck_me.materials.append(DARK)
    for p in neck_me.polygons:
        c = p.center
        if (c - beak_p).length < 0.085 and c.y > head.y + 0.075:
            p.material_index = 1
        for sx in (+1, -1):
            if (c - (head + Vector((sx * 0.052, 0.055, 0.028)))).length < 0.024:
                p.material_index = 2

def scurve(u):
    return Vector((0,
        0.10 * math.sin(u * math.pi * 1.15) + u * 0.14 + 0.06 * u * u + 0.02,
        0.04 + 0.60 * u + 0.10 * math.sin(u * 2.6)))

HEAD_LOCAL = scurve(1.0) + Vector((0, 0.055, 0.045))
NECK_BASE = Vector((0, 0.30, 0.30))

def mball_to_mesh(name, balls, resolution, material, decimate=None, smooth_iters=0, smooth_factor=0.6):
    mb = bpy.data.metaballs.new(name + "_mb")
    mb.resolution = resolution
    mb.threshold = 0.6
    ob = bpy.data.objects.new(name + "_mbob", mb)
    col.objects.link(ob)
    for pos, r, sc in balls:
        el = mb.elements.new()
        el.co = Vector(pos); el.radius = r; el.stiffness = 2.0
        if sc:
            el.type = 'ELLIPSOID'
            el.size_x, el.size_y, el.size_z = sc
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    out = bpy.data.objects.new(name, me)
    col.objects.link(out)
    if decimate:
        m = out.modifiers.new("dec", 'DECIMATE'); m.ratio = decimate
    if smooth_iters > 0:
        sm = out.modifiers.new("sm", 'SMOOTH'); sm.factor = smooth_factor; sm.iterations = smooth_iters
    if out.modifiers:
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(out.evaluated_get(dg))
        out.modifiers.clear()
        old = out.data; out.data = me2; bpy.data.meshes.remove(old)
    shade(out.data, True)
    out.data.materials.append(material)
    return out

BODY_BALLS = [
    ((0, 0.02, 0.17), 0.26, (1.05, 1.55, 0.85)),
    ((0, 0.24, 0.19), 0.17, (0.9, 0.9, 0.85)),
    ((0, -0.26, 0.22), 0.15, (0.8, 1.15, 0.75)),
    ((0, -0.42, 0.30), 0.085, (0.6, 1.3, 0.7)),
]

def neck_balls(n):
    out = []
    for i in range(n):
        u = i / (n - 1.0)
        out.append((tuple(scurve(u)), 0.088 * (1.0 - 0.30 * u), None))
    out.append((tuple(HEAD_LOCAL), 0.078, (0.92, 1.25, 1.0)))
    return out

def wing_panel(feathers, smooth=True):
    me = bpy.data.meshes.new("Wing")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((0.10, 0.62, 0.30)), verts=bm.verts)
    for v in bm.verts:
        u = (v.co.y + 0.31) / 0.62
        v.co.z *= (0.45 + 0.55 * u)
        v.co.z += 0.10 * math.sin(u * math.pi) * 0.9
        v.co.x *= (0.6 + 0.4 * u)
        if u < 0.35 and v.co.z > 0:
            v.co.z -= 0.05 * (0.35 - u)
    for v in bm.verts:
        if v.co.y < -0.27:
            v.co.y += 0.02 * math.sin(v.co.x * 40.0)
    cuts = 2 if smooth else 0
    for _ in range(cuts):
        bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=1, use_grid_fill=True)
    if smooth:
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.9, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    # extra feather rows for the detailed tier: stacked offset copies of the rear half
    if feathers > 1:
        base = [v.co.copy() for v in bm.verts]
        for k in range(1, feathers):
            b2 = bmesh.new()
            bmesh.ops.create_cube(b2, size=1.0)
            bmesh.ops.scale(b2, vec=Vector((0.055, 0.15, 0.018)), verts=b2.verts)
            for v in b2.verts:
                v.co.y += 0.012 * math.sin(v.co.x * 60.0 + k)
            bmesh.ops.rotate(b2, cent=(0, 0, 0), matrix=Euler((0.16 + 0.09 * k, 0, 0)).to_matrix(), verts=b2.verts)
            bmesh.ops.translate(b2, vec=Vector((0.01 * k, -0.21 - 0.035 * k, 0.115 - 0.028 * k)), verts=b2.verts)
            tmp = bpy.data.meshes.new("tmp"); b2.to_mesh(tmp); b2.free()
            bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)
    bm.to_mesh(me); bm.free()
    shade(me, smooth)
    me.materials.append(WHITE)
    return me

def add_wings_tail(body, smooth=True, feathers=1, petals=3):
    for side, name in ((+1, "WingL"), (-1, "WingR")):
        w = bpy.data.objects.new(name, wing_panel(feathers, smooth))
        link(w, parent=body, loc=(side * 0.155, -0.02, 0.28))
        w.rotation_euler = Euler((0.06, side * -0.18, side * 0.10))
        if side < 0:
            w.scale.x = -1.0
    tf = bpy.data.meshes.new("TailFan"); bm = bmesh.new()
    for i in range(petals):
        ang = (i / max(petals - 1.0, 1.0) - 0.5) * 1.15
        add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=10, v_segments=6, radius=0.07),
                 (math.sin(ang) * 0.055, -0.06 - math.cos(ang) * 0.02, 0.01), scale=(0.5, 1.6, 0.28))
    bm.to_mesh(tf); bm.free(); shade(tf, smooth); tf.materials.append(WHITE)
    tail = bpy.data.objects.new("TailFan", tf)
    link(tail, parent=body, loc=(0, -0.46, 0.30))
    tail.rotation_euler = Euler((0.35, 0, 0))

def normalize_and_export(body, path):
    # uniform-scale the whole rig so Body length (Y span) == TARGET_BODY_LEN
    ys = [ (body.matrix_world @ Vector(c)).y for c in body.bound_box ]
    span = max(ys) - min(ys)
    k = TARGET_BODY_LEN / max(span, 0.001)
    body.scale = Vector((k, k, k))
    bpy.ops.object.select_all(action='DESELECT')
    def sel(o):
        o.select_set(True)
        for ch in o.children: sel(ch)
    sel(body)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=True)
    tris = 0
    for o in col.objects:
        if o.select_get() and o.type == 'MESH':
            tris += len(o.data.polygons)
    print("EXPORTED", path, tris)
    # clean scene for next style
    for o in [o for o in col.objects if o.select_get()]:
        bpy.data.objects.remove(o)

# ---------- style 0: ORIGAMI (flat, blocky) ----------
me = bpy.data.meshes.new("Body"); bm = bmesh.new()
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=7, v_segments=4, radius=0.30), (0, 0, 0.18), scale=(0.85, 1.5, 0.8))
bm.to_mesh(me); bm.free(); shade(me, False); me.materials.append(WHITE)
body = bpy.data.objects.new("Body", me); link(body)
nme = bpy.data.meshes.new("NeckHead"); bm = bmesh.new()
for i in range(5):
    u0, u1 = i / 5.0, (i + 1) / 5.0
    pa, pb = scurve(u0), scurve(u1)
    mid = (pa + pb) * 0.5
    seg = pb - pa
    rot = seg.to_track_quat('Z', 'Y').to_euler()
    add_prim(bm, lambda bb: bmesh.ops.create_cube(bb, size=1.0), mid, rot=rot, scale=(0.072, 0.072, seg.length * 1.2))
add_prim(bm, lambda bb: bmesh.ops.create_cube(bb, size=1.0), HEAD_LOCAL, scale=(0.105, 0.13, 0.11))
bm.to_mesh(nme); bm.free()
attach_face(nme, HEAD_LOCAL, smooth=False)
neck = bpy.data.objects.new("NeckHead", nme); link(neck, parent=body, loc=NECK_BASE)
add_wings_tail(body, smooth=False, feathers=1, petals=3)
normalize_and_export(body, f"{OUTDIR}/swan_style0.glb")

# ---------- style 1: LOWPOLY (v1 charm: stitched spheres) ----------
me = bpy.data.meshes.new("Body"); bm = bmesh.new()
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=18, v_segments=12, radius=0.30), (0, 0, 0.16), scale=(0.85, 1.35, 0.75))
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=12, v_segments=8, radius=0.14), (0, 0.26, 0.16), scale=(0.85, 0.95, 0.85))
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=10, v_segments=6, radius=0.10), (0, -0.40, 0.26), scale=(0.7, 1.5, 0.8))
bm.to_mesh(me); bm.free(); shade(me, True); me.materials.append(WHITE)
body = bpy.data.objects.new("Body", me); link(body)
nme = bpy.data.meshes.new("NeckHead"); bm = bmesh.new()
for i in range(10):
    u0, u1 = i / 10.0, (i + 1) / 10.0
    pa, pb = scurve(u0), scurve(u1)
    mid = (pa + pb) * 0.5
    seg = pb - pa
    rot = seg.to_track_quat('Z', 'Y').to_euler()
    rr = 0.062 * (1.0 - 0.28 * u0)
    add_prim(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=10, radius1=rr, radius2=rr * 0.94, depth=seg.length * 1.35), mid, rot=rot)
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=12, v_segments=8, radius=0.085), tuple(HEAD_LOCAL), scale=(0.9, 1.15, 0.95))
bm.to_mesh(nme); bm.free()
attach_face(nme, HEAD_LOCAL, smooth=True)
neck = bpy.data.objects.new("NeckHead", nme); link(neck, parent=body, loc=(0, 0.31, 0.26))
add_wings_tail(body, smooth=True, feathers=1, petals=3)
normalize_and_export(body, f"{OUTDIR}/swan_style1.glb")

# ---------- style 2: ORGANIC (smooth metaballs, mild denoise, no shrink) ----------
body = mball_to_mesh("Body", BODY_BALLS, 0.022, WHITE, decimate=0.75, smooth_iters=3, smooth_factor=0.5)
neck = mball_to_mesh("NeckHead", neck_balls(14), 0.018, WHITE, smooth_iters=3, smooth_factor=0.5)
attach_face(neck.data, HEAD_LOCAL, smooth=True)
neck.parent = body; neck.location = NECK_BASE
add_wings_tail(body, smooth=True, feathers=1, petals=3)
normalize_and_export(body, f"{OUTDIR}/swan_style2.glb")

# ---------- style 3: DETAILED (dense metaballs + layered feathers + 5-petal tail) ----------
body = mball_to_mesh("Body", BODY_BALLS, 0.014, WHITE, decimate=None, smooth_iters=2, smooth_factor=0.4)
neck = mball_to_mesh("NeckHead", neck_balls(18), 0.013, WHITE, smooth_iters=2, smooth_factor=0.4)
attach_face(neck.data, HEAD_LOCAL, smooth=True)
neck.parent = body; neck.location = NECK_BASE
add_wings_tail(body, smooth=True, feathers=3, petals=5)
normalize_and_export(body, f"{OUTDIR}/swan_style3.glb")

print("STYLES_DONE")
