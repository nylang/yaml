/**
 * @brief YamlDocument build / query / durable-vs-scratch ownership tests (m_v0.18_p2).
 * @note MemStack/MemArena scratch helpers: `yaml_scratch_from_stack` / `yaml_scratch_from_arena`
 *       (defined in `reader_selftest.ny`, same YamlTypes module).
 * @see docs/design/compiler/yaml.md §0.5–0.6
 */
part of YamlTypes;

@test
func test_yaml_document_empty_null_root() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("", durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;
  let root: Yaml = doc.Root();
  let is_null: bool = root.node.holds<YamlNull>();
  AssertTrue(is_null);
}

@test
func test_yaml_document_query_map_name() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("name: x", durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;
  let root: Yaml = doc.Root();
  let map_opt: YamlMap? = YamlAsMap(root);
  AssertTrue(map_opt != nil);
  var mapv: YamlMap = map_opt as YamlMap;
  AssertEqI32(mapv.Len(), 1);
  let key0: string? = mapv.KeyAt(0);
  AssertTrue(key0 != nil);
  AssertEqString(key0 as string, "name");
  let val0: Yaml? = mapv.ValueAt(0);
  AssertTrue(val0 != nil);
  let v0: Yaml = val0 as Yaml;
  let s_opt: YamlStr? = v0.node.get_if<YamlStr>();
  AssertTrue(s_opt != nil);
  let sv: YamlStr = s_opt as YamlStr;
  AssertEqString(sv.Text(), "x");

  let r2: Result<YamlDocument, YamlError> = YamlDocument.Parse("name: x", durable, scratch);
  AssertTrue(r2.IsOk());
  let doc2_opt: YamlDocument? = r2.get_if<YamlDocument>();
  AssertTrue(doc2_opt != nil);
  var doc2: YamlDocument = doc2_opt as YamlDocument;
  let map2_opt: YamlMap? = YamlAsMap(doc2.Root());
  AssertTrue(map2_opt != nil);
  var map2: YamlMap = map2_opt as YamlMap;
  let name_node: Yaml? = map2.Get("name");
  AssertTrue(name_node != nil);
  let nv: Yaml = name_node as Yaml;
  let s2_opt: YamlStr? = nv.node.get_if<YamlStr>();
  AssertTrue(s2_opt != nil);
  let s2: YamlStr = s2_opt as YamlStr;
  AssertEqString(s2.Text(), "x");
}

@test
func test_yaml_document_query_seq_scalars() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("[true, false, null, 42, hi]", durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;
  let root: Yaml = doc.Root();
  let seq_opt: YamlSeq? = YamlAsSeq(root);
  AssertTrue(seq_opt != nil);
  var seqv: YamlSeq = seq_opt as YamlSeq;
  AssertEqI32(seqv.Len(), 5);

  let i0: Yaml? = seqv.Get(0);
  AssertTrue(i0 != nil);
  let v0: Yaml = i0 as Yaml;
  let v0_is_bool: bool = v0.node.holds<YamlBool>();
  AssertTrue(v0_is_bool);
  let b0_opt: YamlBool? = v0.node.get_if<YamlBool>();
  AssertTrue(b0_opt != nil);
  let b0: YamlBool = b0_opt as YamlBool;
  AssertTrue(b0.value);

  let i2: Yaml? = seqv.Get(2);
  AssertTrue(i2 != nil);
  let v2: Yaml = i2 as Yaml;
  let v2_is_null: bool = v2.node.holds<YamlNull>();
  AssertTrue(v2_is_null);

  let i3: Yaml? = seqv.Get(3);
  AssertTrue(i3 != nil);
  let v3: Yaml = i3 as Yaml;
  let iv: int64? = YamlAsInt(v3);
  AssertTrue(iv != nil);
  AssertEqI64(iv as int64, 42 as int64);
  let yi_opt: YamlInt? = v3.node.get_if<YamlInt>();
  AssertTrue(yi_opt != nil);
  AssertEqI64((yi_opt as YamlInt).I64(), 42 as int64);

  let i4: Yaml? = seqv.Get(4);
  AssertTrue(i4 != nil);
  let v4: Yaml = i4 as Yaml;
  let s4_opt: YamlStr? = v4.node.get_if<YamlStr>();
  AssertTrue(s4_opt != nil);
  AssertEqString((s4_opt as YamlStr).Text(), "hi");

  let oor: Yaml? = seqv.Get(5);
  AssertTrue(oor == nil);
}

