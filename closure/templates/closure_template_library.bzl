# Copyright 2018 The Closure Rules Authors. All rights reserved.
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

"""Utilities for building generic Soy templates.
"""

load("//closure/compiler:closure_js_library.bzl", "create_closure_js_library")
load("//closure/private:defs.bzl", "CLOSURE_JS_TOOLCHAIN_ATTRS", "unfurl")


def _closure_tpl_header_output_name(src):
    # src is of format <path/to/file>.soy
    return ["{}.soyh".format(src[:-4])]


def _closure_tpl_aspect_impl(target, ctx):
    srcs = proto_common.lang_proto_aspect_impl(
        actions = ctx.actions,
        toolchain = ctx.toolchains[proto_common.TOOLCHAIN_TYPE],
        flavor = "Closure",
        get_generator_options = _closure_proto_options,
        get_generator_options_params = struct(
            testonly = getattr(ctx.rule.attr, "testonly", False),
        ),
        get_output_files = _closure_tpl_header_output_name,
        language = "proto",
        target = target,
    )

    deps = unfurl(ctx.rule.attr.deps, provider = "closure_js_library")
    deps += [ctx.attr._closure_protobuf_runtime]

    suppress = [
        "missingProperties",
        "unusedLocalVariables",
    ]

    protoinfo = getattr(target, "proto", None)
    if protoinfo == None:
        fail("No protoinfo for target: %s" % target)

    direct_descriptor = getattr(protoinfo, "direct_descriptor_set", None)
    if direct_descriptor == None:
        fail("No direct descriptor for target: %s" % target)

    transitive_descriptor_sets = getattr(protoinfo, "transitive_descriptor_sets", None)
    if transitive_descriptor_sets == None:
        transitive_descriptor_sets = []

    library = create_closure_js_library(
        ctx, srcs, deps, [], suppress, True,
        _proto_target=direct_descriptor,
        _transitive_proto_targets=transitive_descriptor_sets)

    return struct(
        exports = library.exports,
        closure_js_library = library.closure_js_library,
    )

closure_tpl_aspect = proto_common.lang_proto_aspect(
    attrs = dict({
        # internal only
        "_closure_protobuf_runtime": attr.label(
            default = Label("//closure/protobuf:runtime"),
        ),
    }, **CLOSURE_JS_TOOLCHAIN_ATTRS),
    implementation = _closure_proto_aspect_impl,
    provides = [
        "closure_js_library",
        "exports",
    ],
)

def _closure_tpl_library_impl(ctx):
    if len(ctx.attr.deps) > 1:
        # TODO(yannic): Revisit this restriction.
        fail(_error_multiple_deps, "deps")

    dep = ctx.attr.deps[0]
    return struct(
        files = depset(),
        exports = dep.exports,
        closure_js_library = dep.closure_js_library,
    )

closure_proto_library = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            providers = [ProtoInfo],
            aspects = [closure_proto_aspect],
        ),
    },
    implementation = _closure_proto_library_impl,
)
