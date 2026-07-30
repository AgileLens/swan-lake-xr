# Swan Lake XR asset pass 2: organic metaball swan + fish + conductor hands w/ baton.
# Blender headless: Blender --background --python make_swan_v2.py
# Exports: swan.glb (Body + NeckHead + WingL/R + TailFan), fish.glb, hands.glb (HandL, HandR+Baton)
# Convention: face +Y in Blender => -Z forward in Godot.
import bpy, bmesh, math
from mathutils import Vector, Euler

OUTDIR = "/Users/alex/dev/swan-lake-xr/project/assets"
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
SILVER = mat("FishSilver", (0.75, 0.82, 0.88, 1.0), 0.25, 0.6)
IVORY = mat("HandIvory", (0.96, 0.95, 0.92, 1.0), 0.55)
PEARL = mat("BatonPearl", (0.99, 0.98, 0.96, 1.0), 0.2)

def link(ob, parent=None, loc=(0, 0, 0)):
    col.objects.link(ob)
    if parent: ob.parent = parent
    ob.location = Vector(loc)
    return ob

def smooth(me):
    for p in me.polygons: p.use_smooth = True

def mball_to_mesh(name, balls, resolution, material, decimate=None):
    """balls: list of (pos, radius, stiffness, scale_xyz or None)"""
    mb = bpy.data.metaballs.new(name + "_mb")
    mb.resolution = resolution
    mb.threshold = 0.6
    ob = bpy.data.objects.new(name + "_mbob", mb)
    col.objects.link(ob)
    for pos, r, stiff, sc in balls:
        el = mb.elements.new()
        el.co = Vector(pos); el.radius = r; el.stiffness = stiff
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
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(out.evaluated_get(dg))
        out.modifiers.clear()
        old = out.data; out.data = me2; bpy.data.meshes.remove(old)
    sm_mod = out.modifiers.new("sm", 'SMOOTH')
    sm_mod.factor = 1.0
    sm_mod.iterations = 12
    dg2 = bpy.context.evaluated_depsgraph_get()
    me3 = bpy.data.meshes.new_from_object(out.evaluated_get(dg2))
    out.modifiers.clear()
    old2 = out.data; out.data = me3; bpy.data.meshes.remove(old2)
    smooth(out.data)
    out.data.materials.append(material)
    return out

# ================= SWAN v2 (organic) =================
# Body family: hull + chest + rump blend into one smooth teardrop
body = mball_to_mesh("Body", [
    ((0, 0.02, 0.17), 0.26, 2.0, (1.05, 1.55, 0.85)),   # main hull
    ((0, 0.24, 0.19), 0.17, 2.0, (0.9, 0.9, 0.85)),     # chest swell
    ((0, -0.26, 0.22), 0.15, 2.0, (0.8, 1.15, 0.75)),   # rump rise
    ((0, -0.42, 0.30), 0.085, 2.0, (0.6, 1.3, 0.7)),    # tail lift
], resolution=0.022, material=WHITE, decimate=0.75)

# Neck family: S-curve chain, generous overlap at base to hide the family seam
def scurve(u):  # u 0..1 -> neck-local point (origin at neck base)
    y = 0.10 * math.sin(u * math.pi * 1.15) + u * 0.14 + 0.06 * u * u
    z = 0.62 * u - 0.16 * math.sin(u * math.pi) * (1 - u * 0.4)
    return (0, y + 0.02, 0.04 + 0.60 * u + 0.10 * math.sin(u * 2.6))

NECK_BASE = Vector((0, 0.30, 0.30))
neck_balls = []
for i in range(14):
    u = i / 13.0
    p = scurve(u)
    r = 0.088 * (1.0 - 0.30 * u)
    neck_balls.append((p, r, 2.0, None))
# head bulb at top
head_p = scurve(1.0)
HEAD = Vector(head_p) + Vector((0, 0.055, 0.045))
neck_balls.append((tuple(HEAD), 0.078, 2.0, (0.92, 1.25, 1.0)))
neck = mball_to_mesh("NeckHead", neck_balls, resolution=0.018, material=WHITE, decimate=None)
neck.parent = body
neck.location = NECK_BASE

