// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "yaml.ny";
import "ntest:ntest.ny";
import "stdlib:stdlib.ny";

@test
func test_yaml_schema_preserves_quoted_scalar_types() {
  let heap = Allocator.ProcessHeap(0i64, 8i64);
  let parsed = YamlDocument.Parse("type: integer\nmaximum: -1\n", heap, heap);
  let rule = (parsed.get_if<YamlDocument>() as YamlDocument).Root();
  let compiled = YamlSchema.Compile(rule);
  if AssertTrue(compiled.IsOk()) != 0 {
    return;
  }

  let schema = compiled.get_if<YamlSchema>() as YamlSchema;
  let number = YamlDocument.Parse("-2", heap, heap);
  let quoted = YamlDocument.Parse("\"-2\"", heap, heap);
  AssertTrue(schema.Validate((number.get_if<YamlDocument>() as YamlDocument).Root()).IsOk());
  let failure = schema.Validate((quoted.get_if<YamlDocument>() as YamlDocument).Root());
  if AssertTrue(failure.IsErr()) != 0 {
    return;
  }

  let error = failure.get_if<SchemaError>() as SchemaError;
  AssertEqString(error.schema_path, "/type");
}
