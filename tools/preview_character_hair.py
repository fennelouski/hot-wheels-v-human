# Render the extracted hair library for eyeballing.
#
#   blender -b -P tools/preview_character_hair.py -- <work-dir> <out-dir>
#
# Two things need human eyes before any of this ships:
#   1. every bald head is CLEAN — no hole where the hair was lifted off
#   2. every hairstyle sits right on a head that isn't the one it came from
# so this renders each bald character, and one base wearing all 11 styles.

import glob
import os
import sys
from math import radians

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
work, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)

BASE = "character-male-b-bald"   # the roster's own bald man: no extraction
                                 # happened on him, so he's a control


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 400
    scene.render.resolution_y = 460
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
    scene.world = world

    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # Head-and-shoulders three-quarter view: hair is a silhouette feature,
    # so a dead-on front view is the one angle that hides the point.
    cam.location = (0.62, -0.78, 0.86)
    cam.rotation_euler = (radians(72), 0, radians(38))
    cam_data.lens = 60

    light_data = bpy.data.lights.new("key", type="AREA")
    light_data.energy = 90
    light_data.size = 3
    light = bpy.data.objects.new("key", light_data)
    light.location = (1.4, -1.8, 2.4)
    light.rotation_euler = (radians(40), 0, radians(38))
    scene.collection.objects.link(light)


def load(path):
    before = {o.name for o in bpy.context.scene.objects}
    bpy.ops.import_scene.gltf(filepath=path)
    added = [o for o in bpy.context.scene.objects if o.name not in before]
    for obj in list(added):                # drop Kenney's turntable prop
        if obj.type == "MESH" and not obj.data.materials and obj.parent is None:
            added.remove(obj)
            bpy.data.objects.remove(obj, do_unlink=True)
    return added


def head_joint_z():
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    return (arm.matrix_world @ arm.data.bones["head"].head_local).z


def shot(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# 1. every bald character, to check for holes
for glb in sorted(glob.glob(f"{work}/*-bald.glb")):
    fresh()
    load(glb)
    shot(os.path.join(out, os.path.basename(glb).replace(".glb", ".png")))

# 2. one base wearing every extracted hairstyle
for glb in sorted(glob.glob(f"{work}/hair-*.glb")):
    fresh()
    load(f"{work}/{BASE}.glb")
    z = head_joint_z()
    for obj in load(glb):
        obj.location.z += z            # the prop's origin IS the head joint
    shot(os.path.join(out, "worn-" + os.path.basename(glb).replace(".glb", ".png")))

print("DONE")
