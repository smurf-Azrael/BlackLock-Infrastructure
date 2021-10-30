# Copyright 2015 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Bazel macros to declare gRPC libraries automatically generated from proto files.

This file declares two macros:
- objc_proto_library
- objc_grpc_library
"""

def _lower_underscore_to_upper_camel(str):
    humps = []
    for hump in str.split("_"):
        humps += [hump[0].upper() + hump[1:]]
    return "".join(humps)

def _file_to_upper_camel(src):
    elements = src.rpartition("/")
    upper_camel = _lower_underscore_to_upper_camel(elements[-1])
    return "".join(elements[:-1] + [upper_camel])

def _file_with_extension(src, ext):
    elements = src.rpartition("/")
    basename = elements[-1].partition(".")[0]
    return "".join(elements[:-1] + [basename, ext])

def _protoc_invocation(srcs, flags):
    """Returns a command line to invoke protoc from a genrule, on the given
    sources, using the given flags.
    """
    protoc_command = "$(location //external:protoc) -I . "
    srcs_params = ""
    for src in srcs:
        srcs_params += " $(location %s)" % (src)
    return protoc_command + flags + srcs_params

def objc_proto_library(name, srcs, visibility = None):
    """Declares an objc_library for the code generated by protoc from the given
    proto sources. This generated code doesn't include proto services.
    """
    h_files = []
    m_files = []
    for src in srcs:
        src = _file_to_upper_camel(src)
        h_files += [_file_with_extension(src, ".pbobjc.h")]
        m_files += [_file_with_extension(src, ".pbobjc.m")]

    protoc_flags = "--objc_out=$(GENDIR)"

    native.genrule(
        name = name + "_codegen",
        srcs = srcs + ["//external:protoc"],
        outs = h_files + m_files,
        cmd = _protoc_invocation(srcs, protoc_flags),
    )
    native.objc_library(
        name = name,
        hdrs = h_files,
        includes = ["."],
        non_arc_srcs = m_files,
        deps = ["//external:protobuf_objc"],
        visibility = visibility,
    )

def objc_grpc_library(name, services, other_messages, visibility = None):
    """Declares an objc_library for the code generated by gRPC and protoc from the
    given proto sources (services and other_messages). The generated code doesn't
    include proto services of the files passed as other_messages.
    """
    objc_proto_library(name + "_messages", services + other_messages)

    h_files = []
    m_files = []
    for src in services:
        src = _file_to_upper_camel(src)
        h_files += [_file_with_extension(src, ".pbrpc.h")]
        m_files += [_file_with_extension(src, ".pbrpc.m")]

    protoc_flags = ("--grpc_out=$(GENDIR) --plugin=" +
                    "protoc-gen-grpc=$(location //external:grpc_protoc_plugin_objc)")

    native.genrule(
        name = name + "_codegen",
        srcs = services + [
            "//external:grpc_protoc_plugin_objc",
            "//external:protoc",
        ],
        outs = h_files + m_files,
        cmd = _protoc_invocation(services, protoc_flags),
    )
    native.objc_library(
        name = name,
        hdrs = h_files,
        includes = ["."],
        srcs = m_files,
        deps = [
            ":" + name + "_messages",
            "//external:proto_objc_rpc",
        ],
        visibility = visibility,
    )

