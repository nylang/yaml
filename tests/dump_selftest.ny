// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlTests;

/**
 * @brief Corpus dump helpers for m_v0.7_p4 (stripped when yaml is a nested dep).
 * @note Must stay `*_selftest.ny` so product consumers of `yaml` do not need `ntest`.
 * @note m_v0.18_p3: uses YamlDocument.Parse (free Parse deleted).
 */

/** A package corpus fixture retains its requested and resolved path identity. */
struct YamlFixture {
  path: string;
  relative: string;
}

static method(YamlFixture) Resolve(rel: string) -> YamlFixture {
  // Resolve package-owned fixtures from either the package or workspace cwd.
  var prefix: string = "";
  var depth: int32 = 0;
  while depth < 8 {
    let candidate: string = prefix.Concat(rel);
    if File.New(candidate).Exists() {
      return YamlFixture{path: candidate, relative: rel};
    }

    let workspace: string = prefix.Concat("third_party/yaml/").Concat(rel);
    if File.New(workspace).Exists() {
      return YamlFixture{path: workspace, relative: rel};
    }

    prefix = "../".Concat(prefix);
    depth = depth + 1;
  }

  return YamlFixture{path: "", relative: rel};
}

method(YamlFixture) Read() -> string {
  let path: string = self.path;
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

method(YamlFixture) Parse() -> Result<YamlDocument, YamlError> {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let path: string = self.path;
  if path.length <= 0 {
    return YamlDocument.ParseFile(self.relative, durable, scratch);
  }

  return YamlDocument.ParseFile(path, durable, scratch);
}

method(YamlFixture) AssertDumpMatch(dump_rel: string) {
  let src: string = self.Read();
  if src.length <= 0 {
    AssertTrueMsg(false, self.relative);
    return;
  }

  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let pr: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr.IsOk());
  let doc_opt: YamlDocument? = pr.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  let got: string = ((doc_opt as YamlDocument).Root()).CanonicalDump();
  let want: string = YamlFixture.Resolve(dump_rel).Read();
  if want.length <= 0 {
    AssertTrueMsg(false, dump_rel);
    return;
  }

  AssertEqString(got, want);
}

method(YamlFixture) AssertParseError() {
  let src: string = self.Read();
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let pr: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr.IsErr());
}

/**
 * @brief §1.5 tree equality: Parse → Emit → Parse; dumps must match (m_v0.18_p4).
 * @note Emit takes `Yaml` by value — re-parse `src` for the emit walk.
 */
method(YamlFixture) AssertRoundTrip() {
  let src: string = self.Read();
  if src.length <= 0 {
    AssertTrueMsg(false, self.relative);
    return;
  }

  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let pr: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr.IsOk());
  let doc_opt: YamlDocument? = pr.get_if<YamlDocument>();
  AssertTrue(doc_opt != nil);
  let before: string = ((doc_opt as YamlDocument).Root()).CanonicalDump();
  let pr2: Result<YamlDocument, YamlError> = YamlDocument.Parse(src, durable, scratch);
  AssertTrue(pr2.IsOk());
  let doc2_opt: YamlDocument? = pr2.get_if<YamlDocument>();
  AssertTrue(doc2_opt != nil);
  let text: string = YamlWriter.Emit((doc2_opt as YamlDocument).Root());
  let pr3: Result<YamlDocument, YamlError> = YamlDocument.Parse(text, durable, scratch);
  AssertTrue(pr3.IsOk());
  let doc3_opt: YamlDocument? = pr3.get_if<YamlDocument>();
  AssertTrue(doc3_opt != nil);
  let after: string = ((doc3_opt as YamlDocument).Root()).CanonicalDump();
  AssertEqString(before, after);
}
