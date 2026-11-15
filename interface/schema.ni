// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "interface/yaml.ni";
import "schema:schema.ny";
import "stdlib:stdlib.ny";

/** @brief Compiled document rules with a YAML DOM entry point. */
pub struct YamlSchema;

/** @brief Compile rules from a YAML document node. The resulting schema owns its rules. */
pub static method(YamlSchema) Compile(rule: ref Yaml) -> Result<YamlSchema, SchemaError>;

/** @brief Validate a YAML document without materializing a second tree. */
pub method(YamlSchema) Validate(value: ref Yaml) -> Result<Unit, SchemaError>;

/** @brief Reuse rules previously compiled by any schema reader. */
pub static method(YamlSchema) FromCompiled(rules: Schema) -> YamlSchema;

/** @brief Return the reusable compiled rules for another document format. */
pub method(YamlSchema) Compiled() -> Schema;
