/**
 * @brief Parse error tests via YamlDocument (walk-free; cross-TU `holds` is NY6002).
 * @note Tree equality tests live in YamlTypes emit/writer selftests.
 */
part of YamlTypes;

@test
func test_yaml_parse_empty_ok() {
  let doc: Yaml = YamlParseTree("");
  AssertTrue(doc.node.holds<YamlNull>());
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("", durable, scratch);
  AssertTrue(r.IsOk());
}

@test
func test_yaml_parse_comments_only_ok() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("# only\n", durable, scratch);
  AssertTrue(r.IsOk());
}

@test
func test_yaml_parse_dup_key_err() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("a: 1\na: 2\n", durable, scratch);
  AssertTrue(r.IsErr());
}

@test
func test_yaml_parse_overflow_err() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("n: 99999999999999999999\n", durable, scratch);
  AssertTrue(r.IsErr());
}

@test
func test_yaml_parse_anchors_err() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("# anchors — out of v1\nx: &a 1\ny: *a\n", durable, scratch);
  AssertTrue(r.IsErr());
}

@test
func test_yaml_parse_block_scalar_err() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("x: |\n  body\n", durable, scratch);
  AssertTrue(r.IsErr());
}

@test
func test_yaml_compact_sequence_map_stops_before_sibling_key(){
  var durable:Allocator=CreateAllocator(0 as int64,8 as int64);var scratch:Allocator=CreateAllocator(0 as int64,8 as int64);
  let parsed:Result<YamlDocument,YamlError> =YamlDocument.Parse("dependencies:\n- key: math\n  root: ../math\nmodules:\n- rel: main.ny\n  object: main.o\n",durable,scratch);
  AssertTrue(parsed.IsOk());let value:YamlDocument?=parsed.get_if<YamlDocument>();AssertTrue(value!=nil);let root:YamlMap?=YamlAsMap((value as YamlDocument).Root());AssertTrue(root!=nil);AssertEqI32((root as YamlMap).Len(),2);
}
