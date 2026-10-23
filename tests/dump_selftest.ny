/**
 * @brief Corpus dump helpers for m_v0.7_p4 (stripped when yaml is a nested dep).
 * @note Must stay `*_selftest.ny` so product consumers of `yaml` do not need `ntest`.
 * @note m_v0.18_p3: uses YamlDocument.Parse (free Parse deleted).
 */
part of YamlTypes;

func yaml_path_exists(path: string) -> bool {
  let f: File = File.New(path);
  return f.Exists();
}

func yaml_resolve_testdata(rel: string) -> string {
  // Test inputs live under repository tests/, independent of the package cwd.
  var prefix: string = "";
  var depth: int32 = 0;
  while depth < 8 {
    let candidate: string = prefix.Concat(rel);
    if yaml_path_exists(candidate) {
      return candidate;
    }
    prefix = "../".Concat(prefix);
    depth = depth + 1;
  }
  return copy("");
}

func yaml_read_testdata(rel: string) -> string {
  let path: string = yaml_resolve_testdata(rel);
  if path.length <= 0 {
    return copy("");
  }
  let f: File = File.New(path);
  let rd: Result<string, IoError> = f.ReadAsString();
  if rd.IsErr() {
    return copy("");
  }
  let t: string? = rd.get_if<string>();
  if t == nil {
    return copy("");
  }
  return copy(t as string);
}

func yaml_parse_testdata(rel: string) -> Result<YamlDocument, YamlError> {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let path: string = yaml_resolve_testdata(rel);
  if path.length <= 0 {
    return YamlDocument.ParseFile(rel, durable, scratch);
  }
  return YamlDocument.ParseFile(path, durable, scratch);
}

func yaml_assert_dump_match(yaml_rel: string, dump_rel: string) {
  let src: string = yaml_read_testdata(yaml_rel);
  if src.length <= 0 {
    AssertTrueMsg(false, yaml_rel);
    return;
  }
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let pr: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr.IsOk());
  let doc_opt: YamlDocument? = pr.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  let got: string = YamlCanonicalDump((doc_opt as YamlDocument).Root());
  let want: string = yaml_read_testdata(dump_rel);
  if want.length <= 0 {
    AssertTrueMsg(false, dump_rel);
    return;
  }
  AssertEqString(got, want);
}

func yaml_assert_parse_err_file(rel: string) {
  let src: string = yaml_read_testdata(rel);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let pr: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr.IsErr());
}

/**
 * @brief §1.5 tree equality: Parse → Emit → Parse; dumps must match (m_v0.18_p4).
 * @note Emit takes `Yaml` by value — re-parse `src` for the emit walk.
 */
func yaml_assert_corpus_round_trip(yaml_rel: string) {
  let src: string = yaml_read_testdata(yaml_rel);
  if src.length <= 0 {
    AssertTrueMsg(false, yaml_rel);
    return;
  }
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let pr: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr.IsOk());
  let doc_opt: YamlDocument? = pr.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  let before: string = YamlCanonicalDump((doc_opt as YamlDocument).Root());
  let pr2: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr2.IsOk());
  let doc2_opt: YamlDocument? = pr2.get_if<YamlDocument>();
  AssertTrue(doc2_opt != nil);
  let text: string = YamlWriter.Emit((doc2_opt as YamlDocument).Root());
  let pr3: Result<YamlDocument, YamlError> = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(pr3.IsOk());
  let doc3_opt: YamlDocument? = pr3.get_if<YamlDocument>();
  AssertTrue(doc3_opt != nil);
  let after: string = YamlCanonicalDump((doc3_opt as YamlDocument).Root());
  AssertEqString(before, after);
}
