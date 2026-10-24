load(":video_modules.bzl", "video_driver_modules")
load(":video_driver_build.bzl", "define_target_variant_modules")
load(":target_variants.bzl", "get_all_la_variants", "get_all_le_variants")

def define_target_modules():
    for (t, v) in get_all_la_variants() + get_all_le_variants():
        define_target_variant_modules(
            target = t,
            variant = v,
            registry = video_driver_modules,
            modules = [
                "msm_video",
            ],
        )
