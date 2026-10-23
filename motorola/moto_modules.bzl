load("//build/kernel/kleaf:kernel.bzl", "ddk_module")

# DDK definitions of the Motorola out-of-tree modules.
#
# The Kbuild files of these modules only test make variables, none of them are
# Kconfig symbols. The variables a module is built with come from the
# KBUILD_OPTIONS of its Makefile in the LineageOS kernel_motorola_sm6475-modules
# tree. Variables that only some devices set are given per product and picked
# with --//vendor/motorola/sm6475:mmi_product=<product>.

MOTO_ROOT = "//vendor/motorola/sm6475-modules/motorola"

# (target, variant) pairs to define the modules for.
MOTO_TARGET_VARIANTS = [
    ("parrot", "consolidate"),
    ("parrot", "perf"),
]

def _evaluate(conditions, variables):
    """Values of the conditions met by variables; a "!VAR" key matches when VAR is unset."""
    result = []
    for condition, values in conditions.items():
        if condition.startswith("!"):
            met = condition[1:] not in variables
        else:
            met = condition in variables
        if met:
            result += [v for v in values if v not in result]
    return result

def _resolve(conditions, make_variables, product_make_variables):
    """Static list, or a select() over the products when some variables are product specific."""
    if not conditions:
        return []
    if not product_make_variables:
        return _evaluate(conditions, make_variables)

    branches = {"//conditions:default": _evaluate(conditions, make_variables)}
    for product, variables in product_make_variables.items():
        branches["//vendor/motorola/sm6475:mmi_product_{}".format(product)] = _evaluate(
            conditions,
            make_variables + variables,
        )
    return select(branches)

def moto_module(
        name,
        srcs,
        out = None,
        deps = [],
        includes = [],
        local_defines = [],
        copts = [],
        make_variables = [],
        product_make_variables = {},
        conditional_defines = {},
        conditional_srcs = {},
        conditional_copts = {},
        kernel_internal_headers = False):
    """Defines a Motorola module for every (target, variant) in MOTO_TARGET_VARIANTS.

    The module is named <target>_<variant>_<name>.

    Args:
      name: module name
      srcs: sources and private headers that are always built
      out: name of the .ko, defaults to <name>.ko
      deps: dependencies, %b is replaced with <target>_<variant>
      includes: include directories, relative to the package
      local_defines: unconditional defines
      copts: unconditional compiler options
      make_variables: make variables set for every product (Makefile KBUILD_OPTIONS)
      product_make_variables: dict of product -> additional make variables
      conditional_defines: dict of make variable -> defines (the Kbuild ifneq blocks)
      conditional_srcs: dict of make variable -> sources
      conditional_copts: dict of make variable -> compiler options
      kernel_internal_headers: whether the module includes kernel internal
        headers (kernel/sched, drivers/android, drivers/base)
    """
    common_deps = [
        "//vendor/motorola/sm6475:all_headers",
        MOTO_ROOT + ":public_headers",
    ]
    if kernel_internal_headers:
        common_deps.append("//vendor/motorola/sm6475:moto_kernel_internal_headers")

    for target, variant in MOTO_TARGET_VARIANTS:
        tv = "{}_{}".format(target, variant)

        ddk_module(
            name = "{}_{}".format(tv, name),
            out = out or "{}.ko".format(name),
            srcs = srcs + _resolve(conditional_srcs, make_variables, product_make_variables),
            includes = includes,
            local_defines = local_defines + _resolve(conditional_defines, make_variables, product_make_variables),
            copts = copts + _resolve(conditional_copts, make_variables, product_make_variables),
            deps = common_deps + [dep.replace("%b", tv) for dep in deps],
            kernel_build = "//vendor/motorola/sm6475:{}".format(tv),
            visibility = ["//visibility:public"],
        )

# Motorola modules built for each product: (path under drivers/, module name).
# Matches the modules loaded by device/motorola/sm6475-common.
_PRODUCT_MODULES = {
    "mona": [
        ("input/misc/goodix_fod_mmi", "goodix_fod_mmi"),
        ("input/misc/rbs_fod_mmi", "rbs_fod_mmi"),
        ("input/touchscreen/goodix_berlin_mmi", "goodix_brl_mmi"),
        ("input/touchscreen/touchscreen_mmi", "touchscreen_mmi"),
        ("misc/hall", "hall_pen"),
        ("misc/mmi_stow", "mmi_stow"),
        ("misc/mmi_sys_temp", "mmi_sys_temp"),
        ("misc/sx937x_multi", "sx937x_multi"),
        ("misc/utag", "utags"),
        ("mmi_annotate", "mmi_annotate"),
        ("mmi_info", "mmi_info"),
        ("mmi_relay", "mmi_relay"),
        ("moto_netopt/con_dfpar", "con_dfpar"),
        ("power/bm_adsp_ulog", "bm_adsp_ulog"),
        ("power/mmi_charger", "mmi_charger"),
        ("power/qpnp_adaptive_charge", "qpnp_adaptive_charge"),
        ("power/qti_glink_charger", "qti_glink_charger"),
        ("regulator/dio8015", "dio8015"),
        ("sensors", "sensors_class"),
    ],
}

def get_moto_product_modules(product):
    """Module label templates for define_qti_targets(extra_modules = ...)."""
    if product not in _PRODUCT_MODULES:
        fail("No Motorola modules defined for product {}".format(product))
    return [
        "{{root}}/motorola/drivers/{}:{{base}}_{{variant}}_{}".format(path, name)
        for path, name in _PRODUCT_MODULES[product]
    ]
