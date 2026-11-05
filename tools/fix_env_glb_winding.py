#!/usr/bin/env python3
"""One-time, evidence-gated repair of the tracked env.glb made by the old generator."""
from pathlib import Path
import collections, hashlib, json, math, struct, sys

ROOT = Path(__file__).resolve().parent.parent
GLB = ROOT / "project/assets/env/env.glb"
OLD_SHA256 = "7a17d97008a518f9f787573fa062021a604542a3b4fdad8b9abf1fcdf7ba40a1"
INTERMEDIATE_SHA256 = "fff46c19cdb6322aa751f9df6f3e4996160b36537e7258f78f0fee25060d8dbb"
FMT = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

def parse(data):
    magic, version, total = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67 and version == 2 and total == len(data)
    off, doc, binary = 12, None, None
    while off < total:
        length, kind = struct.unpack_from("<II", data, off); off += 8
        chunk = data[off:off + length]; off += length
        if kind == 0x4E4F534A: doc = json.loads(chunk.decode().rstrip("\0 "))
        elif kind == 0x004E4942: binary = bytearray(chunk)
    assert doc is not None and binary is not None
    return doc, binary

def accessor(doc, binary, index):
    a = doc["accessors"][index]; view = doc["bufferViews"][a["bufferView"]]
    code, size = FMT[a["componentType"]]; n = NCOMP[a["type"]]
    stride = view.get("byteStride", size * n)
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    values = [struct.unpack_from("<" + code * n, binary, start + i * stride) for i in range(a["count"])]
    return values, (start, stride, code, n)

def primitive(doc, name):
    mesh = next(m for m in doc["meshes"] if m.get("name") == name)
    assert len(mesh["primitives"]) == 1 and mesh["primitives"][0].get("mode", 4) == 4
    return mesh["primitives"][0]

def components(positions, indices):
    unique, uid = {}, []
    for p in positions:
        if p not in unique: unique[p] = len(unique)
        uid.append(unique[p])
    parent = list(range(len(unique)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    def union(a, b):
        a, b = find(a), find(b)
        if a != b: parent[b] = a
    for q in range(0, len(indices), 3):
        a, b, c = (uid[indices[q + i]] for i in range(3)); union(a, b); union(a, c)
    verts = collections.defaultdict(set); tris = collections.defaultdict(list)
    for i, u in enumerate(uid): verts[find(u)].add(u)
    for q in range(0, len(indices), 3): tris[find(uid[indices[q]])].append(q)
    return [(verts[r], tris[r]) for r in verts]

def face_normal(positions, ids):
    a, b, c = (positions[i] for i in ids)
    u = tuple(b[k] - a[k] for k in range(3)); v = tuple(c[k] - a[k] for k in range(3))
    n = (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0])
    length = math.sqrt(sum(x*x for x in n)); assert length > 1e-10
    return tuple(x / length for x in n)

def build(doc, binary):
    doc["buffers"][0]["byteLength"] = len(binary)
    raw_json = json.dumps(doc, separators=(",", ":")).encode()
    raw_json += b" " * ((4 - len(raw_json) % 4) % 4)
    binary += b"\0" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(raw_json) + 8 + len(binary)
    return struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(raw_json), 0x4E4F534A) + raw_json + struct.pack("<II", len(binary), 0x004E4942) + binary

