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

"""Build definitions for Closure Stylesheet libraries."""

load(
    "//closure/private:defs.bzl",
    "SOY_FILE_TYPE",
    "SOY_HEADER_FILE_TYPE",
    "CLOSURE_JS_TOOLCHAIN_ATTRS",
    "collect_template_headers",
    "collect_runfiles",
    "unfurl",
)

_SOYHEADERCOMPILER = "@com_google_template_soy//:SoyHeaderCompiler"


def _lib_impl(ctx):
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
    for dep in unfurl(ctx.attr.deps, provider = "closure_js_library"):
        tpl_descriptors = getattr(dep.closure_js_library, "descriptors", None)
        if tpl_descriptors:
            for f in tpl_descriptors.to_list():
                args += ["--protoFileDescriptors=%s" % f.path]
                inputs.append(f)

        tpl_headers = getattr(dep.closure_js_library, "template_headers", None)
        if tpl_headers:
            for f in tpl_headers.to_list():
                hdeps.append(f.path)
                inputs.append(f)

    if len(hdeps) > 0:
       args += ["--depHeaders=%s" % ",".join(hdeps)]
    args += ["--output=%s" % ctx.outputs.outputs[0]]

    ctx.actions.run(
        inputs = inputs,
        outputs = ctx.outputs.outputs,
        executable = ctx.executable.compiler,
        arguments = args,
        mnemonic = "SoyHeaderCompiler",
        progress_message = "Generating %d SOY header file(s)" % len(
            ctx.attr.outputs,
        ),
    )

def _closure_tpl_library(ctx):
    deps = unfurl(ctx.attr.deps, provider = "closure_tpl_library")
    tpls = collect_template_headers(deps)
    _lib_impl(ctx)

    return struct(
        files = depset(),
        exports = unfurl(ctx.attr.exports),
        closure_js_library = struct(),
        closure_tpl_library = struct(
            srcs = depset(ctx.files.srcs, transitive = [tpls.srcs]),
            labels = depset([ctx.label], transitive = [tpls.labels]),
        ),
        runfiles = ctx.runfiles(
            files = ctx.files.srcs + ctx.files.data,
            transitive_files = depset(
                transitive = [collect_runfiles(deps), collect_runfiles(ctx.attr.data)],
            ),
        ),
    )

_closure_template_library = rule(
    implementation = _closure_tpl_library,
    output_to_genfiles = True,
    attrs = {
        "srcs": attr.label_list(allow_files = SOY_FILE_TYPE),
        "outputs": attr.output_list(),
        "data": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = ["closure_tpl_library"]),
        "compiler": attr.label(cfg = "host", executable = True, mandatory = True),
        "defs": attr.string_list(),
        "exports": attr.label_list(),
    },
)

def closure_template_library(
    name,
    srcs = [],
    data = [],
    deps = [],
    defs = []):

    """Implements closure template libraries."""

    _closure_template_library(
        name = name,
        srcs = srcs,
        deps = deps,
        data = data,
        defs = defs,
        outputs = ["%s.soyh" % name],
        compiler = _SOYHEADERCOMPILER)
