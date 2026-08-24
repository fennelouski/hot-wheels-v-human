#!/usr/bin/env python3
# Renders the iPad home screen's tile art: one picture of the actual toy per
# button, so a kid who can't read yet can still find "Build a Car".
#
# Same idea as the decoration box's 243 thumbnails, and the same trick — a PNG
# of the real model beats a glyph in a game whose whole subject is toys. Two
# tiles have no toy to photograph and stay SF Symbols in the view: "Race on TV"
# (no TV model exists in any pack) and "Garage" (Kenney's pit garage has
# "TANKCO." branding baked into its texture, which is fine as trackside
# scenery and wrong on a kid's home screen).
#
# Rendered from the SOURCE GLBs, not the bundled USDZs: the toy-car kit and the
# roster share one atlas texture, and Blender's USD importer collapses that UV
# lookup to a single texel — every model comes out the same flat brown. The
# glTF importer gets it right, and these are the same meshes either way.
#
# One camera and one two-light rig for every tile, so the set reads as a set.
# Transparent background: the art sits on the button's own tint.
#
# Run:  blender -b -P tools/render_tile_art.py
# Output: Hot Wheels v Human/Resources/Thumbs/tile-*.png (loose PNGs, loaded by
# URL — see DecorPaletteView.thumb for why named-image lookup isn't used).

import math
import os
import sys

import bpy
from mathutils import Vector

TOY = "Graphics/3DModels/Source/kenney_toy-car-kit/Models/GLB format"
CAST = "Graphics/3DModels/Source/kenney_mini-characters/Models/GLB format"
OUT = "Hot Wheels v Human/Resources/Thumbs"
# Each tile is rendered TIGHT to its own subject: the canvas takes the object's
# aspect rather than a fixed one. A fixed canvas bakes empty margin into the
# PNG, and the card then fits that padded image again — double letterboxing,
# which had the toys reading smaller than the two SF Symbols beside them.
# Tight PNGs mean `scaledToFit` puts every toy at the same height on screen.
# 320 px tall = 2x the card's 84 pt strip, with headroom.
HEIGHT = 320
MIN_ASPECT, MAX_ASPECT = 1.0, 2.4

# tile name -> the models on it. More than one is laid out side by side,
# spaced from their MEASURED widths rather than a guessed offset.
TILES = {
    "build-car":  [f"{TOY}/vehicle-speedster.glb"],
    "build-track": [f"{TOY}/track-narrow-looping.glb"],
    # A visibly DIFFERENT car from the one on "Build a Car" — this tile is
    # about the rival, and two orange speedsters side by side read as one
    # button repeated.
    "race-robot": [f"{TOY}/vehicle-racer.glb"],
    "my-racers":  [f"{CAST}/character-male-a.glb"],
    "two-player": [f"{CAST}/character-male-a.glb",
                   f"{CAST}/character-female-d.glb"],
}
# Characters are rigged, and their BIND pose is a T-pose with the arms flung
# out — framed on that, the figure shrinks to nothing in a square tile. Posing
# them first costs one line and doubles how big they read.
POSE = "idle"


def load(glb):
    """Import one model, posed, with Kenney's turntable prop removed.

    Every character GLB ships a stray unparented Icosphere with no material —
    a colour-reference ball parked off to the side. It renders as nothing but
    it counts toward the bounds, which framed the figure at a third of the
    tile. `extract_character_hair.py` drops it by the same heuristic.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    made = set(bpy.data.objects) - before
    for o in list(made):
        if o.type == "MESH" and not o.data.materials and o.parent is None:
            made.discard(o)
            bpy.data.objects.remove(o, do_unlink=True)
    arm = next((o for o in made if o.type == "ARMATURE"), None)
    if arm is not None:
        action = next((a for a in bpy.data.actions if a.name == POSE), None)
        if action is not None:
            if not arm.animation_data:
                arm.animation_data_create()
            arm.animation_data.action = action
            bpy.context.scene.frame_set(int(action.frame_range[0]))
    bpy.context.view_layer.update()
    return [o for o in made if o.type == "MESH"], [o for o in made if o.parent is None]


def bounds(objs):
    """World-space bounds of the POSED meshes, so framing sees what renders."""
    deps = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        ev = o.evaluated_get(deps)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            pts.append(ev.matrix_world @ v.co)
        ev.to_mesh_clear()
    lo = Vector(min(p[i] for p in pts) for i in range(3))
    hi = Vector(max(p[i] for p in pts) for i in range(3))
    return lo, hi


def render(name, parts):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    cursor = 0.0
    for glb in parts:
        meshes, roots = load(glb)
        if not meshes:
            sys.exit(f"{name}: nothing imported from {glb}")
        lo, hi = bounds(meshes)
        width = (hi - lo).x
        if objs:
            # Shoulder to shoulder with a tenth of a body between them, so the
            # pair reads as two people rather than one wide blob.
            shift = cursor + width * 0.6 - (lo.x + hi.x) / 2
            for r in roots:
                r.location.x += shift
            bpy.context.view_layer.update()
            cursor += width * 1.1
        else:
            cursor = width * 0.55
        objs += meshes
    lo, hi = bounds(objs)
    centre = (lo + hi) / 2
    span = max((hi - lo).x, (hi - lo).y, (hi - lo).z)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_y = HEIGHT
    scene.render.film_transparent = True
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.5

    cam_data = bpy.data.cameras.new("c")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("c", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    dist = span * 3
    cam.location = centre + Vector((dist * 0.62, -dist * 0.72, dist * 0.46))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()

    # Fit in CAMERA space, not world space. A world-space "biggest dimension"
    # guess is wrong for anything that isn't roughly cubic — it framed the
    # two-up tile on its width and left the figures half-height.
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    corners = [inv @ Vector((x, y, z))
               for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    cx = [c.x for c in corners]
    cy = [c.y for c in corners]
    mid_x, mid_y = (min(cx) + max(cx)) / 2, (min(cy) + max(cy)) / 2
    ext_x, ext_y = max(cx) - min(cx), max(cy) - min(cy)
    # Canvas takes the subject's shape, clamped so nothing comes out a sliver.
    aspect = min(MAX_ASPECT, max(MIN_ASPECT, ext_x / ext_y))
    width = int(round(HEIGHT * aspect))
    scene.render.resolution_x = width
    # ortho_scale spans the LARGER render dimension, so height needs the
    # aspect factored back in.
    cam_data.ortho_scale = max(ext_x, ext_y * aspect) * 1.06
    # Recentre: nudge the camera along its own axes so the toy sits dead centre.
    cam.location += cam.matrix_world.to_3x3() @ Vector((mid_x, mid_y, 0))

    key = bpy.data.lights.new("key", "SUN")
    key.energy = 4.0
    key_obj = bpy.data.objects.new("key", key)
    scene.collection.objects.link(key_obj)
    key_obj.rotation_euler = (math.radians(52), 0, math.radians(38))
    fill = bpy.data.lights.new("fill", "SUN")
    fill.energy = 1.4
    fill_obj = bpy.data.objects.new("fill", fill)
    scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(70), 0, math.radians(-120))

    scene.render.filepath = os.path.abspath(os.path.join(OUT, f"tile-{name}.png"))
    bpy.ops.render.render(write_still=True)
    print("WROTE", scene.render.filepath)


os.makedirs(OUT, exist_ok=True)
for name, parts in TILES.items():
    render(name, parts)
print("DONE")
