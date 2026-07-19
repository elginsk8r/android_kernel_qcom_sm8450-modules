load("@rules_pkg//pkg:install.bzl", "pkg_install")
load("@rules_pkg//pkg:mappings.bzl", "pkg_files", "strip_prefix")
load("//build/kernel/kleaf:hermetic_tools.bzl", "hermetic_genrule")
load(
    "//build/kernel/kleaf:kernel.bzl",
    "ddk_uapi_headers",
    "kernel_abi",
    "kernel_module_group",
    "kernel_modules_install",
)

DEFAULT_MODULE_ROOT = "//vendor/qcom/sm8450-modules"

# Default mapping of module identifiers to path templates
DEFAULT_COMMON_MODULES = {
    "audio": "{root}/qcom/opensource/audio-kernel:{target}_{variant}_modules",
    "bt_fm_slim": "{root}/qcom/opensource/bt-kernel:{target}_{variant}_bt_fm_slim",
    "btpower": "{root}/qcom/opensource/bt-kernel:{target}_{variant}_btpower",
    "bt_radio": "{root}/qcom/opensource/bt-kernel:{target}_{variant}_radio-i2c-rtc6226-qca",
    "camera": "{root}/qcom/opensource/camera-kernel:{target}_{variant}_camera",
    "ipa_gsim": "{root}/qcom/opensource/dataipa:{target}_{variant}_gsim",
    "ipa_ipam": "{root}/qcom/opensource/dataipa:{target}_{variant}_ipam",
    "ipa_ipanetm": "{root}/qcom/opensource/dataipa:{target}_{variant}_ipanetm",
    "rmnet_aps": "{root}/qcom/opensource/datarmnet-ext/aps:{target}_{variant}_aps",
    "rmnet_mem": "{root}/qcom/opensource/datarmnet-ext/mem:{target}_{variant}_rmnet_mem",
    "rmnet_offload": "{root}/qcom/opensource/datarmnet-ext/offload:{target}_{variant}_offload",
    "rmnet_variant": "{root}/qcom/opensource/datarmnet-ext/{variant}:{target}_{variant}_{variant}",
    "rmnet_tether": "{root}/qcom/opensource/datarmnet-ext/{variant}_tether:{target}_{variant}_{variant}_tether",
    "rmnet_sch": "{root}/qcom/opensource/datarmnet-ext/sch:{target}_{variant}_sch",
    "rmnet_shs": "{root}/qcom/opensource/datarmnet-ext/shs:{target}_{variant}_shs",
    "rmnet_wlan": "{root}/qcom/opensource/datarmnet-ext/wlan:{target}_{variant}_wlan",
    "rmnet_core": "{root}/qcom/opensource/datarmnet:{target}_{variant}_rmnet_core",
    "rmnet_ctl": "{root}/qcom/opensource/datarmnet:{target}_{variant}_rmnet_ctl",
    "display": "{root}/qcom/opensource/display-drivers:{target}_{variant}_display_drivers",
    "video": "{root}/qcom/opensource/video-driver:{target}_{variant}_video_modules",
    "dsp_cdsp": "{root}/qcom/opensource/dsp-kernel:{target}_{variant}_cdsp-loader",
    "dsp_frpc": "{root}/qcom/opensource/dsp-kernel:{target}_{variant}_frpc-adsprpc",
    "kgsl": "{root}/qcom/opensource/graphics-kernel:{target}_{variant}_msm_kgsl",
    "ext_display": "{root}/qcom/opensource/mm-drivers/msm_ext_display:{target}_{variant}_msm_ext_display",
    "sync_fence": "{root}/qcom/opensource/mm-drivers/sync_fence:{target}_{variant}_sync_fence",
    "mmrm": "{root}/qcom/opensource/mmrm-driver:{target}_{variant}_mmrm_driver",
    "qce50": "{root}/qcom/opensource/securemsm-kernel:{target}_{variant}_qce50_dlkm",
    "qcedev": "{root}/qcom/opensource/securemsm-kernel:{target}_{variant}_qcedev-mod_dlkm",
    "qrng": "{root}/qcom/opensource/securemsm-kernel:{target}_{variant}_qrng_dlkm",
    "qseecom": "{root}/qcom/opensource/securemsm-kernel:{target}_{variant}_qseecom_dlkm",
    "smcinvoke": "{root}/qcom/opensource/securemsm-kernel:{target}_{variant}_smcinvoke_dlkm",
    "tz_log": "{root}/qcom/opensource/securemsm-kernel:{target}_{variant}_tz_log_dlkm",
    "cnss2": "{root}/qcom/opensource/wlan/platform:{target}_{variant}_cnss2",
    "cnss_nl": "{root}/qcom/opensource/wlan/platform:{target}_{variant}_cnss_nl",
    "cnss_ipc": "{root}/qcom/opensource/wlan/platform:{target}_{variant}_cnss_plat_ipc_qmi_svc",
    "cnss_prealloc": "{root}/qcom/opensource/wlan/platform:{target}_{variant}_cnss_prealloc",
    "cnss_utils": "{root}/qcom/opensource/wlan/platform:{target}_{variant}_cnss_utils",
    "wlan_fw_svc": "{root}/qcom/opensource/wlan/platform:{target}_{variant}_wlan_firmware_service",
    "qcacld": "{root}/qcom/opensource/wlan/qcacld-3.0:{target}_{variant}_qca_cld_qca6750",
}

