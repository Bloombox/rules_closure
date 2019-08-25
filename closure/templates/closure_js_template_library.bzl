# Copyright 2016 The Closure Rules Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utilities for compiling Closure Templates to JavaScript.
"""

load("//closure/compiler:closure_js_aspect.bzl", "closure_js_aspect")
load("//closure/compiler:closure_js_library.bzl", "closure_js_library")
load("//closure/templates:closure_template_library.bzl", "closure_template_library")
load("//closure/private:defs.bzl", "SOY_FILE_TYPE", "unfurl")

_SOYTOJSSRCCOMPILER = "@com_google_template_soy//:SoyToJsSrcCompiler"
_SOYTOINCREMENTALDOMSRCCOMPILER = "@com_google_template_soy//:SoyToIncrementalDomSrcCompiler"


def _impl(ctx):
    # fail if we get more than one dep (should be an abstract target)
#    if len(ctx.attr.deps) > 1:
#        fail("Provide maximum of 1 dependency to closure_js_template_library: an abstract template target.")

    if not ctx.attr.incremental_dom:
        args = ["--outputPathFormat=%s/{INPUT_DIRECTORY}/{INPUT_FILE_NAME}.js" %
                ctx.configuration.genfiles_dir.path]
        if ctx.attr.soy_msgs_are_external:
            args += ["--googMsgsAreExternal"]
        if ctx.attr.should_generate_soy_msg_defs:
            args += ["--shouldGenerateGoogMsgDefs"]
        if ctx.attr.bidi_global_dir:
            args += ["--bidiGlobalDir=%s" % ctx.attr.bidi_global_dir]
        if ctx.attr.plugin_modules:
            args += ["--pluginModules=%s" % ",".join(ctx.attr.plugin_modules)]
    else:
        args = ["--outputPathFormat=%s/{INPUT_DIRECTORY}/{INPUT_FILE_NAME}_idom.js" %
                ctx.configuration.genfiles_dir.path]
    args += ["--shouldPostfixNamespaces=false"]

    if ctx.attr.plugin_modules:
        args += ["--pluginModules=%s" % ",".join(ctx.attr.plugin_modules)]

    for arg in ctx.attr.defs:
        if not arg.startswith("--") or (" " in arg and "=" not in arg):
            fail("Please use --flag=value syntax for defs")
        args += [arg]

    inputs = []
    for f in ctx.files.srcs:
        args.append("--srcs=" + f.path)
        inputs.append(f)
    if ctx.file.globals:
        args += ["--compileTimeGlobalsFile", ctx.file.globals.path]
        inputs.append(ctx.file.globals)

    protodeps = []
    for dep in unfurl(ctx.attr.deps, provider = "closure_js_library"):
        dep_descriptors = getattr(dep.closure_js_library, "descriptors", None)
        if dep_descriptors:
            for f in dep_descriptors.to_list():
                if f not in protodeps:
                    protodeps.append(f)
                    args += ["--protoFileDescriptors=%s" % f.path]
                    inputs.append(f)

    soydeps = []
    for dep in unfurl(ctx.attr.deps, provider = "closure_tpl_library"):
        dep_templates = getattr(dep.closure_js_library, "outputs", None)
        if dep_templates:
            for f in dep_templates.to_list():
                soydeps.append(f.path)
                inputs.append(f)

    ## prep dependencies for the template, if we have any
    if len(soydeps) > 0:
        args += ["--depHeaders=%s" % ",".join(soydeps)]

    ctx.actions.run(
        inputs = inputs,
        outputs = ctx.outputs.outputs,
        executable = ctx.executable.compiler,
        arguments = args,
        mnemonic = "SoyCompiler",
        progress_message = "Generating %d SOY v2 JS file(s)" % len(
            ctx.attr.outputs,
        ),
    )

_closure_js_template_library = rule(
    implementation = _impl,
    output_to_genfiles = True,
    attrs = {
        "srcs": attr.label_list(allow_files = SOY_FILE_TYPE),
        "deps": attr.label_list(
            aspects = [closure_js_aspect],
            providers = ["closure_js_library"],
        ),
        "outputs": attr.output_list(),
        "globals": attr.label(allow_single_file = True),
        "plugin_modules": attr.label_list(),
        "should_generate_soy_msg_defs": attr.bool(),
        "bidi_global_dir": attr.int(default = 1, values = [1, -1]),
        "soy_msgs_are_external": attr.bool(),
        "incremental_dom": attr.bool(),
        "compiler": attr.label(cfg = "host", executable = True, mandatory = True),
        "defs": attr.string_list(),
    },
)


def closure_js_template_library(
        name,
        srcs,
        deps = [],
        suppress = [],
        incremental_dom = False,
        testonly = None,
        globals = None,
        plugin_modules = None,
        should_generate_soy_msg_defs = None,
        bidi_global_dir = None,
        soy_msgs_are_external = None,
        defs = [],
        **kwargs):
    if incremental_dom:
        compiler = str(Label(_SOYTOINCREMENTALDOMSRCCOMPILER))
        js_srcs = [src + "_idom.js" for src in srcs]
    else:
        compiler = str(Label(_SOYTOJSSRCCOMPILER))
        js_srcs = [src + ".js" for src in srcs]

    _closure_js_template_library(
        name = name + "_soy_js",
        srcs = srcs,
        deps = deps,
        outputs = js_srcs,
        testonly = testonly,
        visibility = ["//visibility:private"],
        globals = globals,
        plugin_modules = plugin_modules,
        should_generate_soy_msg_defs = should_generate_soy_msg_defs,
        bidi_global_dir = bidi_global_dir,
        soy_msgs_are_external = soy_msgs_are_external,
        compiler = compiler,
        incremental_dom = incremental_dom,
        defs = defs,
    )

    deps = deps + [
        str(Label("//closure/library/array")),
        str(Label("//closure/library/asserts")),
        str(Label("//closure/library/debug")),
        str(Label("//closure/library/format")),
        str(Label("//closure/library/html:safehtml")),
        str(Label("//closure/library/html:safescript")),
        str(Label("//closure/library/html:safestyle")),
        str(Label("//closure/library/html:safestylesheet")),
        str(Label("//closure/library/html:safeurl")),
        str(Label("//closure/library/html:trustedresourceurl")),
        str(Label("//closure/library/html:uncheckedconversions")),
        str(Label("//closure/library/i18n:bidi")),
        str(Label("//closure/library/i18n:bidiformatter")),
        str(Label("//closure/library/i18n:numberformat")),
        str(Label("//closure/library/object")),
        str(Label("//closure/library/soy:soy")),
        str(Label("//closure/library/soy:all_js")),
        str(Label("//closure/library/string")),
        str(Label("//closure/library/string:const")),
        str(Label("//closure/library/uri")),
        str(Label("//closure/templates:soy_jssrc")),
    ]

    if incremental_dom:
        deps = deps + [
            str(Label("//closure/templates:soy_jssrc_idom")),
            str(Label("@com_google_javascript_incremental_dom//:idom-js")),
        ]

    base_suppressions = []
    if incremental_dom:
        base_suppressions.append("superfluousSuppress")
        base_suppressions.append("strictModuleChecks")
        base_suppressions.append("extraRequire")
        base_suppressions.append("missingProperties")

    closure_js_library(
        name = name,
        srcs = js_srcs,
        deps = deps,
        testonly = testonly,
        suppress = base_suppressions + suppress + [
            "analyzerChecks",
            "reportUnknownTypes",
            "strictCheckTypes",
            "unusedLocalVariables",
            "undefinedNames"
        ],
        internal_templates = srcs,
        **kwargs
    )
