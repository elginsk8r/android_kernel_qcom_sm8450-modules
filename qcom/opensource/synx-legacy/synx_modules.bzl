load(":synx_module_build.bzl", "create_module_registry")

SYNX_KERNEL_ROOT = "synx-kernel-v1"

synx_modules = create_module_registry([":synx_headers"])
register_synx_module = synx_modules.register

register_synx_module(
    name = "synx-driver",
    path = "msm",
    srcs = [
        "synx/synx.c",
        "synx/synx_util.c",
        "synx/synx_debugfs.c",
    ],
)

register_synx_module(
    name = "qcom_ipc_lite",
    path = "msm",
    srcs = [
        "synx/qcom_ipc_lite.c",
    ],
)
