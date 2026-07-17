# Convert one GLB to USDZ via headless Blender.
#
#   blender -b -P tools/convert_glb_to_usdz.py -- <in.glb> <out.usdz> [scale]
#
# Prints "DIMENSIONS x y z" (post-scale, metres) so you can verify the
# Graphics/README rule: a track straight ends up ~0.4 m wide. Scale is
# baked at conversion time, never in code.

import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
scale = float(argv[2]) if len(argv) > 2 else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

if scale != 1.0:
    for obj in bpy.context.scene.objects:
        if obj.parent is None:
            obj.scale = (scale, scale, scale)
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

bpy.ops.wm.usd_export(filepath=dst)
print("WROTE", dst)
