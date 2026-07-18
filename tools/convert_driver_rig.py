# Convert the Quaternius rigged human into per-reaction USDZ clips.
#
#   blender -b -P tools/convert_driver_rig.py
#
# One USDZ per reaction state (RealityKit plays a USDZ's single animation
# timeline; separate files = separate clips, ~200 KB each). Orientation is
# baked Y-up exactly like convert_glb_to_usdz.py. Also renders a preview
# PNG per clip into /tmp so a human (or agent) can eyeball the pose.

import os

import bpy

SRC = "Graphics/3DModels/Source/quaternius_animated_human/FBX/Animated Human.fbx"
OUT = "Hot Wheels v Human/Resources/Models3D"
PREVIEW = os.environ.get("DRIVER_PREVIEW_DIR", "")

# reaction state -> source action name suffix (probed 2026-07-18)
CLIPS = {
    "driver-idle": "Idle",        # steady driving
    "driver-crash": "Death",      # destruction reaction
    "driver-cheer": "Jump",       # win celebration
    "driver-boost": "Punch",      # boost push-back
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
if arm.animation_data is None:
    arm.animation_data_create()

for out_name, suffix in CLIPS.items():
    action = next(a for a in bpy.data.actions if a.name.endswith("|" + suffix))
    arm.animation_data.action = action
    start, end = action.frame_range
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = int(start), int(end)
    scene.frame_set(int(start))
    dst = os.path.join(OUT, out_name + ".usdz")
    bpy.ops.wm.usd_export(filepath=dst, convert_orientation=True,
                          export_animation=True, export_armatures=True)
    print("WROTE", dst, "frames", int(start), "-", int(end))

    if PREVIEW:
        scene.frame_set(int((start + end) / 2))
        cam_data = bpy.data.cameras.new("cam")
        cam = bpy.data.objects.new("cam", cam_data)
        scene.collection.objects.link(cam)
        cam.location = (0, -4.5, 1.2)
        cam.rotation_euler = (1.45, 0, 0)
        scene.camera = cam
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.resolution_x = scene.render.resolution_y = 400
        scene.render.filepath = os.path.join(PREVIEW, out_name + ".png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam)