# beak + eyes appended into NeckHead mesh
bm = bmesh.new(); bm.from_mesh(neck.data)
def add_prim(bm_target, make, matrix_translate, rot=None, scale=None):
    b2 = bmesh.new(); make(b2)
    if scale: bmesh.ops.scale(b2, vec=Vector(scale), verts=b2.verts)
    if rot: bmesh.ops.rotate(b2, cent=(0,0,0), matrix=rot.to_matrix(), verts=b2.verts)
    bmesh.ops.translate(b2, vec=Vector(matrix_translate), verts=b2.verts)
    tmp = bpy.data.meshes.new("tmp"); b2.to_mesh(tmp); b2.free()
    bm_target.from_mesh(tmp); bpy.data.meshes.remove(tmp)

add_prim(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=12, radius1=0.040, radius2=0.007, depth=0.15),
         HEAD + Vector((0, 0.135, -0.005)), rot=Euler((-math.pi/2, 0, 0)))
for sx in (+1, -1):
    add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=8, v_segments=6, radius=0.016),
             HEAD + Vector((sx * 0.052, 0.055, 0.028)))
bm.to_mesh(neck.data); bm.free()
smooth(neck.data)
neck.data.materials.append(ORANGE)  # slot 1
neck.data.materials.append(DARK)    # slot 2
for p in neck.data.polygons:
    c = p.center
    if (c - (HEAD + Vector((0, 0.135, -0.005)))).length < 0.10 and c.y > HEAD.y + 0.05:
        p.material_index = 1
    for sx in (+1, -1):
        if (c - (HEAD + Vector((sx * 0.052, 0.055, 0.028)))).length < 0.024:
            p.material_index = 2

# Wings: sculpted panels with feather notches (origin at shoulder)
def wing_mesh(side):
    me = bpy.data.meshes.new("Wing")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((0.10, 0.62, 0.30)), verts=bm.verts)
    # taper toward rear + arch over back
    for v in bm.verts:
        u = (v.co.y + 0.31) / 0.62          # 0 rear .. 1 front
        v.co.z *= (0.45 + 0.55 * u)          # thinner at rear
        v.co.z += 0.10 * math.sin(u * math.pi) * 0.9
        v.co.x *= (0.6 + 0.4 * u)
        if u < 0.35 and v.co.z > 0:          # rear-top: feather step silhouette
            v.co.z -= 0.05 * (0.35 - u)
    # 3 notch cuts on trailing tip
    for v in bm.verts:
        if v.co.y < -0.27:
            k = math.sin((v.co.x * 40.0))
            v.co.y += 0.02 * k
    for _ in range(2):
        bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=1, use_grid_fill=True)
    bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.9, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(me); bm.free()
    smooth(me)
    me.materials.append(WHITE)
    return me

for side, name in ((+1, "WingL"), (-1, "WingR")):
    w = bpy.data.objects.new(name, wing_mesh(side))
    link(w, parent=body, loc=(side * 0.155, -0.02, 0.28))
    w.rotation_euler = Euler((0.06, side * -0.18, side * 0.10))

# Tail fan (3 flattened petals)
tf = bpy.data.meshes.new("TailFan"); bm = bmesh.new()
for i, ang in enumerate((-0.5, 0.0, 0.5)):
    add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=10, v_segments=6, radius=0.07),
             (math.sin(ang) * 0.05, -0.06 - math.cos(ang) * 0.02, 0.01), scale=(0.5, 1.6, 0.28))
bm.to_mesh(tf); bm.free(); smooth(tf); tf.materials.append(WHITE)
tail = bpy.data.objects.new("TailFan", tf)
link(tail, parent=body, loc=(0, -0.46, 0.30))
tail.rotation_euler = Euler((0.35, 0, 0))

