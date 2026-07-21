#!/usr/bin/env python3
# Which patch of Kenney's shared `colormap.png` each roster character wears
# for skin, shirt, pants and shoes — emitted as the Swift table in
# `Core/Models/RosterColormap.swift`.
#
# Why this exists: the twelve Mini Characters have their whole appearance
# painted into one shared 512x512 colormap, so the stripe palette that dresses
# the old Quaternius rig does nothing to them (see DriverPainter.apply's
# `bakedAppearance`). That left the editor's Skin, Shirt and Pants swatches
# changing a saved value and nothing on screen.
#
# The colormap is an 8x8 grid of 64px cells, but one MATERIAL is a vertical
# PAIR of cells — a light row over a dark row, which is its shading ramp. So
# the unit meaning "one garment" is a patch: 8 columns x 4 row-pairs.
# Recolouring a body part = rewriting one patch. Working in patch space
# rather than matching colours is what keeps the shading intact and stops two
# garments that share a shade from bleeding into each other.
#
# Run:  blender -b -P tools/extract_roster_palette.py
# Then paste the printed table into RosterColormap.swift. Check the trailing
# colour comments against Graphics/.../Previews/*.png before trusting it —
# the band thresholds below are geometry heuristics, not gospel.

import os
import sys

import bpy

SRC = "Graphics/3DModels/Source/kenney_mini-characters/Models/GLB format"
CHARACTERS = [f"character-{sex}-{v}"
              for sex in ("female", "male") for v in "abcdef"]

GRID = 8
ROWS_PER_PATCH = 2
# The shared 76-poly skull, matched exactly like extract_character_hair.py —
# whatever patch it samples IS this character's skin, hands included.
SKULL_POLYS = 76
SKULL_Z = (0.343, 0.661)
# The eyes are a small, dark, front-of-face island near eye height, separate
# from the skull. On a few characters they get their OWN colormap cell (so the
# Eyes swatch can recolour them); on the rest that cell is ALSO the hair or a
# garment, and since Kenney's palette maps every poly of a cell to one flat
# texel, eyes and that garment are the exact same pixels — inseparable, so we
# emit `eyes: None` and leave them the sheet's dark default.
EYE_MAX_POLYS = 40
EYE_Z = (0.38, 0.55)
# Garments, as fractions of the BODY mesh's own height (its top is the
# shoulders — the head is a separate mesh). Gaps between the bands are
# deliberate: the waist and ankles are where two garments meet, and a vote
# taken across a seam is a coin toss.
BANDS = {"shoes": (0.00, 0.18), "pants": (0.25, 0.50), "shirt": (0.72, 1.01)}


def patch_of(poly, uv):
    """The colormap patch (row-pair, col) a polygon samples."""
    u = sum(uv[l].uv[0] for l in poly.loop_indices) / poly.loop_total
    v = sum(uv[l].uv[1] for l in poly.loop_indices) / poly.loop_total
    col = min(GRID - 1, max(0, int(u * GRID)))
    # Blender's V is bottom-up; the PNG's rows are top-down.
    row = min(GRID - 1, max(0, int((1.0 - v) * GRID)))
    return row // ROWS_PER_PATCH, col


def texel(image, poly, uv):
    """Colour under a polygon, read from Blender's bottom-up pixel buffer.
    Carried through only so the emitted table can be eyeballed."""
    u = sum(uv[l].uv[0] for l in poly.loop_indices) / poly.loop_total
    v = sum(uv[l].uv[1] for l in poly.loop_indices) / poly.loop_total
    w, h = image.size
    i = (min(h - 1, int(v * h)) * w + min(w - 1, int(u * w))) * 4
    return "#%02X%02X%02X" % tuple(round(image.pixels[i + c] * 255) for c in range(3))


def colormap_image():
    """The one texture every character shares. Read from bpy.data, not the
    material graph: `body-mesh` reaches it through a node tree the material
    API no longer exposes the same way."""
    images = [im for im in bpy.data.images if im.size[0] and im.size[1]]
    if not images:
        sys.exit("no colormap image in the imported file")
    return images[0]