@test
func test_yaml_document_query_nested_map() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse(
    "dependencies:\n  stdlib:\n    path: ../stdlib\n",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;
  let root: Yaml = doc.Root();
  let map_opt: YamlMap? = YamlAsMap(root);
  AssertTrue(map_opt != nil);
  var mapv: YamlMap = map_opt as YamlMap;
  let deps_n: Yaml? = mapv.Get("dependencies");
  AssertTrue(deps_n != nil);
  let deps_map: YamlMap? = YamlAsMap(deps_n as Yaml);
  AssertTrue(deps_map != nil);
  var dm: YamlMap = deps_map as YamlMap;
  let std_n: Yaml? = dm.Get("stdlib");
  AssertTrue(std_n != nil);
  let std_map: YamlMap? = YamlAsMap(std_n as Yaml);
  AssertTrue(std_map != nil);
  var sm: YamlMap = std_map as YamlMap;
  let path_n: Yaml? = sm.Get("path");
  AssertTrue(path_n != nil);
  let path_v: Yaml = path_n as Yaml;
  let path_s: YamlStr? = path_v.node.get_if<YamlStr>();
  AssertTrue(path_s != nil);
  AssertEqString((path_s as YamlStr).Text(), "../stdlib");
}

@test
func test_yaml_document_parse_error() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("x: &a 1\ny: *a\n", durable, scratch);
  AssertTrue(r.IsErr());
  let eo: YamlError? = r.get_if<YamlError>();
  AssertTrue(eo != nil);
  let e: YamlError = eo as YamlError;
  AssertTrue(e.Message().length > 0);
}

@test
func test_yaml_document_memstack_scratch_reset_durable() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var stack: MemStack = MemStack{};
  stack.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = yaml_scratch_from_stack(stack);
  let mark: uintptr = stack.Mark();
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);

  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse("a: 1\nb: two\n", durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;

  // Scratch Reset must not invalidate durable Document strings / query results.
  stack.Reset(mark);

  let root: Yaml = doc.Root();
  let map_opt: YamlMap? = YamlAsMap(root);
  AssertTrue(map_opt != nil);
  var mapv: YamlMap = map_opt as YamlMap;
  AssertEqI32(mapv.Len(), 2);
  let ka: string? = mapv.KeyAt(0);
  AssertTrue(ka != nil);
  AssertEqString(ka as string, "a");
  let kb: string? = mapv.KeyAt(1);
  AssertTrue(kb != nil);
  AssertEqString(kb as string, "b");
  let vb: Yaml? = mapv.Get("b");
  AssertTrue(vb != nil);
  let vb_n: Yaml = vb as Yaml;
  let sb: YamlStr? = vb_n.node.get_if<YamlStr>();
  AssertTrue(sb != nil);
  AssertEqString((sb as YamlStr).Text(), "two");
  let va: Yaml? = mapv.Get("a");
  AssertTrue(va != nil);
  let ia: int64? = YamlAsInt(va as Yaml);
  AssertTrue(ia != nil);
  AssertEqI64(ia as int64, 1 as int64);

  // Scratch reusable after Reset; Document still valid.
  let r2: Result<YamlDocument, YamlError> = YamlDocument.Parse("x: y", durable, scratch);
  AssertTrue(r2.IsOk());
  let doc2_opt: YamlDocument? = r2.get_if<YamlDocument>();
  AssertTrue(doc2_opt != nil);
  var doc2: YamlDocument = doc2_opt as YamlDocument;
  let root2: Yaml = doc2.Root();
  let m2_opt: YamlMap? = YamlAsMap(root2);
  AssertTrue(m2_opt != nil);
  var m2: YamlMap = m2_opt as YamlMap;
  let xv: Yaml? = m2.Get("x");
  AssertTrue(xv != nil);
  let xv_n: Yaml = xv as Yaml;
  let xs: YamlStr? = xv_n.node.get_if<YamlStr>();
  AssertTrue(xs != nil);
  AssertEqString((xs as YamlStr).Text(), "y");

  // Original document still queryable after second Parse reused scratch.
  let root_again: Yaml = doc.Root();
  let map_again_opt: YamlMap? = YamlAsMap(root_again);
  AssertTrue(map_again_opt != nil);
  var map_again: YamlMap = map_again_opt as YamlMap;
  let k_again: string? = map_again.KeyAt(0);
  AssertTrue(k_again != nil);
  AssertEqString(k_again as string, "a");

  _nyra_free(chunk);
}

