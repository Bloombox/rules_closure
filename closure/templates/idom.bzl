
package(default_visibility = ["//visibility:public"])

load("@io_bloombox_labs_NEURON//defs:closure.bzl",
     "closure_js_library",
     "closure_ts_library")

suppressions = [
    "JSC_UNKNOWN_EXPR_TYPE",
    "jsdocMissingType",
    "extraRequire",
    "unusedLocalVariables",
    "JSC_IMPLICITLY_NULLABLE_JSDOC"]


## Files: TSC Config
filegroup(
    name = "idom-tsconfig",
    srcs = ["tsconfig.json"])


## Files: Closure Dist
closure_js_library(
    name = "idom-types-js",
    srcs = ["dist/closure/release/types.js"],
    suppress = ["JSC_IMPLICITLY_NULLABLE_JSDOC"])

closure_js_library(
    name = "idom-debug-js",
    srcs = ["dist/closure/release/debug.js"])

closure_js_library(
    name = "idom-global-js",
    srcs = ["dist/closure/release/global.js"],
    deps = [":idom-debug-js"])

closure_js_library(
    name = "idom-assertions-js",
    srcs = ["dist/closure/release/assertions.js"],
    deps = [
        ":idom-global-js",
        ":idom-types-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-symbols-js",
    srcs = ["dist/closure/release/symbols.js"])

closure_js_library(
    name = "idom-util-js",
    srcs = ["dist/closure/release/util.js"],
    suppress = ["JSC_UNKNOWN_EXPR_TYPE"] + suppressions)

closure_js_library(
    name = "idom-attributes-js",
    srcs = ["dist/closure/release/attributes.js"],
    deps = [
        ":idom-types-js",
        ":idom-assertions-js",
        ":idom-symbols-js",
        ":idom-util-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-changes-js",
    srcs = ["dist/closure/release/changes.js"],
    deps = [":idom-util-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-notifications-js",
    srcs = ["dist/closure/release/notifications.js"])

closure_js_library(
    name = "idom-context-js",
    srcs = ["dist/closure/release/context.js"],
    deps = [":idom-notifications-js"],
    suppress = [
        "JSC_UNKNOWN_EXPR_TYPE",
        "JSC_IMPLICITLY_NULLABLE_JSDOC"])

closure_js_library(
    name = "idom-dom_util-js",
    srcs = ["dist/closure/release/dom_util.js"],
    deps = [":idom-notifications-js", ":idom-assertions-js"],
    suppress = ["JSC_UNKNOWN_EXPR_TYPE"] + suppressions)

closure_js_library(
    name = "idom-node_data-js",
    srcs = ["dist/closure/release/node_data.js"],
    deps = [
        ":idom-util-js",
        ":idom-assertions-js",
        ":idom-dom_util-js",
        ":idom-global-js",
        ":idom-types-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-nodes-js",
    srcs = ["dist/closure/release/nodes.js"],
    deps = [
        ":idom-node_data-js",
        ":idom-types-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-core-js",
    srcs = ["dist/closure/release/core.js"],
    deps = [
        ":idom-assertions-js",
        ":idom-context-js",
        ":idom-dom_util-js",
        ":idom-global-js",
        ":idom-node_data-js",
        ":idom-nodes-js",
        ":idom-types-js"],
    suppress = suppressions + ["JSC_OPTIONAL_PARAM_NOT_MARKED_OPTIONAL"])

closure_js_library(
    name = "idom-diff-js",
    srcs = ["dist/closure/release/diff.js"],
    deps = [
        ":idom-changes-js",
        ":idom-util-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-virtual_elements-js",
    srcs = ["dist/closure/release/virtual_elements.js"],
    deps = [
        ":idom-assertions-js",
        ":idom-attributes-js",
        ":idom-core-js",
        ":idom-global-js",
        ":idom-node_data-js",
        ":idom-types-js",
        ":idom-diff-js",
        ":idom-util-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-index-js",
    srcs = ["dist/closure/index.js"],
    deps = [
        ":idom-attributes-js",
        ":idom-core-js",
        ":idom-global-js",
        ":idom-node_data-js",
        ":idom-notifications-js",
        ":idom-symbols-js",
        ":idom-virtual_elements-js"],
    suppress = suppressions)

closure_js_library(
    name = "idom-js",
    exports = [":idom-index-js"])
