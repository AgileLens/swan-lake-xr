# Blender headless: stylized low-poly swan -> GLB
# Run: Blender --background --python make_swan.py
# Convention: models facing +Y in Blender => faces -Z (forward) in Godot after glTF export.
import bpy, bmesh, math
from mathutils import Vector, Euler

OUT = "/Users/alex/dev/swan-lake-xr/project/assets/swan.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.context.scene.collection

def mat(name, rgba, rough=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    return m

WHITE = mat("SwanWhite", (0.98, 0.97, 0.94, 1.0), 0.6)
ORANGE = mat("Beak", (0.85, 0.45, 0.12, 1.0), 0.5)
BLACK = mat("Mask", (0.03, 0.03, 0.035, 1.0), 0.7)

def add_obj(mesh_name, verts_faces_fn, material, parent=None, origin=(0,0,0)):
    me = bpy.data.meshes.new(mesh_name)
    bm = bmesh.new()
    verts_faces_fn(bm)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(mesh_name, me)
    col.objects.link(ob)
    ob.data.materials.append(material)
    if parent:
        ob.parent = parent
    ob.location = Vector(origin)
    for p in me.polygons:
        p.use_smooth = True
    return ob

def uvsphere(bm, radius=1.0, u=16, v=10, scale=(1,1,1), offset=(0,0,0)):
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(offset), verts=bm.verts)

# ---------- Body (origin = waterline center) ----------
def body_fn(bm):
    # main hull
    uvsphere(bm, 0.30, 18, 12, scale=(0.85, 1.35, 0.75), offset=(0, 0, 0.16))
    # chest puff
    uvsphere(bm, 0.14, 12, 8, scale=(0.85, 0.95, 0.85), offset=(0, 0.26, 0.16))
    # tail nub, raised
    uvsphere(bm, 0.10, 10, 6, scale=(0.7, 1.5, 0.8), offset=(0, -0.40, 0.26))
body = add_obj("Body", body_fn, WHITE)

# ---------- Neck + Head (child of Body, origin at neck base) ----------
NECK_BASE = Vector((0, 0.34, 0.28))
curve = bpy.data.curves.new("NeckCurve", 'CURVE')
curve.dimensions = '3D'
curve.bevel_depth = 0.055
curve.bevel_resolution = 4
curve.resolution_u = 24
sp = curve.splines.new('BEZIER')
sp.bezier_points.add(3)
pts = [
    # S-curve: base -> forward lean -> back -> head, in NECK-LOCAL coords
    ((0, 0.00, 0.00), (0, -0.05, -0.08), (0, 0.06, 0.10)),
    ((0, 0.16, 0.28), (0, 0.02, -0.12), (0, -0.02, 0.12)),
    ((0, 0.04, 0.55), (0, 0.06, -0.10), (0, -0.06, 0.10)),
    ((0, 0.16, 0.72), (0, -0.10, -0.04), (0, 0.06, 0.02)),
]
for bp, (co, hl, hr) in zip(sp.bezier_points, pts):
    bp.co = Vector(co)
    bp.handle_left = Vector(co) + Vector(hl)
    bp.handle_right = Vector(co) + Vector(hr)
    bp.handle_left_type = bp.handle_right_type = 'FREE'
neck_ob = bpy.data.objects.new("NeckHead", None)  # placeholder; replaced below

# convert curve to mesh via temp object
tmp = bpy.data.objects.new("neck_tmp", curve)
col.objects.link(tmp)
dg = bpy.context.evaluated_depsgraph_get()
neck_me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
bpy.data.objects.remove(tmp)
for p in neck_me.polygons:
    p.use_smooth = True
neck = bpy.data.objects.new("NeckHead", neck_me)
col.objects.link(neck)
neck.data.materials.append(WHITE)
neck.parent = body
neck.location = NECK_BASE

# head bulb + beak as part of NeckHead (join via bmesh append)
bm = bmesh.new()
bm.from_mesh(neck_me)
HEAD = Vector((0, 0.175, 0.735))
bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.085)
last = [v for v in bm.verts if v.select] or bm.verts[-74:]
# scale+move the just-created sphere verts (last 74 for 12x8 sphere)
new_verts = bm.verts[:] if False else None
# simpler: take verts with no faces yet? fallback: translate all verts created after count
bm2 = bmesh.new()
bmesh.ops.create_uvsphere(bm2, u_segments=12, v_segments=8, radius=0.085)
bmesh.ops.scale(bm2, vec=Vector((0.9, 1.15, 0.95)), verts=bm2.verts)
bmesh.ops.translate(bm2, vec=HEAD, verts=bm2.verts)
me2 = bpy.data.meshes.new("head_part")
bm2.to_mesh(me2); bm2.free()
bm.from_mesh(me2)
# beak: cone forward from head
bm3 = bmesh.new()
bmesh.ops.create_cone(bm3, cap_ends=True, segments=10, radius1=0.045, radius2=0.008, depth=0.16)
bmesh.ops.rotate(bm3, cent=(0,0,0), matrix=Euler((-math.pi/2, 0, 0)).to_matrix(), verts=bm3.verts)
bmesh.ops.translate(bm3, vec=HEAD + Vector((0, 0.145, -0.01)), verts=bm3.verts)
me3 = bpy.data.meshes.new("beak_part")
bm3.to_mesh(me3); bm3.free()
bm.from_mesh(me3)
bm.to_mesh(neck_me)
bm.free()
for p in neck_me.polygons:
    p.use_smooth = True
# material slots: 0 white (neck+head), 1 orange beak, 2 black mask
neck_me.materials.append(ORANGE)
neck_me.materials.append(BLACK)
n_neckhead = len(neck_me.polygons)
# assign beak cone polys to orange (they are the last 20-ish polys), mask ring black
beak_polys = 10 + 10  # cone side+caps approx; assign by position instead:
for p in neck_me.polygons:
    c = p.center
    if (c - (HEAD + Vector((0, 0.145, -0.01)))).length < 0.11 and c.y > HEAD.y + 0.06:
        p.material_index = 1

# ---------- Wings (children, origins at shoulders for flap hinge) ----------
def wing_fn_factory(side):  # side: +1 = left(+x), -1 = right
    def fn(bm):
        # folded wing: flattened sphere shell along body flank, in WING-LOCAL coords (origin at shoulder)
        uvsphere(bm, 0.30, 14, 10, scale=(0.22, 1.30, 0.55), offset=(side * 0.05, -0.22, 0.07))
    return fn

wingL = add_obj("WingL", wing_fn_factory(+1), WHITE, parent=body, origin=(0.16, 0.05, 0.22))
wingR = add_obj("WingR", wing_fn_factory(-1), WHITE, parent=body, origin=(-0.16, 0.05, 0.22))

# ---------- Export ----------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_yup=True,
    export_apply=True,
)
import os
print("EXPORTED", OUT, os.path.getsize(OUT), "bytes")
tris = sum(len(o.data.polygons) for o in (body, neck, wingL, wingR))
print("POLYS", tris)
