#!/usr/bin/env python3
# Cuts the mobility aid out of `character-female-a`'s body mesh.
#
# Why: Kenney's Mini Characters is an accessibility pack, and female-a is
# modelled WITH forearm crutches — welded into `body-mesh`, rigidly bound to
# the arm and leg joints. Standing in the bind pose that reads fine. In this
# game she is sitting in a race car, and the `drive` clip swings those joints
# independently, so the shafts and cuffs scatter into loose blocks floating
# around her — the "stray triangles flying out from the person's body" bug.
# Nothing in RealityKit can hide part of one mesh with one material, so the
# geometry has to go at conversion time. She stays; only the crutches leave.
#
# She is the ONLY one of the twelve wider than the shared 0.3836 arm span
# (she reaches 0.5494), and the aid is the only geometry she has that no other
# roster character does — which is how this finds it, rather than by a
# hand-typed vertex list that would rot the moment Kenney re-exports.
#
# The bald cut needs the same treatment — tools/extract_character_hair.py
# only touches the HEAD, so the aid is still on the body it hands back. Pass
# its output in as an extra input:
#
#   blender -b -P tools/extract_character_hair.py -- <tmp>
#   blender -b -P tools/strip_mobility_aid.py -- <out_dir> \
#       <tmp>/character-female-a-bald.glb
#
# Then convert BOTH emitted GLBs, both poses, at the roster scale:
#   for g in character-female-a character-female-a-bald; do
#     for p in idle drive; do
#       blender -b -P tools/convert_glb_to_usdz.py -- \
#         <out_dir>/$g.glb "Hot Wheels v Human/Resources/Models3D/$g-$p.usdz" \
#         10.73 --anim --action $p
#     done
#   done

import os
import sys

import bpy

SRC = "Graphics/3DModels/Source/kenney_mini-characters/Models/GLB format"
TARGET = "character-female-a"
OTHERS = [f"character-{sex}-{v}"
          for sex in ("female", "male") for v in "abcdef" if f"character-{sex}-{v}" != TARGET]
# What the aid comes to once found. Asserted, not assumed: a silent partial
# match here would export a woman missing an arm, and it would still look
# plausible in a thumbnail.
EXPECT_ISLANDS = 8
EXPECT_POLYS = 176


def islands(mesh):
    """Polygon indices grouped into connected islands, welded by position.

    Same reason as tools/extract_character_hair.py: the glTF import splits
    vertices at every UV/normal seam, so no two faces share a vertex and
    Blender's own "separate by loose parts" hands back one part per face.
    """
    weld, rep = {}, []
    for v in mesh.vertices:
        rep.append(weld.setdefault(tuple(round(c, 4) for c in v.co), len(weld)))
    parent = list(range(len(weld)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for poly in mesh.polygons:
        roots = [find(rep[i]) for i in poly.vertices]
        for r in roots[1:]:
            if r != roots[0]:
                parent[r] = roots[0]
    grouped = {}
    for poly in mesh.polygons:
        grouped.setdefault(find(rep[poly.vertices[0]]), []).append(poly.index)
    return list(grouped.values())


def signature(mesh, group):
    """A shape fingerprint that survives being mirrored to the other side.

    Face count plus the island's bounding-box dimensions, rounded to a
    tenth of a millimetre. `abs` on nothing — the box dims are already
    side-agnostic, which is what lets a left crutch match a right one and a
    left forearm match every other character's.
    """
    pts = [mesh.vertices[i].co for p in group for i in mesh.polygons[p].vertices]
    dims = tuple(round(max(p[a] for p in pts) - min(p[a] for p in pts), 4)
                 for a in range(3))
    return (len(group), dims)


def body_of(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    obj = next((o for o in bpy.data.objects
                if o.type == "MESH" and o.name == "body-mesh"), None)
    if obj is None:
        sys.exit(f"{name}: no body-mesh")
    return obj


def separate_polys(obj, poly_indices):
    """Split `poly_indices` off `obj` into a new object; returns it.

    Clearing vertex AND edge flags matters — entering edit mode rebuilds the
    face selection from the vertices, so stale flags hand `separate` the whole
    mesh. That mistake cost tools/extract_character_hair.py a silent bad
    export once already; same guard here.
    """
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="OBJECT")
    # Deselect every OBJECT first. glTF import leaves the whole file selected,
    # and Blender enters edit mode on all selected objects at once — so the
    # head goes into the same edit session and `separate` splits it too. That
    # is how the first run of this tool exported a body with no head on it.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for v in obj.data.vertices:
        v.select = False
    for e in obj.data.edges:
        e.select = False
    for poly in obj.data.polygons:
        poly.select = poly.index in poly_indices
    before = set(bpy.data.objects)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    made = set(bpy.data.objects) - before
    if len(made) != 1:
        sys.exit(f"separate produced {len(made)} objects, expected 1")
    return made.pop()


# --- every island shape the OTHER eleven characters have between them ---
known = set()
for other in OTHERS:
    mesh = body_of(other).data
    for group in islands(mesh):
        known.add(signature(mesh, group))

# --- female-a's islands that match nothing on anyone else ---
body = body_of(TARGET)
groups = islands(body.data)
aid = [g for g in groups if signature(body.data, g) not in known]
polys = sum(len(g) for g in aid)
print(f"AID islands={len(aid)} polys={polys} of {len(body.data.polygons)}")
for g in aid:
    print("   ", signature(body.data, g))
if (len(aid), polys) != (EXPECT_ISLANDS, EXPECT_POLYS):
    sys.exit(f"expected {EXPECT_ISLANDS} islands / {EXPECT_POLYS} polys — the "
             f"pack changed, re-verify with a render before trusting this")

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir, extras = argv[0], argv[1:]
os.makedirs(out_dir, exist_ok=True)

# The signatures of the aid itself, so the same cut lands on any variant of
# her (the bald head, a future re-export) without re-deriving it there.
aid_signatures = {signature(body.data, g) for g in aid}


def strip(path, out_name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    obj = next(o for o in bpy.data.objects
               if o.type == "MESH" and o.name == "body-mesh")
    doomed_polys = {p for g in islands(obj.data)
                    if signature(obj.data, g) in aid_signatures for p in g}
    if len(doomed_polys) != EXPECT_POLYS:
        sys.exit(f"{path}: matched {len(doomed_polys)} polys, expected {EXPECT_POLYS}")
    bpy.data.objects.remove(separate_polys(obj, doomed_polys), do_unlink=True)
    dest = os.path.join(out_dir, out_name)
    bpy.ops.export_scene.gltf(filepath=dest, export_format="GLB",
                              use_selection=False)
    print("WROTE", dest)


strip(os.path.join(SRC, TARGET + ".glb"), f"{TARGET}.glb")
for extra in extras:
    strip(extra, os.path.basename(extra))
