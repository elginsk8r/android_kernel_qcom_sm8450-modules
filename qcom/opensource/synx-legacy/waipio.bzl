load(":synx_modules.bzl", "synx_modules")
load(":synx_module_build.bzl", "define_target_variant_modules")

def define_waipio():
    define_target_variant_modules(
        target = "waipio",
        variant = "perf",
        registry = synx_modules,
        modules = [
            "synx-driver",
            "qcom_ipc_lite",
        ],
        config_options = [
            "TARGET_SYNX_ENABLE",
            "CONFIG_MSM_GLOBAL_SYNX",
        ],
    )
