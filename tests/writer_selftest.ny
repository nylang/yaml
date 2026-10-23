/**
 * @brief YamlWriter / Accept / Emit tests (m_v0.18_p3).
 * @see docs/design/compiler/yaml.md §0.4 · §1.5
 */
part of YamlTypes;

@test
func test_yaml_writer_emit_null() {
  let n: Yaml = Yaml{ node: YamlNull{ _pad: 0 } };
  let text: string = YamlWriter.Emit(n);
  AssertTrue(text.Contains("null"));
}

@test
func test_yaml_writer_accept_roundtrip_name() {
  let src: Yaml = YamlParseTree("name: x");
  let text: string = YamlWriter.Emit(src);
  AssertTrue(text.Contains("name:"));
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;
  let map_opt: YamlMap? = YamlAsMap(doc.Root());
  AssertTrue(map_opt != nil);
  var mapv: YamlMap = map_opt as YamlMap;
  let name_node: Yaml? = mapv.Get("name");
  AssertTrue(name_node != nil);
  let nv: Yaml = name_node as Yaml;
  let s_opt: YamlStr? = nv.node.get_if<YamlStr>();
  AssertTrue(s_opt != nil);
  AssertEqString((s_opt as YamlStr).Text(), "x");
}

@test
func test_yaml_writer_new_handler_get_string() {
  var w: YamlWriter = YamlWriter.New();
  AssertTrue(w.StartObject());
  AssertTrue(w.Key("name"));
  AssertTrue(w.String("x"));
  AssertTrue(w.EndObject(1));
  let text: string = w.GetString();
  AssertTrue(text.Contains("name:"));
  AssertTrue(text.Contains("x"));
}

@test
func test_yaml_accept_handler_events() {
  var st: YamlEvState = yaml_ev_state_new();
  let stp: *mut YamlEvState = cast<YamlEvState>.pointer(& mut st);
  var rec: YamlEventRecorder = YamlEventRecorder{ st: stp };
  let node: Yaml = YamlParseTree("[true, null]");
  AssertTrue(node.Accept(rec));
  AssertTrue(st.kinds.Len() >= 4);
}
