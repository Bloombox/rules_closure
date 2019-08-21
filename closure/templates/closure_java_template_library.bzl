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

"""Utilities for compiling Closure Templates to Java.
"""

load("//closure/compiler:closure_js_aspect.bzl", "closure_js_aspect")
load("//closure/compiler:closure_js_library.bzl", "closure_js_library")
load("//closure/templates:closure_template_library.bzl", "closure_template_library")
load("//closure/private:defs.bzl", "SOY_FILE_TYPE", "unfurl")

_SOY_COMPILER_BIN = "@com_google_template_soy//:SoyParseInfoGenerator"
_SOY_LIBRARY = "@com_google_template_soy//:com_google_template_soy"


def _impl(ctx):
    out_prefix = _soy__dirname([s for s in ctx.files.srcs][0].path)
    args = ["--outputDirectory=%s/%s" %
        (ctx.configuration.genfiles_dir.path, out_prefix)]
    args.append("--javaPackage=%s" % ctx.attr.java_package)
    args.append("--javaClassNameSource=filename")

    for arg in ctx.attr.defs:
        if not arg.startswith("--") or (" " in arg and "=" not in arg):
            fail("Please use --flag=value syntax for defs")
        args += [arg]
    inputs = []
    for f in ctx.files.srcs:
        args.append("--srcs=" + f.path)
        inputs.append(f)

    for dep in unfurl(ctx.attr.deps, provider = "closure_js_library"):
        dep_descriptors = getattr(dep.closure_js_library, "descriptors", None)
        if dep_descriptors:
            for f in dep_descriptors.to_list():
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
        mnemonic = "SoyJavaCompiler",
        progress_message = "Generating %d SOY v2 Java file(s)" % len(
            ctx.attr.outputs,
        ),
    )

_closure_java_template_library = rule(
    implementation = _impl,
    output_to_genfiles = True,
    attrs = {
        "java_package": attr.string(),
        "srcs": attr.label_list(allow_files = SOY_FILE_TYPE),
        "deps": attr.label_list(
            aspects = [closure_js_aspect],
            providers = ["closure_js_library"],
        ),
        "outputs": attr.output_list(),
        "compiler": attr.label(cfg = "host", executable = True, mandatory = True),
        "defs": attr.string_list(),
    },
)


# Generates a java_library with the SoyFileInfo and SoyTemplateInfo
# for all templates.
#
# For each Soy input called abc_def.soy, a Java class AbcDefSoyInfo will be
# generated.  For a template in that file called foo.barBaz, you can reference
# its info as AbcDefSoyInfo.BAR_BAZ.
#
# srcs: an explicit file list of soy files to scan.
# java_package: the package for the Java files that are generated. If not
#     given, defaults to the package from which this function was invoked.
# deps: Soy files that these templates depend on, in order for
#     templates to include the parameters of templates they call.
# filegroup_name: will create a filegroup suitable for use as a
#     dependency by another soy_java_wrappers rule
# extra_srcs: any build rule that provides Soy files that should be used
#     as additional sources. For these, an extra_outs must be provided for each
#     Java file expected. Useful for generating Java wrappers for Soy files not
#     in the Java tree.
# extra_outs: extra output files from the dependencies that are requested;
#     useful if for generating wrappers for files that are not in the Java tree
# allow_external_calls: Whether to allow external soy calls (i.e. calls to
#     undefined templates). This parameter is passed to SoyParseInfoGenerator and
#     it defaults to true.
# soycompilerbin: Optional Soy to ParseInfo compiler target.
def closure_java_template_library(
        name,
        java_package = None,
        srcs = [],
        deps = [],
        filegroup_name = None,
        extra_srcs = [],
        extra_outs = [],
        allow_external_calls = False,
        root_directory = None,
        soycompilerbin = str(Label(_SOY_COMPILER_BIN)),
        **kwargs):
    proto_deps = [dep for dep in deps if "proto" in dep]
    java_package = java_package or _soy__GetJavaPackageForCurrentDirectory(root_directory)

    # Strip off the .soy suffix from the file name and camel-case it, preserving
    # the case of directory names, if any.
    outs = [
        (_soy__dirname(fn) + _soy__camel(_soy__filename(fn)[:-4]) +
         "SoyInfo.java").replace("-", "")
        for fn in srcs
    ]
    defs = []
    if allow_external_calls:
        defs.append("--allowExternalCalls=" + str(allow_external_calls))

    _closure_java_template_library(
        name = name + "_soy_java",
        java_package = java_package,
        srcs = srcs + extra_srcs,
        deps = deps,
        outputs = outs + extra_outs,
        compiler = soycompilerbin,
        defs = defs,
    )

    java_protos = [proto.replace("-closure_proto", "") for proto in proto_deps]
    java_protos = [("%s-java_proto" % proto) for proto in java_protos]

    if len(java_protos) > 0:
        java_protos += ["@com_google_protobuf//:protobuf_java"]

    # Now, wrap them in a Java library, and expose the Soy files as resources.
    java_srcs = outs + extra_outs
    native.java_library(
        name = name,
        srcs = java_srcs or None,
        exports = [str(Label(_SOY_LIBRARY))],
        deps = ([
            "@com_google_guava",
            "@javax_annotation_jsr250_api",
            str(Label(_SOY_LIBRARY)),
        ] + java_protos) if java_srcs else None,  # b/13630760
        resources = srcs + extra_srcs,
        **kwargs
    )

    if filegroup_name != None:
        # Create a filegroup with all the dependencies.
        native.filegroup(
            name = filegroup_name,
            srcs = srcs + extra_srcs + deps,
            **kwargs
        )

# The output file for abc_def.soy is AbcDefSoyInfo.java. Handle camelcasing
# for both underscores and digits: css3foo_bar is Css3FooBarSoyInfo.java.
def _soy__camel(str):
    last = "_"
    result = ""
    for index in range(len(str)):
        ch = str[index]
        if ch != "_":
            if (last >= "a" and last <= "z") or (last >= "A" and last <= "Z"):
                result += ch
            else:
                result += ch.upper()
        last = ch
    return result

def _soy__dirname(file):
    return file[:file.rfind("/") + 1]

def _soy__filename(file):
    return file[file.rfind("/") + 1:]

def _soy__GetJavaPackageForCurrentDirectory(root_dir):
    """Returns the java package corresponding to the current directory."""
    directory = native.package_name()
    for prefix in (root_dir or "java/", "javatests/"):
        if directory.startswith(prefix):
            if root_dir:
                return ".".join(directory.split("/"))
            return ".".join(directory[len(prefix):].split("/"))
        i = directory.find("/" + prefix)
        if i != -1:
            return ".".join(directory[i + len(prefix) + 1:].split("/"))
    fail("Unable to infer java package from directory: " + directory)