def audit(data):
    doc, binary = parse(data)
    tp = primitive(doc, "Trees")
    tpos, _ = accessor(doc, binary, tp["attributes"]["POSITION"])
    tnorm, _ = accessor(doc, binary, tp["attributes"]["NORMAL"])
    tind = [x[0] for x in accessor(doc, binary, tp["indices"])[0]]
    crowns, crown_ok, crown_normals_ok = 0, 0, 0
    for verts, offsets in components(tpos, tind):
        if len(verts) == 24 and len(offsets) == 44:
            crowns += 1
            ys = [tpos[tind[q]][1] for q in offsets for _ in [0]]
            lo, hi = min(ys), max(ys)
            bottom = [q for q in offsets if max(abs(tpos[tind[q+i]][1] - lo) for i in range(3)) < 1e-6]
            top = [q for q in offsets if max(abs(tpos[tind[q+i]][1] - hi) for i in range(3)) < 1e-6]
            if len(bottom) == len(top) == 4 and all(face_normal(tpos, tind[q:q+3])[1] < -0.9 for q in bottom) and all(face_normal(tpos, tind[q:q+3])[1] > 0.9 for q in top):
                crown_ok += 1
                caps = bottom + top
                if all(sum(face_normal(tpos, tind[q:q+3])[k] * (sum(tnorm[tind[q+i]][k] for i in range(3))/3.0) for k in range(3)) > 0.9 for q in caps):
                    crown_normals_ok += 1
    rp = primitive(doc, "Reeds")
    rpos, _ = accessor(doc, binary, rp["attributes"]["POSITION"])
    rnorm, _ = accessor(doc, binary, rp["attributes"]["NORMAL"])
    rind = [x[0] for x in accessor(doc, binary, rp["indices"])[0]]
    reed_components = components(rpos, rind)
    blades = sum(len(v) == 8 and len(q) == 12 for v, q in reed_components)
    reed_normal_min = min(sum(face_normal(rpos, rind[q:q+3])[k] * (sum(rnorm[rind[q+i]][k] for i in range(3))/3.0) for k in range(3)) for q in range(0, len(rind), 3))
    return {"crowns": crowns, "crown_ok": crown_ok, "crown_normals_ok": crown_normals_ok,
            "blades_double_sided": blades, "reed_normal_min": reed_normal_min,
            "reed_triangles": len(rind)//3, "sha256": hashlib.sha256(data).hexdigest()}

def repair(data):
    assert hashlib.sha256(data).hexdigest() == OLD_SHA256, "input is not the audited original GLB"
    doc, binary = parse(data)
    tp = primitive(doc, "Trees")
    tpos, _ = accessor(doc, binary, tp["attributes"]["POSITION"])
    tnorm, nmeta = accessor(doc, binary, tp["attributes"]["NORMAL"])
    tind_values, imeta = accessor(doc, binary, tp["indices"])
    tind = [x[0] for x in tind_values]
    cap_offsets, cap_vertices, crowns = [], set(), 0
    for verts, offsets in components(tpos, tind):
        if len(verts) != 24 or len(offsets) != 44: continue
        crowns += 1
        ys = [tpos[tind[q]][1] for q in offsets]; lo, hi = min(ys), max(ys)
        caps = [q for q in offsets if max(tpos[tind[q+i]][1] for i in range(3)) - min(tpos[tind[q+i]][1] for i in range(3)) < 1e-6 and (abs(tpos[tind[q]][1]-lo)<1e-6 or abs(tpos[tind[q]][1]-hi)<1e-6)]
        assert len(caps) == 8
        for q in caps:
            cap_offsets.append(q); cap_vertices.update(tind[q:q+3])
    assert crowns == 39 and len(cap_offsets) == 312
    istart, istride, icode, _ = imeta
    assert icode == "H" and istride == 2
    for q in cap_offsets:
        tind[q+1], tind[q+2] = tind[q+2], tind[q+1]
    for i, value in enumerate(tind): struct.pack_into("<H", binary, istart + i*2, value)
    nstart, nstride, ncode, nn = nmeta
    assert ncode == "f" and nn == 3
    for i in cap_vertices:
        n = tnorm[i]
        struct.pack_into("<fff", binary, nstart + i*nstride, -n[0], -n[1], -n[2])

    rp = primitive(doc, "Reeds")
    rpos, _ = accessor(doc, binary, rp["attributes"]["POSITION"])
    rind = [x[0] for x in accessor(doc, binary, rp["indices"])[0]]
    reverse = []
    for verts, offsets in components(rpos, rind):
        if len(verts) == 8 and len(offsets) == 6:
            for q in offsets: reverse.extend((rind[q], rind[q+2], rind[q+1]))
    assert len(reverse) == 298 * 6 * 3
    new_indices = rind + reverse
    while len(binary) % 4: binary.append(0)
    new_offset = len(binary)
    binary.extend(struct.pack("<" + "H"*len(new_indices), *new_indices))
    view_index = len(doc["bufferViews"])
    doc["bufferViews"].append({"buffer": 0, "byteOffset": new_offset, "byteLength": len(new_indices)*2, "target": 34963})
    ra = doc["accessors"][rp["indices"]]; ra["bufferView"] = view_index; ra["byteOffset"] = 0; ra["count"] = len(new_indices)
    return build(doc, binary)

def add_reed_back_normals(data):
    assert hashlib.sha256(data).hexdigest() == INTERMEDIATE_SHA256
    doc, binary = parse(data); rp = primitive(doc, "Reeds")
    original_count = doc["accessors"][rp["attributes"]["POSITION"]]["count"]
    assert original_count == 4751
    # Duplicate the entire Reeds vertex stream so every explicit back triangle can carry the
    # opposite normal. Unused duplicate cattail vertices are a small deterministic cost and keep
    # all four attribute streams aligned.
    for semantic in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"):
        old_index = rp["attributes"][semantic]
        old = doc["accessors"][old_index]; values, _ = accessor(doc, binary, old_index)
        code, _ = FMT[old["componentType"]]; n = NCOMP[old["type"]]
        second = [tuple(-x for x in v) for v in values] if semantic == "NORMAL" else values
        combined = values + second
        while len(binary) % 4: binary.append(0)
        offset = len(binary)
        flat = [x for value in combined for x in value]
        binary.extend(struct.pack("<" + code*len(flat), *flat))
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(binary)-offset, "target": 34962}
        view_index = len(doc["bufferViews"]); doc["bufferViews"].append(view)
        new = dict(old); new["bufferView"] = view_index; new["byteOffset"] = 0; new["count"] = len(combined)
        accessor_index = len(doc["accessors"]); doc["accessors"].append(new)
        rp["attributes"][semantic] = accessor_index
    indices = [x[0] for x in accessor(doc, binary, rp["indices"])[0]]
    assert len(indices) == 4187*3
    original_index_count = 2399*3
    indices[original_index_count:] = [i + original_count for i in indices[original_index_count:]]
    while len(binary) % 4: binary.append(0)
    offset = len(binary); binary.extend(struct.pack("<" + "H"*len(indices), *indices))
    view_index = len(doc["bufferViews"]); doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(indices)*2, "target": 34963})
    old = doc["accessors"][rp["indices"]]; new = dict(old); new["bufferView"] = view_index; new["byteOffset"] = 0
    accessor_index = len(doc["accessors"]); doc["accessors"].append(new); rp["indices"] = accessor_index
    return build(doc, binary)

if __name__ == "__main__":
    before = GLB.read_bytes()
    if "--check" in sys.argv:
        print(json.dumps(audit(before), sort_keys=True)); raise SystemExit(0)
    digest = hashlib.sha256(before).hexdigest()
    after = add_reed_back_normals(repair(before)) if digest == OLD_SHA256 else add_reed_back_normals(before)
    result = audit(after)
    assert result["crowns"] == result["crown_ok"] == result["crown_normals_ok"] == 39
    assert result["blades_double_sided"] == 298 and result["reed_triangles"] == 4187 and result["reed_normal_min"] > 0.6
    GLB.write_bytes(after)
    print(json.dumps(result, sort_keys=True))