bpy.ops.object.select_all(action='DESELECT')
for o in (body, neck, tail, *[o for o in col.objects if o.name.startswith("Wing")]):
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"{OUTDIR}/swan.glb", export_format='GLB', use_selection=True, export_yup=True, export_apply=True)
print("SWAN2", sum(len(o.data.polygons) for o in col.objects if o.type == 'MESH' and o.select_get()))

# ================= FISH =================
for o in list(col.objects): o.select_set(False)
fme = bpy.data.meshes.new("FishBody"); bm = bmesh.new()
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=14, v_segments=8, radius=0.055), (0, 0, 0), scale=(0.55, 1.9, 0.9))
# tail fin
add_prim(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=3, radius1=0.05, radius2=0.001, depth=0.07),
         (0, -0.125, 0.0), rot=Euler((math.pi/2, 0, 0)), scale=(0.3, 1.0, 1.4))
# dorsal
add_prim(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=3, radius1=0.03, radius2=0.001, depth=0.05),
         (0, 0.01, 0.055), scale=(0.25, 1.6, 1.0))
bm.to_mesh(fme); bm.free(); smooth(fme); fme.materials.append(SILVER)
fish = bpy.data.objects.new("Fish", fme); link(fish)
fish.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"{OUTDIR}/fish.glb", export_format='GLB', use_selection=True, export_yup=True, export_apply=True)
print("FISH", len(fme.polygons))

# ================= CONDUCTOR HANDS (+ baton in right) =================
for o in list(col.objects): o.select_set(False)

def hand(name, curl, side):
    """Stylized mitten hand. curl 0=open (left), 1=holding (right). Origin at wrist, fingers -Z, palm -Y."""
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    # palm
    add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=12, v_segments=8, radius=0.045),
             (0, 0, -0.045), scale=(1.0, 0.55, 1.15))
    # finger block: 4 segments fanned, curled by `curl`
    for i in range(4):
        fx = (i - 1.5) * 0.021
        ang = curl * (0.9 + i * 0.05)
        fz = -0.095 - math.cos(ang) * 0.045
        fy = -math.sin(ang) * 0.045
        add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=8, v_segments=6, radius=0.017),
                 (fx, fy, fz), scale=(0.75, 0.8, 2.0 - curl * 0.7))
    # thumb
    add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=8, v_segments=6, radius=0.018),
             (side * 0.048, -0.02 - curl * 0.015, -0.055), scale=(0.8, 0.8, 1.6))
    # wrist stub
    add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=10, v_segments=6, radius=0.032),
             (0, 0.004, 0.012), scale=(0.9, 0.75, 0.9))
    bm.to_mesh(me); bm.free(); smooth(me); me.materials.append(IVORY)
    ob = bpy.data.objects.new(name, me); link(ob)
    return ob

hl = hand("HandL", 0.15, +1)
hr = hand("HandR", 0.85, -1)
hr.location = Vector((0.25, 0, 0))
# baton: 30cm tapered shaft + cork ball, gripped in right hand, pointing -Z
bme = bpy.data.meshes.new("Baton"); bm = bmesh.new()
add_prim(bm, lambda b: bmesh.ops.create_cone(b, cap_ends=True, segments=10, radius1=0.006, radius2=0.0022, depth=0.30),
         (0, 0, -0.115), rot=Euler((0, 0, 0)))
add_prim(bm, lambda b: bmesh.ops.create_uvsphere(b, u_segments=10, v_segments=8, radius=0.011), (0, 0, 0.038))
bm.to_mesh(bme); bm.free(); smooth(bme); bme.materials.append(PEARL)
baton = bpy.data.objects.new("Baton", bme)
link(baton, parent=hr, loc=(-0.002, -0.035, -0.055))
baton.rotation_euler = Euler((math.radians(-90+14), 0, 0))  # cone axis +Z->points forward -Z-ish through grip

bpy.ops.object.select_all(action='DESELECT')
for o in (hl, hr, baton): o.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"{OUTDIR}/hands.glb", export_format='GLB', use_selection=True, export_yup=True, export_apply=True)
print("HANDS", len(hl.data.polygons) + len(hr.data.polygons) + len(bme.polygons))
print("ASSETS2_DONE")
