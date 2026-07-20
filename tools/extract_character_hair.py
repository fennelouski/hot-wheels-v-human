# Split Kenney Mini characters into a bald head + a detachable hair mesh.
#
#   blender -b -P tools/extract_character_hair.py -- <out-dir> [--preview]
#
# Why this exists: the roster's hair is baked into `head-mesh`, so HairStyle
# could only ever LAYER procedural geometry on top of hair that was already
# there (two of the four styles didn't visibly render at all). But the hair
# is modelled as disconnected geometry islands sitting on a skull that is
# byte-identical across all twelve characters — 76 polys, z 0.343…0.661,
# x ±0.16 — so it separates cleanly with no modelling and no new assets.
# The hairstyles we ship ARE the art, which is why nothing else matched the
# style: every downloadable CC0 pack with detachable hair is a different
# art direction (see Documents/OPEN-THREADS.md item 5).
#
# Outputs per character:
#   <id>-bald.glb   the character with its hair islands deleted
#   hair-<id>.glb   just those islands, origin moved to the head joint so
#                   DriverDressUp can pin it exactly like a hat
#
# character-male-b has no hair islands (he's the bald one) — he yields a
# bald body and no hair, which is the correct answer, not a failure.

import os
import sys

import bpy
from mathutils import Vector

SRC = "Graphics/3DModels/Source/kenney_mini-characters/Models/GLB format"
CHARACTERS = [f"character-{sex}-{v}"
              for sex in ("female", "male") for v in "abcdef"]

# The shared skull, measured identically in all twelve OBJs. Matched exactly
# rather than by "biggest island" so a bad match fails loudly instead of
# silently exporting someone's fringe as their head.
SKULL_POLYS = 76
SKULL_Z = (0.343, 0.661)
# Hair reaches onto the cranium; jaws don't. This is what keeps male-b's
# beard (tops out at 0.423) and everyone's ears, eyes and mouth attached to
# the bald head instead of being lifted off as a "hairstyle".
HAIR_MIN_TOP = 0.55
# ...and hair is never skin-coloured. Height alone left female-f's long side
# hair behind (it hangs to 0.624, below her crown) and her hair clips with
# it. Sampling the colormap separates hair from ears reliably: across all
# twelve, ears land within ~10 of their own skull's tone and hair no closer
# than ~40, so the gap is wide and the threshold isn't delicate.
SKIN_DISTANCE = 30.0


def islands(mesh):
    """Polygon indices grouped into connected islands.

    Blender's own "separate by loose parts" is useless here: the glTF import
    splits vertices at every UV/normal seam, so no two faces share a vertex
    and every face comes out its own part. Welding by POSITION first (which
    is how the same islands show up in the OBJ) recovers the real topology
    without touching the mesh — nothing is merged, only grouped.
    """
    weld = {}
    rep = []
    for v in mesh.vertices:
        key = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        rep.append(weld.setdefault(key, len(weld)))

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


def island_z(mesh, poly_indices):
    zs = [mesh.vertices[i].co.z
          for p in poly_indices for i in mesh.polygons[p].vertices]
    return min(zs), max(zs)


def colormap(mesh):
    """The character's colormap as (width, height, flat RGBA float list)."""
    for material in mesh.materials:
        if not material or not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                image = node.image
                return image.size[0], image.size[1], list(image.pixels)
    sys.exit("no colormap texture on the head material")


def island_colour(mesh, poly_indices, tex):
    """Mean texel under an island, 0-255 RGB."""
    width, height, pixels = tex
    uv = mesh.uv_layers.active.data
    us, vs = [], []
    for p in poly_indices:
        for loop in mesh.polygons[p].loop_indices:
            us.append(uv[loop].uv[0])
            vs.append(uv[loop].uv[1])
    x = min(width - 1, max(0, int(sum(us) / len(us) * width)))
    y = min(height - 1, max(0, int(sum(vs) / len(vs) * height)))
    i = (y * width + x) * 4
    return [pixels[i + c] * 255 for c in range(3)]


