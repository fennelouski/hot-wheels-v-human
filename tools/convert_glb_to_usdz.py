# Convert one GLB to USDZ via headless Blender.
#
#   blender -b -P tools/convert_glb_to_usdz.py -- <in.glb> <out.usdz> [scale] [--anim]
#
# Prints "DIMENSIONS x y z" (post-scale, metres) so you can verify the
# Graphics/README rule: a track straight ends up ~0.4 m wide. Scale is
# baked at conversion time, never in code.
#
# --anim exports skeletal animation too. OFF by default because it's dead
# weight on the static track/car models (and Blender's USD exporter drops
# animation silently when it's off — the Kenney character packs came through
# with their skeleton but zero clips before this flag existed).

import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
animate = "--anim" in argv
argv = [a for a in argv if a != "--anim"]
# --action <name> keeps ONE clip. Blender's USD exporter bakes the scene
# TIMELINE, not glTF's named clips, so a Kenney character (32 actions:
# idle/walk/drive/sit/…) would otherwise export as one long reel cycling
# through every pose. Pick the action you want and the range follows it.
action = None
if "--action" in argv:
    i = argv.index("--action")
    action = argv[i + 1]
    del argv[i:i + 2]
    animate = True
src, dst = argv[0], argv[1]
scale = float(argv[2]) if len(argv) > 2 else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

if scale != 1.0:
    # Scale via a parent empty so node TRANSLATIONS scale too (Kenney GLBs
    # carry e.g. a -1 z offset on the root node; scaling the object itself
    # would leave that offset at full size).
    rig = bpy.data.objects.new("scale_rig", None)
    bpy.context.scene.collection.objects.link(rig)
    rig.scale = (scale, scale, scale)
    for obj in list(bpy.context.scene.objects):
        if obj.parent is None and obj is not rig:
            obj.parent = rig
    bpy.context.view_layer.update()

mins, maxs = [1e9] * 3, [-1e9] * 3
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], world[i])
                maxs[i] = max(maxs[i], world[i])
print("DIMENSIONS", *(round(maxs[i] - mins[i], 4) for i in range(3)))

# RealityKit ignores the USD upAxis metadata, so bake a Y-up orientation
# into the geometry (Blender Z-up -> (x, z, -y) in RealityKit).
if animate:
    start, end = 1, 1
    if action:
        clip = bpy.data.actions.get(action)
        if clip is None:
            names = sorted(a.name for a in bpy.data.actions)
            sys.exit(f"no action '{action}'. available: {names}")
        # Pin every armature to this one action so the timeline IS the clip.
        for obj in bpy.context.scene.objects:
            if obj.type == "ARMATURE":
                if obj.animation_data is None:
                    obj.animation_data_create()
                obj.animation_data.action = clip
        start, end = (int(round(v)) for v in clip.frame_range)
    else:
        for clip in bpy.data.actions:
            end = max(end, int(round(clip.frame_range[1])))
    bpy.context.scene.frame_start = start
    bpy.context.scene.frame_end = max(end, start + 1)
bpy.ops.wm.usd_export(filepath=dst, convert_orientation=True,
                      export_animation=animate)
print("WROTE", dst, "anim" if animate else "static")
