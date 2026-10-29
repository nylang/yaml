// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief YAML product and corpus contracts across implementation modules. */
module YamlTests;
part "a_yaml_selftest.ny";
part "parse_selftest.ny";
part "reader_selftest.ny";
part "document_selftest.ny";
part "writer_selftest.ny";
part "emit_selftest.ny";
part "dump_selftest.ny";
part "z_corpus_selftest.ny";
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";
import "ntest:ntest.ny";
import "private/parse.ny";
import "private/reader.ny";
import "private/document.ny";
import "private/emit.ny";
import "private/dump.ny";
import "private/lexical.ny";