def get_default_uapi_headers(module_root = DEFAULT_MODULE_ROOT):
    return [
        "{}/qcom/opensource/audio-kernel:audio_uapi_headers".format(module_root),
        "{}/qcom/opensource/dataipa:ipa_uapi_headers".format(module_root),
        "{}/qcom/opensource/display-drivers:uapi_headers".format(module_root),
    ]

def define_qti_targets(
        target,
        base = None,
        variant = "perf",
        extra_modules = None,
        target_modules = None,
        module_path_map = None,
        uapi_headers = None,
        dist_prefix = "qcom",
        module_root = DEFAULT_MODULE_ROOT):
    """
    Macro that defines external module groups and installation targets.
    Supports inheriting, module path mapping overrides, and target-renaming modules.
    """

    if not target_modules:
        target_modules = []

        for key, template in DEFAULT_COMMON_MODULES.items():
            # If the module key was explicitly overridden in module_path_map, use target
            if module_path_map and key in module_path_map:
                override_template = module_path_map[key]
                target_modules.append(
                    override_template.format(root = module_root, target = target, variant = variant)
                )
            else:
                # Otherwise, fall back to base (if set) or target
                eval_target = base if base else target
                target_modules.append(
                    template.format(root = module_root, target = eval_target, variant = variant)
                )

        # Append target-specific extra modules if defined
        if extra_modules:
            target_modules.extend([
                m.format(root = module_root, target = target, variant = variant) if "{root}" in m or "{target}" in m or "{variant}" in m else m
                for m in extra_modules
            ])

    if not uapi_headers:
        uapi_headers = get_default_uapi_headers(module_root)

    kernel_target = base if base else target
    kernel_build_ref = "//vendor/qcom/kernel:{}_{}".format(kernel_target, variant)

    kernel_module_group(
        name = "{}_external_modules".format(target),
        srcs = target_modules,
    )

    kernel_modules_install(
        name = "{}_modules_install".format(target),
        kernel_build = kernel_build_ref,
        kernel_modules = [
            ":{}_external_modules".format(target),
        ],
    )

    ddk_out_tarball = "{}-ddk-uapi-headers.tar.gz".format(target)
    merged_out_tarball = "{}-kernel-uapi-headers.tar.gz".format(target)

    ddk_uapi_headers(
        name = "{}_ddk_uapi_headers".format(target),
        srcs = uapi_headers,
        out = ddk_out_tarball,
        kernel_build = kernel_build_ref,
    )

    hermetic_genrule(
        name = "{}_merged_kernel_uapi_headers".format(target),
        srcs = [
            "//vendor/qcom/kernel:{}_{}_uapi_headers".format(target, variant),
            ":{}_ddk_uapi_headers".format(target),
        ],
        outs = [
            merged_out_tarball,
        ],
        cmd = """
            mkdir -p out
            tar -xzf $$(find bazel-out/ -name {target}_{variant}_uapi_headers.tar.gz -o -name kernel-uapi-headers.tar.gz -print -quit) -C out
            tar -xzf $$(find bazel-out/ -name {ddk_out} -print -quit) -C out
            tar -czf $(@D)/{merged_out} . -C out
        """.format(
            target = target,
            variant = variant,
            ddk_out = ddk_out_tarball,
            merged_out = merged_out_tarball,
        ),
    )

    pkg_files(
        name = "{}_uapi_headers_dist_files".format(target),
        srcs = [
            ":{}_merged_kernel_uapi_headers".format(target),
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
            kernel_build_ref,
            ":{}_modules_install".format(target),
            ":{}_uapi_headers_dist_files".format(target),
            "//vendor/qcom/kernel:kernel_aarch64",
            "//vendor/qcom/kernel:kernel_aarch64_modules",
            "//vendor/qcom/kernel:kernel_aarch64_images_system_dlkm_image",
        ],
        strip_prefix = strip_prefix.files_only(),
    )

    pkg_install(
        name = "{}_dist".format(target),
        srcs = [":{}_dist_files".format(target)],
        destdir = "out/{}_{}/dist".format(dist_prefix, target),
    )

    kernel_abi(
        name = "{}_abi".format(target),
        kernel_build = kernel_build_ref,
        kernel_modules = [
            ":{}_external_modules".format(target),
        ],
        module_grouping = False,
    )
