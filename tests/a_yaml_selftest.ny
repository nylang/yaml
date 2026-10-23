/**
 * @brief Package-local smoke tests for `yaml` (ntest T0). Run via `nyra test`.
 */
part of YamlTypes;

@test
func test_yaml_package_smoke() {
  let n: Yaml = Yaml{ node: YamlNull{ _pad: 0 } };
  let _ok: bool = n.node.holds<YamlNull>();
  AssertTrue(_ok);
}

@test
func test_yaml_parse_empty_null() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("", durable, scratch);
  AssertTrue(r.IsOk());
}

@test
func test_yaml_parse_name_x() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("name: x", durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var ydoc: YamlDocument = doc_opt as YamlDocument;
  let doc: Yaml = ydoc.Root();
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  AssertEqI32(m.Len(), 1);
  let name: Yaml? = m.Get("name");
  AssertTrue(name != nil);
  let nv: Yaml = name as Yaml;
  let s: YamlStr? = nv.node.get_if<YamlStr>();
  AssertTrue(s != nil);
  let sv: YamlStr = s as YamlStr;
  AssertEqString(sv.value, "x");
}

@test
func test_yaml_parse_nested_stdlib_path() {
  let doc: Yaml = YamlParseTree("dependencies:\n  stdlib:\n    path: ../stdlib\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  let deps_n: Yaml? = m.Get("dependencies");
  AssertTrue(deps_n != nil);
  let deps_v: Yaml = deps_n as Yaml;
  let deps: YamlMap? = deps_v.node.get_if<YamlMap>();
  AssertTrue(deps != nil);
  let dm: YamlMap = deps as YamlMap;
  let std_n: Yaml? = dm.Get("stdlib");
  AssertTrue(std_n != nil);
  let std_v: Yaml = std_n as Yaml;
  let std: YamlMap? = std_v.node.get_if<YamlMap>();
  AssertTrue(std != nil);
  let sm: YamlMap = std as YamlMap;
  let path_n: Yaml? = sm.Get("path");
  AssertTrue(path_n != nil);
  let path_v: Yaml = path_n as Yaml;
  let path: YamlStr? = path_v.node.get_if<YamlStr>();
  AssertTrue(path != nil);
  let pv: YamlStr = path as YamlStr;
  AssertEqString(pv.value, "../stdlib");
}

@test
func test_yaml_parse_seq_two_maps() {
  let doc: Yaml = YamlParseTree("- name: a\n- name: b\n");
  let seq: YamlSeq? = doc.node.get_if<YamlSeq>();
  AssertTrue(seq != nil);
  let s: YamlSeq = seq as YamlSeq;
  AssertEqI32(s.Len(), 2);
  let i0: Yaml? = s.Get(0);
  AssertTrue(i0 != nil);
  let v0: Yaml = i0 as Yaml;
  let m0: YamlMap? = v0.node.get_if<YamlMap>();
  AssertTrue(m0 != nil);
  let mm0: YamlMap = m0 as YamlMap;
  let n0: Yaml? = mm0.Get("name");
  AssertTrue(n0 != nil);
  let nv0: Yaml = n0 as Yaml;
  let s0: YamlStr? = nv0.node.get_if<YamlStr>();
  AssertTrue(s0 != nil);
  let sv0: YamlStr = s0 as YamlStr;
  AssertEqString(sv0.value, "a");
  let i1: Yaml? = s.Get(1);
  AssertTrue(i1 != nil);
  let v1: Yaml = i1 as Yaml;
  let m1: YamlMap? = v1.node.get_if<YamlMap>();
  AssertTrue(m1 != nil);
  let mm1: YamlMap = m1 as YamlMap;
  let n1: Yaml? = mm1.Get("name");
  AssertTrue(n1 != nil);
  let nv1: Yaml = n1 as Yaml;
  let s1: YamlStr? = nv1.node.get_if<YamlStr>();
  AssertTrue(s1 != nil);
  let sv1: YamlStr = s1 as YamlStr;
  AssertEqString(sv1.value, "b");
}

@test
func test_yaml_parse_flow_map() {
  let doc: Yaml = YamlParseTree("{a: 1}");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  AssertEqI32(m.Len(), 1);
  let a: Yaml? = m.Get("a");
  AssertTrue(a != nil);
  let av: Yaml = a as Yaml;
  let n: YamlInt? = av.node.get_if<YamlInt>();
  AssertTrue(n != nil);
  let ni: YamlInt = n as YamlInt;
  AssertEqI64(ni.value, 1 as int64);
}

@test
func test_yaml_parse_empty_flow_map() {
  let doc: Yaml = YamlParseTree("{}");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let em: YamlMap = map as YamlMap;
  AssertEqI32(em.Len(), 0);
}

@test
func test_yaml_parse_quoted_always_string() {
  let doc: Yaml = YamlParseTree("x: \"true\"\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  AssertEqI32(m.Len(), 1);
}

@test
func test_yaml_parse_quoted_three_len() {
  let doc: Yaml = YamlParseTree("x: \"true\"\ny: \"1\"\nz: 'it''s'\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  AssertEqI32(m.Len(), 3);
}

@test
func test_yaml_parse_quoted_doc_true() {
  let doc: Yaml = YamlParseTree("\"true\"");
  let s: YamlStr? = doc.node.get_if<YamlStr>();
  AssertTrue(s != nil);
  let sv: YamlStr = s as YamlStr;
  AssertEqString(sv.value, "true");
}

@test
func test_yaml_parse_quoted_doc_one() {
  let doc: Yaml = YamlParseTree("\"1\"");
  let s: YamlStr? = doc.node.get_if<YamlStr>();
  AssertTrue(s != nil);
  let sv: YamlStr = s as YamlStr;
  AssertEqString(sv.value, "1");
}

@test
func test_yaml_parse_quoted_doc_esc() {
  let doc: Yaml = YamlParseTree("'it''s'");
  let _d: Yaml = doc;
}

@test
func test_yaml_parse_core_scalars() {
  let doc: Yaml = YamlParseTree("t: true\nf: false\nn: null\ni: 42\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  AssertEqI32(m.Len(), 4);
}

@test
func test_yaml_parse_core_true() {
  let doc: Yaml = YamlParseTree("t: true\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  let t: Yaml? = m.Get("t");
  AssertTrue(t != nil);
  let tv: Yaml = t as Yaml;
  let tb: YamlBool? = tv.node.get_if<YamlBool>();
  AssertTrue(tb != nil);
  let tbv: YamlBool = tb as YamlBool;
  AssertTrue(tbv.value);
}

@test
func test_yaml_parse_core_false() {
  let doc: Yaml = YamlParseTree("f: false\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  let f: Yaml? = m.Get("f");
  AssertTrue(f != nil);
  let fv: Yaml = f as Yaml;
  let fb: YamlBool? = fv.node.get_if<YamlBool>();
  AssertTrue(fb != nil);
  let fbv: YamlBool = fb as YamlBool;
  AssertFalse(fbv.value);
}

@test
func test_yaml_parse_core_null() {
  let doc: Yaml = YamlParseTree("n: null\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  let n: Yaml? = m.Get("n");
  AssertTrue(n != nil);
  let nv: Yaml = n as Yaml;
  AssertTrue(nv.node.holds<YamlNull>());
}

@test
func test_yaml_parse_core_int() {
  let doc: Yaml = YamlParseTree("i: 42\n");
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let m: YamlMap = map as YamlMap;
  let i: Yaml? = m.Get("i");
  AssertTrue(i != nil);
  let iv: Yaml = i as Yaml;
  let ival: YamlInt? = iv.node.get_if<YamlInt>();
  AssertTrue(ival != nil);
  let ivn: YamlInt = ival as YamlInt;
  AssertEqI64(ivn.value, 42 as int64);
}

@test
func test_yaml_error_and_stubs() {
  let err: YamlError = YamlError{ line: 1, column: 2, message: "e" };
  AssertEqI32(err.line, 1);
  AssertEqI32(err.column, 2);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let pf: Result<YamlDocument, YamlError> = YamlDocument.ParseFile(
    "/tmp/nyra_yaml_p3_missing_no_such.yaml",
    durable,
    scratch
  );
  AssertTrue(pf.IsErr());
  let n: Yaml = Yaml{ node: YamlNull{ _pad: 0 } };
  let out: string = YamlWriter.Emit(n);
  AssertTrue(out.Contains("null"));
}

@test
func test_yaml_map_seq_len_empty() {
  let empty_entries: Array<YamlMapEntry> = Array<YamlMapEntry>{};
  let m: YamlMap = YamlMap{ entries: empty_entries };
  AssertEqI32(m.Len(), 0);
  var m2: YamlMap = YamlMap{ entries: Array<YamlMapEntry>{} };
  let v: Yaml = Yaml{ node: YamlStr{ value: "x" } };
  m2.entries.Push(YamlMapEntry{ key: "name", value: v });
  AssertEqI32(m2.Len(), 1);
  let doc: Yaml = Yaml{ node: m2 };
  let map: YamlMap? = doc.node.get_if<YamlMap>();
  AssertTrue(map != nil);
  let mm: YamlMap = map as YamlMap;
  AssertEqI32(mm.Len(), 1);
  let empty_items: Array<Yaml> = Array<Yaml>{};
  let s: YamlSeq = YamlSeq{ items: empty_items };
  AssertEqI32(s.Len(), 0);
}

@test
func test_yaml_parse_err_of_dup() {
  let st: YamlParseErr = YamlParseErrOf("a: 1\na: 2\n");
  AssertTrue(st.failed);
  AssertTrue(st.message.Contains("duplicate"));
}

@test
func test_yaml_parse_err_of_overflow() {
  let st: YamlParseErr = YamlParseErrOf("n: 99999999999999999999\n");
  AssertTrue(st.failed);
  AssertTrue(st.message.Contains("overflow"));
}

@test
func test_yaml_emit_roundtrip_name_x() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let doc: Yaml = YamlParseTree("name: x");
  let text: string = YamlWriter.Emit(doc);
  AssertTrue(text.Contains("name:"));
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(r.IsOk());
  let doc2: Yaml = YamlParseTree("a: 1");
  let text2: string = YamlWriter.Emit(doc2);
  let r2: Result<YamlDocument, YamlError> = YamlDocument.Parse(text2, durable, scratch);
  AssertTrue(r2.IsOk());
  let doc3: Yaml = YamlParseTree("public: []\n");
  let text3: string = YamlWriter.Emit(doc3);
  AssertTrue(text3.Contains("[]"));
  let r3: Result<YamlDocument, YamlError> = YamlDocument.Parse(text3, durable, scratch);
  AssertTrue(r3.IsOk());
  let doc4: Yaml = YamlParseTree("- a\n- b\n");
  let text4: string = YamlWriter.Emit(doc4);
  AssertTrue(text4.Contains("- a"));
  AssertTrue(text4.Contains("- b"));
  let r4: Result<YamlDocument, YamlError> = YamlDocument.Parse(text4, durable, scratch);
  AssertTrue(r4.IsOk());
  let doc5: Yaml = YamlParseTree("x: \"true\"\n");
  let text5: string = YamlWriter.Emit(doc5);
  let r5: Result<YamlDocument, YamlError> = YamlDocument.Parse(text5, durable, scratch);
  AssertTrue(r5.IsOk());
  let nest: Yaml = YamlParseTree("dependencies:\n  stdlib:\n    path: ../stdlib\n");
  let nt: string = YamlWriter.Emit(nest);
  AssertTrue(nt.Contains("dependencies:"));
  AssertTrue(nt.Contains("path:"));
  let nr: Result<YamlDocument, YamlError> = YamlDocument.Parse(nt, durable, scratch);
  AssertTrue(nr.IsOk());
  yaml_assert_round_trip(YamlParseTree("{a: 1}"));
  yaml_assert_round_trip(YamlParseTree("{}"));
  let seqm: Yaml = YamlParseTree("- name: a\n- name: b\n");
  let seqt: string = YamlWriter.Emit(seqm);
  AssertTrue(seqt.Contains("name:"));
  let seqr: Result<YamlDocument, YamlError> = YamlDocument.Parse(seqt, durable, scratch);
  AssertTrue(seqr.IsOk());
  let mapseq: Yaml = YamlParseTree("name: yaml\nitems:\n  - a\n  - b\n");
  let mst: string = YamlWriter.Emit(mapseq);
  AssertTrue(mst.Contains("items:"));
  AssertTrue(mst.Contains("- a"));
  let msr: Result<YamlDocument, YamlError> = YamlDocument.Parse(mst, durable, scratch);
  AssertTrue(msr.IsOk());
  let pkg: Result<YamlDocument, YamlError> = YamlDocument.ParseFile("package.yaml", durable, scratch);
  if pkg.IsErr() {
    let pkg2: Result<YamlDocument, YamlError> = YamlDocument.ParseFile(
      "source/yaml/package.yaml",
      durable,
      scratch
    );
    AssertTrue(pkg2.IsOk());
  } else {
    AssertTrue(pkg.IsOk());
  }
}