def islands(mesh):
    """Polygon indices grouped into connected islands, welded by position.

    Same reason as extract_character_hair.py: the glTF import splits vertices
    at every UV/normal seam, so connectivity has to be recovered by position
    or every face comes out as its own island.
    """
    weld, rep = {}, []
    for v in mesh.vertices:
        key = tuple(round(c, 5) for c in v.co)
        rep.append(weld.setdefault(key, len(weld)))
    parent = list(range(len(mesh.polygons)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    owner = {}
    for i, poly in enumerate(mesh.polygons):
        for vert in poly.vertices:
            k = rep[vert]
            if k in owner:
                a, b = find(owner[k]), find(i)
                if a != b:
                    parent[a] = b
            owner[k] = i
    groups = {}
    for i in range(len(mesh.polygons)):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())


def roles(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    # Every file also ships an `Icosphere` — a colour-reference ball parked
    # off to the side that samples nearly every patch on the sheet. Left in,
    # it out-votes the actual clothes. Only the two body meshes count.
    meshes = {o.name: o.data for o in bpy.data.objects
              if o.type == "MESH" and o.name.endswith("-mesh")}
    head, body = meshes.get("head-mesh"), meshes.get("body-mesh")
    if head is None or body is None:
        sys.exit(f"{name}: expected head-mesh + body-mesh, got {list(meshes)}")

    image = colormap_image()
    swatches = {}
    for mesh in (head, body):
        uv = mesh.uv_layers.active.data
        for poly in mesh.polygons:
            swatches.setdefault(patch_of(poly, uv), texel(image, poly, uv))

    skin = None
    uv = head.uv_layers.active.data
    for group in islands(head):
        zs = [head.vertices[i].co.z
              for p in group for i in head.polygons[p].vertices]
        if (len(group) == SKULL_POLYS
                and abs(min(zs) - SKULL_Z[0]) < 0.005
                and abs(max(zs) - SKULL_Z[1]) < 0.005):
            skin = patch_of(head.polygons[group[0]], uv)
    if skin is None:
        sys.exit(f"{name}: no skull island — the roster changed, fix SKULL_*")

    # Eyes + the hair island: both come off the head. Hair is the LARGEST
    # non-skull head island; eyes are a SMALL dark island at eye height. When
    # they share a patch (dark hair), there's no separate small eye island and
    # `eye_patch` stays None.
    hair_island = max((g for g in islands(head)
                       if patch_of(head.polygons[g[0]], uv) != skin),
                      key=len, default=None)
    hair_patch = patch_of(head.polygons[hair_island[0]], uv) if hair_island else None
    eye_patch = None
    for group in islands(head):
        p = patch_of(head.polygons[group[0]], uv)
        if p == skin or p == hair_patch or len(group) > EYE_MAX_POLYS:
            continue
        zs = [head.vertices[i].co.z
              for poly in group for i in head.polygons[poly].vertices]
        mid = (min(zs) + max(zs)) / 2
        r, g_, b = (int(swatches[p][i:i+2], 16) for i in (1, 3, 5))
        if EYE_Z[0] <= mid <= EYE_Z[1] and (0.299*r + 0.587*g_ + 0.114*b) < 100:
            eye_patch = p

    # Garments come off the BODY mesh alone, so hair can't win a vote.
    uv = body.uv_layers.active.data
    heights = {}
    for poly in body.polygons:
        z = sum(body.vertices[v].co.z for v in poly.vertices) / len(poly.vertices)
        heights.setdefault(patch_of(poly, uv), []).append(z)
    top = max(z for zs in heights.values() for z in zs)

    picked = {}
    for role, (lo, hi) in BANDS.items():
        votes = {patch: sum(1 for z in zs if lo * top <= z < hi * top)
                 for patch, zs in heights.items() if patch != skin}
        votes = {p: n for p, n in votes.items() if n}
        picked[role] = max(votes, key=votes.get) if votes else skin
    # A repainted garment sharing the eye cell makes the eyes that garment's
    # colour — the exact bug this catches. Drop the eye patch there so we don't
    # promise a swatch we can't honour.
    if eye_patch in (picked["shirt"], picked["pants"], skin):
        eye_patch = None
    return skin, picked["shirt"], picked["pants"], picked["shoes"], eye_patch, swatches


print("\n// Generated by tools/extract_roster_palette.py — do not hand-edit.")
print("    static let patches: [String: Patches] = [")
for character in CHARACTERS:
    skin, shirt, pants, shoes, eyes, swatches = roles(character)
    eyes_arg = f", eyes: {list(eyes)}" if eyes else ""
    print(f'        "{character}": .init(skin: {list(skin)}, shirt: {list(shirt)}, '
          f'pants: {list(pants)}, shoes: {list(shoes)}{eyes_arg}),'
          f'   // skin {swatches[skin]} shirt {swatches[shirt]} '
          f'pants {swatches[pants]} shoes {swatches[shoes]}'
          f'{" eyes " + swatches[eyes] if eyes else ""}')
print("    ]")