@test
func test_yaml_document_memarena_scratch_reset_durable() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var arena: MemArena = MemArena{};
  arena.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = yaml_scratch_from_arena(arena);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);

  let r: Result<YamlDocument, YamlError> = YamlDocument.Parse(
    "name: pkg\nversion: 1\n",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;

  arena.ResetAll();

  let root: Yaml = doc.Root();
  let map_opt: YamlMap? = YamlAsMap(root);
  AssertTrue(map_opt != nil);
  var mapv: YamlMap = map_opt as YamlMap;
  let name_n: Yaml? = mapv.Get("name");
  AssertTrue(name_n != nil);
  let name_v: Yaml = name_n as Yaml;
  let name_s: YamlStr? = name_v.node.get_if<YamlStr>();
  AssertTrue(name_s != nil);
  AssertEqString((name_s as YamlStr).Text(), "pkg");
  let ver_n: Yaml? = mapv.Get("version");
  AssertTrue(ver_n != nil);
  let ver_i: int64? = YamlAsInt(ver_n as Yaml);
  AssertTrue(ver_i != nil);
  AssertEqI64(ver_i as int64, 1 as int64);

  arena.Release();
  _nyra_free(chunk);
}

@test
func test_yaml_document_parsefile_package_yaml() {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<YamlDocument, YamlError> = YamlDocument.ParseFile("package.yaml", durable, scratch);
  if !r.IsOk() {
    let r2: Result<YamlDocument, YamlError> = YamlDocument.ParseFile(
      "source/yaml/package.yaml",
      durable,
      scratch
    );
    AssertTrue(r2.IsOk());
    let doc_opt: YamlDocument? = r2.get_if<YamlDocument>();
    AssertTrue(doc_opt != nil);
    var doc: YamlDocument = doc_opt as YamlDocument;
    let root: Yaml = doc.Root();
    let map_opt: YamlMap? = YamlAsMap(root);
    AssertTrue(map_opt != nil);
    var mapv: YamlMap = map_opt as YamlMap;
    let name_n: Yaml? = mapv.Get("name");
    AssertTrue(name_n != nil);
    let name_v: Yaml = name_n as Yaml;
    let name_s: YamlStr? = name_v.node.get_if<YamlStr>();
    AssertTrue(name_s != nil);
    AssertEqString((name_s as YamlStr).Text(), "yaml");
    return;
  }
  let doc_opt: YamlDocument? = r.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  var doc: YamlDocument = doc_opt as YamlDocument;
  let root: Yaml = doc.Root();
  let map_opt: YamlMap? = YamlAsMap(root);
  AssertTrue(map_opt != nil);
  var mapv: YamlMap = map_opt as YamlMap;
  let name_n: Yaml? = mapv.Get("name");
  AssertTrue(name_n != nil);
  let name_v: Yaml = name_n as Yaml;
  let name_s: YamlStr? = name_v.node.get_if<YamlStr>();
  AssertTrue(name_s != nil);
  AssertEqString((name_s as YamlStr).Text(), "yaml");
}
