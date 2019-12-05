
"""Utilities for building Closure Templates (Soy).
"""

load(
    "//closure/private:defs.bzl",
    "SOY_FILE_TYPE",
    "SOY_HEADER_FILE_TYPE",
    "CLOSURE_JS_TOOLCHAIN_ATTRS",
    "collect_template_headers",
    "collect_runfiles",
    "unfurl",
)

load("//closure/compiler:closure_js_library.bzl", "create_closure_js_library")

_SOYHEADERCOMPILER = "@com_google_template_soy//:SoyHeaderCompiler"


def _template_impl(ctx):
    args = []
    for arg in ctx.attr.defs:
        if not arg.startswith("--") or (" " in arg and "=" not in arg):
            fail("Please use --flag=value syntax for defs")
        args += [arg]
    inputs = []
    for f in ctx.files.srcs:
        args.append("--srcs=" + f.path)
        inputs.append(f)
    hdeps = []
    protodeps = []
    protos = []
    for dep in unfurl(ctx.attr.deps, provider = "closure_js_library"):
        tpl_descriptors = getattr(dep.closure_js_library, "descriptors", None)
        if tpl_descriptors:
            for f in tpl_descriptors.to_list():
                if f.path not in protos:
                    protos.append(f.path)
                    args += ["--protoFileDescriptors=%s" % f.path]
                    inputs.append(f)
                    protodeps.append(dep)
        transitive_descriptors = getattr(dep.closure_js_library, "transitive_descriptors", None)
        if transitive_descriptors:
            for f in transitive_descriptors.to_list():
                if f.path not in protos:
                    protos.append(f.path)
                    args += ["--protoFileDescriptors=%s" % f.path]
                    inputs.append(f)
                    protodeps.append(dep)

        tpl_headers = getattr(dep.closure_js_library, "template_headers", None)
        if tpl_headers:
            for f in tpl_headers.to_list():
                args += ["--depHeaders=%s" % f.path]
                hdeps.append(f.path)
                inputs.append(f)

    args += ["--output=%s" % ctx.outputs.outputs[0].path]

    if ctx.attr.plugin_modules:
        args += ["--pluginModules=%s" % ",".join(ctx.attr.plugin_modules)]

    if ctx.file.globals:
        args += ["--compileTimeGlobalsFile", ctx.file.globals.path]
        inputs.append(ctx.file.globals)

    ctx.actions.run(
        inputs = inputs,
        outputs = ctx.outputs.outputs,
        executable = ctx.executable.compiler,
        arguments = args,
        mnemonic = "SoyHeaderCompiler",
        progress_message = "Generating %d SOY header(s)" % len(
            ctx.attr.outputs,
        ),
    )

    library = create_closure_js_library(
        ctx, [], [], [], [], True,
        _template_headers=ctx.outputs.outputs)

    return struct(
        exports = library.exports,
        closure_js_library = library.closure_js_library,
        closure_tpl_library = struct(
            srcs = ctx.files.srcs,
            outputs = ctx.outputs.outputs,
            protos = protodeps,
            headers = hdeps,
        )
    )


_closure_template_library = rule(
    output_to_genfiles = True,
    attrs = dict({
        "srcs": attr.label_list(allow_files = SOY_FILE_TYPE),
        "outputs": attr.output_list(),
        "globals": attr.label(allow_single_file = True),
        "plugin_modules": attr.label_list(),
        "deps": attr.label_list(providers = ["closure_js_library"]),
        "compiler": attr.label(cfg = "host", executable = True, mandatory = True),
        "defs": attr.string_list(),
    }, **CLOSURE_JS_TOOLCHAIN_ATTRS),
    implementation = _template_impl,
)


def closure_template_library(
        name,
        srcs,
        deps = [],
        plugin_modules = None,
        should_generate_soy_msg_defs = None,
        bidi_global_dir = None,
        soy_msgs_are_external = None,
        defs = [],
        **kwargs):

    """ Abstract rule for a Soy template. """

    _closure_template_library(
        name = name,
        srcs = srcs,
        deps = deps,
        compiler = str(Label(_SOYHEADERCOMPILER)),
        outputs = ["%s.soyh" % name],
        defs = defs,
    )
