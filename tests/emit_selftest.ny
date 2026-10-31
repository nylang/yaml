// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlTests;

/**
 * @brief YamlWriter.Emit + Document round-trip tests (walk `Yaml.node` in YamlTypes).
 */

method(Yaml) AssertRoundTrip() {
  // Emit takes Yaml by value (move). Compare two Document parses of the emitted text.
  let text: string = YamlWriter.Emit(self);
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  let r2: Result<YamlDocument, YamlError> = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(r2.IsOk());
  let doc2_opt: YamlDocument? = r2.get_if<YamlDocument>();
  AssertTrue(doc2_opt != nil);
  AssertTrue(((doc_opt as YamlDocument).Root()).Equals((doc2_opt as YamlDocument).Root()));
}

static method(YamlDocument) AssertRoundTripText(src: string) {
  (Yaml.ParseOrNull(src)).AssertRoundTrip();
}

static method(YamlWriter) EmitQuoted(s: string) -> string {
  let n: Yaml = Yaml{node: YamlStr{value: copy(s)}};

  return YamlWriter.Emit(n);
}

@test
func test_yaml_emit_empty_collections_and_null() {
  let n: Yaml = Yaml{node: YamlNull{_pad: 0}};
  let nt: string = YamlWriter.Emit(n);
  AssertTrue(nt.Contains("null"));
  n.AssertRoundTrip();
  let empty_map: Yaml = Yaml{node: YamlMap{entries: Array<YamlMapEntry>{}}};
  let mt: string = YamlWriter.Emit(empty_map);
  AssertTrue(mt.Contains("{}"));
  empty_map.AssertRoundTrip();
  let empty_seq: Yaml = Yaml{node: YamlSeq{items: Array<Yaml>{}}};
  let st: string = YamlWriter.Emit(empty_seq);
  AssertTrue(st.Contains("[]"));
  empty_seq.AssertRoundTrip();
}

@test
func test_yaml_emit_plain_safe_path() {
  let text: string = YamlWriter.EmitQuoted("../stdlib");
  AssertFalse(text.Contains("\""));
  AssertTrue(text.Contains("../stdlib"));
  (Yaml{node: YamlStr{value: copy("../stdlib")}}).AssertRoundTrip();
}

@test
func test_yaml_emit_quotes_special_chars() {
  let colon: string = YamlWriter.EmitQuoted("a:b");
  AssertTrue(colon.Contains("\""));
  (Yaml{node: YamlStr{value: copy("a:b")}}).AssertRoundTrip();
  (Yaml{node: YamlStr{value: copy("true")}}).AssertRoundTrip();
  (Yaml{node: YamlStr{value: copy("1")}}).AssertRoundTrip();
  (Yaml{node: YamlStr{value: copy("")}}).AssertRoundTrip();
  (Yaml{node: YamlStr{value: copy("hello world")}}).AssertRoundTrip();
}

@test
func test_yaml_emit_int_bool() {
  (Yaml{node: YamlInt{value: 42 as int64}}).AssertRoundTrip();
  (Yaml{node: YamlBool{value: true}}).AssertRoundTrip();
  (Yaml{node: YamlBool{value: false}}).AssertRoundTrip();
}

@test
func test_yaml_parsefile_missing() {
  let missing: string = "/tmp/nyra_yaml_p3_missing_no_such.yaml";
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let pf: Result<YamlDocument, YamlError> = YamlDocument.ParseFile(missing, durable, scratch);
  AssertTrue(pf.IsErr());
  let err: YamlError? = pf.get_if<YamlError>();
  AssertTrue(err != nil);
  let e: YamlError = err as YamlError;
  AssertEqI32(e.line, 0);
  AssertEqI32(e.column, 0);
  AssertTrue(e.message.Contains(missing));
}