def classify(mesh):
    """(skull, hair) as lists of polygon indices."""
    tex = colormap(mesh)
    groups = islands(mesh)
    skull = None
    for group in groups:
        lo, hi = island_z(mesh, group)
        if (len(group) == SKULL_POLYS
                and abs(lo - SKULL_Z[0]) < 0.005 and abs(hi - SKULL_Z[1]) < 0.005):
            skull = group
    if skull is None:
        return None, []

    skin = island_colour(mesh, skull, tex)
    hair = []
    for group in groups:
        if group is skull:
            continue
        if island_z(mesh, group)[1] <= HAIR_MIN_TOP:
            continue
        colour = island_colour(mesh, group, tex)
        if sum((a - b) ** 2 for a, b in zip(colour, skin)) ** 0.5 > SKIN_DISTANCE:
            hair.append(group)
    return skull, [p for g in hair for p in g]


def separate_polys(obj, poly_indices):
    """Split `poly_indices` off `obj` into a new object; returns it.

    Clearing vertex AND edge flags matters: entering edit mode rebuilds the
    face selection from the vertices, so setting only `polygon.select` while
    stale vertex flags are set hands `separate` the WHOLE mesh. That took the
    entire head off every character instead of just the hair, and the export
    still succeeded — caught by comparing poly counts, not by eye.
    """
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mesh = obj.data
    for v in mesh.vertices:
        v.select = False
    for e in mesh.edges:
        e.select = False
    for p in mesh.polygons:
        p.select = False
    for i in poly_indices:
        mesh.polygons[i].select = True
        for vi in mesh.polygons[i].vertices:
            mesh.vertices[vi].select = True

    before = {o.name for o in bpy.context.scene.objects}
    bpy.context.tool_settings.mesh_select_mode = (False, False, True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    made = [o for o in bpy.context.scene.objects if o.name not in before]
    if len(made) != 1:
        sys.exit(f"separate produced {len(made)} objects, expected 1")
    if len(made[0].data.polygons) != len(poly_indices):
        sys.exit(f"separate took {len(made[0].data.polygons)} polys, "
                 f"expected {len(poly_indices)}")
    return made[0]


def head_joint_z(armature):
    bone = armature.data.bones.get("head")
    return (armature.matrix_world @ bone.head_local).z if bone else 0.0


def load(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{SRC}/{name}.glb")
    # The GLBs import with a stray unparented Icosphere (no material) —
    # Kenney's turntable prop. It is not part of the character.
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and not obj.data.materials and obj.parent is None:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    head = next(o for o in bpy.context.scene.objects
                if o.type == "MESH" and o.name.startswith("head-mesh"))
    return armature, head


def process(name, out_dir):
    armature, head = load(name)
    skull, hair = classify(head.data)
    if skull is None:
        sys.exit(f"{name}: no skull island matched — the roster's shared "
                 f"skull is the anchor for all of this, so refusing to guess")
    print(f"CLASSIFY {name} polys={len(head.data.polygons)} "
          f"hair_polys={len(hair)}")

    # --- hair prop, origin at the head joint ---
    if hair:
        joint_z = head_joint_z(armature)
        prop = separate_polys(head, hair)
        # Unparent from the armature and drop the skinning: the prop rides
        # the posed head joint via HeadPinSystem, exactly like a hat, so a
        # second skinned copy of the rig would just be dead weight.
        prop.parent = None
        prop.modifiers.clear()
        prop.vertex_groups.clear()
        for v in prop.data.vertices:
            v.co.z -= joint_z
        prop.name = f"hair-{name}"
        for obj in list(bpy.context.scene.objects):
            if obj is not prop:
                bpy.data.objects.remove(obj, do_unlink=True)
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(out_dir, f"hair-{name}.glb"),
            export_format="GLB", use_selection=False)

    # --- bald character: same import, hair polygons deleted ---
    armature, head = load(name)
    _, hair = classify(head.data)
    if hair:
        doomed = separate_polys(head, hair)
        bpy.data.objects.remove(doomed, do_unlink=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, f"{name}-bald.glb"),
        export_format="GLB", use_selection=False)


argv = sys.argv[sys.argv.index("--") + 1:]
out_dir = argv[0]
os.makedirs(out_dir, exist_ok=True)
for character in CHARACTERS:
    process(character, out_dir)
print("DONE")
