load("@rules_pkg//pkg:install.bzl", "pkg_install")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files", "strip_prefix")
load(
    "//build/kernel/kleaf:kernel.bzl",
    "kernel_module_group",
    "kernel_modules_install",
)
load(":target_kernel.bzl", "define_qti_kernel", "DEFAULT_KERNEL_ROOT", "DEFAULT_MODULE_ROOT")

def define_qti_dist(
        target,
        msm_target,
        variant = "perf",
        extra_modules = None,
        dist_prefix = "qcom",
        kernel_root = DEFAULT_KERNEL_ROOT,
        module_root = DEFAULT_MODULE_ROOT):
    """
    Product-level dist targets.
    Reuses the pre-defined kernel for `msm_target` and optionally
    adds product-specific modules.
    """

    if extra_modules:
        product_modules = [
            m.format(
                root = module_root,
                target = target,
                base = msm_target,
                variant = variant,
            ) if "{root}" in m or "{target}" in m or "{base}" in m or "{variant}" in m else m
            for m in extra_modules
        ]

        kernel_module_group(
            name = "{}_external_modules".format(target),
            srcs = [
                "{}:{}_external_modules".format(module_root, msm_target)
            ] + product_modules,
        )

        kernel_modules_install(
            name = "{}_modules_install".format(target),
            kernel_build = "{}:{}_{}".format(kernel_root, msm_target, variant),
            kernel_modules = [":{}_external_modules".format(target)],
        )
        modules_install_label = ":{}_modules_install".format(target)
    else:
        modules_install_label = "{}:{}_modules_install".format(module_root, msm_target)

    pkg_files(
        name = "{}_uapi_headers_dist_files".format(target),
        srcs = [
            "{}:{}_merged_kernel_uapi_headers".format(module_root, msm_target)
        ],
    )

    pkg_install(
        name = "{}_uapi_headers_dist".format(target),
        srcs = [":{}_uapi_headers_dist_files".format(target)],
        destdir = "out/{}_{}/dist".format(dist_prefix, target),
    )

    pkg_files(
        name = "{}_dist_files".format(target),
        srcs = [
            "{}:{}_{}".format(kernel_root, msm_target, variant),
            modules_install_label,
            ":{}_uapi_headers_dist_files".format(target),
            "{}:kernel_aarch64".format(kernel_root),
            "{}:kernel_aarch64_modules".format(kernel_root),
            "{}:kernel_aarch64_images_system_dlkm_image".format(kernel_root),
        ],
        strip_prefix = strip_prefix.files_only(),
    )

    pkg_install(
        name = "{}_dist".format(target),
        srcs = [":{}_dist_files".format(target)],
        destdir = "out/{}_{}/dist".format(dist_prefix, target),
    )

def define_qti_platform(target, variant = "perf", dist_prefix = "qcom", extra_modules = []):
    define_qti_kernel(
        target = target,
        variant = variant,
        extra_modules = extra_modules,
    )
    define_qti_dist(
        target = target,
        msm_target = target,
        dist_prefix = dist_prefix,
    )
