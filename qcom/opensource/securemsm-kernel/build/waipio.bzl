load(":securemsm_kernel.bzl", "define_consolidate_gki_modules")

def define_waipio():
    define_consolidate_gki_modules(
        target = "waipio",
        modules = [
            "smcinvoke_dlkm",
            "tz_log_dlkm",
            "qce50_dlkm",
            "qcedev-mod_dlkm",
            "qrng_dlkm",
            "qseecom_dlkm",
        ],
        extra_options = [
            "CONFIG_QCOM_SMCINVOKE",
            "CONFIG_QSEECOM",
        ],
    )
