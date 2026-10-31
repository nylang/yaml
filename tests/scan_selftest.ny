// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlScanner;

/**
 * @brief Scanner token tables and error-position tests (m_v0.7_p1 Work §3).
 */

method(YamlToken) AssertToken(kind: int32, lexeme: string, line: int32, column: int32) {
  AssertEqI32(self.kind, kind);
  AssertEqString(self.lexeme, lexeme);
  AssertEqI32(self.line, line);
  AssertEqI32(self.column, column);
}

@test
func test_yaml_scan_empty() {
  var toks: YamlScanResult = YamlScanResult.New();
  toks.Tokenize("");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 1);
  (toks.Get(0)).AssertToken(kYamlTokStreamEnd, "", 1, 1);
}

@test
func test_yaml_scan_hash_only() {
  var toks: YamlScanResult = YamlScanResult.New();
  toks.Tokenize("# only");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 1);
  (toks.Get(0)).AssertToken(kYamlTokStreamEnd, "", 1, 7);
}

@test
func test_yaml_scan_name_yaml() {
  var toks: YamlScanResult = YamlScanResult.New();
  toks.Tokenize("name: yaml");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 4);
  (toks.Get(0)).AssertToken(kYamlTokPlain, "name", 1, 1);
  (toks.Get(1)).AssertToken(kYamlTokColon, ":", 1, 5);
  (toks.Get(2)).AssertToken(kYamlTokPlain, "yaml", 1, 7);
  (toks.Get(3)).AssertToken(kYamlTokStreamEnd, "", 1, 11);
}

@test
func test_yaml_scan_nested_spaces() {
  var toks: YamlScanResult = YamlScanResult.New();
  toks.Tokenize("parent:\n  child: 1");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 8);
  (toks.Get(0)).AssertToken(kYamlTokPlain, "parent", 1, 1);
  (toks.Get(1)).AssertToken(kYamlTokColon, ":", 1, 7);
  (toks.Get(2)).AssertToken(kYamlTokIndent, "", 2, 3);
  (toks.Get(3)).AssertToken(kYamlTokPlain, "child", 2, 3);
  (toks.Get(4)).AssertToken(kYamlTokColon, ":", 2, 8);
  (toks.Get(5)).AssertToken(kYamlTokInt, "1", 2, 10);
  (toks.Get(6)).AssertToken(kYamlTokDedent, "", 2, 11);
  (toks.Get(7)).AssertToken(kYamlTokStreamEnd, "", 2, 11);
}

@test
func test_yaml_scan_quoted_colon() {
  var toks: YamlScanResult = YamlScanResult.New();
  toks.Tokenize("\"a:b\"");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 2);
  (toks.Get(0)).AssertToken(kYamlTokStr, "a:b", 1, 1);
  (toks.Get(1)).AssertToken(kYamlTokStreamEnd, "", 1, 6);
}

@test
func test_yaml_scan_true_false_null() {
  var t: YamlScanResult = YamlScanResult.New();
  t.Tokenize("true");
  AssertTrue(t.ok);
  AssertEqI32(t.Len(), 2);
  (t.Get(0)).AssertToken(kYamlTokBool, "true", 1, 1);
  var f: YamlScanResult = YamlScanResult.New();
  f.Tokenize("false");
  AssertTrue(f.ok);
  AssertEqI32(f.Len(), 2);
  (f.Get(0)).AssertToken(kYamlTokBool, "false", 1, 1);
  var n: YamlScanResult = YamlScanResult.New();
  n.Tokenize("null");
  AssertTrue(n.ok);
  AssertEqI32(n.Len(), 2);
  (n.Get(0)).AssertToken(kYamlTokNull, "null", 1, 1);
}

@test
func test_yaml_scan_flow_map() {
  var toks: YamlScanResult = YamlScanResult.New();
  toks.Tokenize("{a: 1, b: 2}");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 10);
  (toks.Get(0)).AssertToken(kYamlTokLBrace, "{", 1, 1);
  (toks.Get(1)).AssertToken(kYamlTokPlain, "a", 1, 2);
  (toks.Get(2)).AssertToken(kYamlTokColon, ":", 1, 3);
  (toks.Get(3)).AssertToken(kYamlTokInt, "1", 1, 5);
  (toks.Get(4)).AssertToken(kYamlTokComma, ",", 1, 6);
  (toks.Get(5)).AssertToken(kYamlTokPlain, "b", 1, 8);
  (toks.Get(6)).AssertToken(kYamlTokColon, ":", 1, 9);
  (toks.Get(7)).AssertToken(kYamlTokInt, "2", 1, 11);
  (toks.Get(8)).AssertToken(kYamlTokRBrace, "}", 1, 12);
  (toks.Get(9)).AssertToken(kYamlTokStreamEnd, "", 1, 13);
}

@test
func test_yaml_scan_tab_indent_error() {
  var r: YamlScanResult = YamlScanResult.New();
  r.Tokenize("name:\n\tx: 1");
  AssertFalse(r.ok);
  AssertEqI32(r.error.line, 2);
  AssertEqI32(r.error.column, 1);
  AssertTrue(r.error.message.Contains("tabs"));
}

@test
func test_yaml_scan_block_dash_and_flow_seq() {
  var dash: YamlScanResult = YamlScanResult.New();
  dash.Tokenize("- a");
  AssertTrue(dash.ok);
  AssertEqI32(dash.Len(), 3);
  (dash.Get(0)).AssertToken(kYamlTokDash, "-", 1, 1);
  (dash.Get(1)).AssertToken(kYamlTokPlain, "a", 1, 3);
  var seq: YamlScanResult = YamlScanResult.New();
  seq.Tokenize("[true, false, null]");
  AssertTrue(seq.ok);
  AssertEqI32(seq.Len(), 8);
  (seq.Get(0)).AssertToken(kYamlTokLBracket, "[", 1, 1);
  (seq.Get(1)).AssertToken(kYamlTokBool, "true", 1, 2);
  (seq.Get(2)).AssertToken(kYamlTokComma, ",", 1, 6);
  (seq.Get(3)).AssertToken(kYamlTokBool, "false", 1, 8);
  (seq.Get(4)).AssertToken(kYamlTokComma, ",", 1, 13);
  (seq.Get(5)).AssertToken(kYamlTokNull, "null", 1, 15);
  (seq.Get(6)).AssertToken(kYamlTokRBracket, "]", 1, 19);
}

@test
func test_yaml_scan_forbidden_indicators() {
  var a: YamlScanResult = YamlScanResult.New();
  a.Tokenize("x: &a 1");
  AssertFalse(a.ok);
  AssertEqI32(a.error.line, 1);
  AssertEqI32(a.error.column, 4);
  var t: YamlScanResult = YamlScanResult.New();
  t.Tokenize("x: !!str y");
  AssertFalse(t.ok);
  var d: YamlScanResult = YamlScanResult.New();
  d.Tokenize("%YAML 1.2\n");
  AssertFalse(d.ok);
  var b: YamlScanResult = YamlScanResult.New();
  b.Tokenize("x: |\n  body");
  AssertFalse(b.ok);
  AssertTrue(b.error.message.Contains("block scalars"));
}
