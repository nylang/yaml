/**
 * @brief Scanner token tables and error-position tests (m_v0.7_p1 Work §3).
 */
part of YamlTypes;

func yaml_expect_tok(tok: YamlToken, kind: int32, lexeme: string, line: int32, column: int32) {
  AssertEqI32(tok.kind, kind);
  AssertEqString(tok.lexeme, lexeme);
  AssertEqI32(tok.line, line);
  AssertEqI32(tok.column, column);
}

@test
func test_yaml_scan_empty() {
  var toks: YamlScanResult = MakeEmptyScanResult();
  toks.Tokenize("");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 1);
  yaml_expect_tok(toks.Get(0), kYamlTokStreamEnd, yaml_empty_view(), 1, 1);
}

@test
func test_yaml_scan_hash_only() {
  var toks: YamlScanResult = MakeEmptyScanResult();
  toks.Tokenize("# only");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 1);
  yaml_expect_tok(toks.Get(0), kYamlTokStreamEnd, yaml_empty_view(), 1, 7);
}

@test
func test_yaml_scan_name_yaml() {
  var toks: YamlScanResult = MakeEmptyScanResult();
  toks.Tokenize("name: yaml");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 4);
  yaml_expect_tok(toks.Get(0), kYamlTokPlain, "name", 1, 1);
  yaml_expect_tok(toks.Get(1), kYamlTokColon, ":", 1, 5);
  yaml_expect_tok(toks.Get(2), kYamlTokPlain, "yaml", 1, 7);
  yaml_expect_tok(toks.Get(3), kYamlTokStreamEnd, yaml_empty_view(), 1, 11);
}

@test
func test_yaml_scan_nested_spaces() {
  var toks: YamlScanResult = MakeEmptyScanResult();
  toks.Tokenize("parent:\n  child: 1");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 8);
  yaml_expect_tok(toks.Get(0), kYamlTokPlain, "parent", 1, 1);
  yaml_expect_tok(toks.Get(1), kYamlTokColon, ":", 1, 7);
  yaml_expect_tok(toks.Get(2), kYamlTokIndent, yaml_empty_view(), 2, 3);
  yaml_expect_tok(toks.Get(3), kYamlTokPlain, "child", 2, 3);
  yaml_expect_tok(toks.Get(4), kYamlTokColon, ":", 2, 8);
  yaml_expect_tok(toks.Get(5), kYamlTokInt, "1", 2, 10);
  yaml_expect_tok(toks.Get(6), kYamlTokDedent, yaml_empty_view(), 2, 11);
  yaml_expect_tok(toks.Get(7), kYamlTokStreamEnd, yaml_empty_view(), 2, 11);
}

@test
func test_yaml_scan_quoted_colon() {
  var toks: YamlScanResult = MakeEmptyScanResult();
  toks.Tokenize("\"a:b\"");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 2);
  yaml_expect_tok(toks.Get(0), kYamlTokStr, "a:b", 1, 1);
  yaml_expect_tok(toks.Get(1), kYamlTokStreamEnd, yaml_empty_view(), 1, 6);
}

@test
func test_yaml_scan_true_false_null() {
  var t: YamlScanResult = MakeEmptyScanResult();
  t.Tokenize("true");
  AssertTrue(t.ok);
  AssertEqI32(t.Len(), 2);
  yaml_expect_tok(t.Get(0), kYamlTokBool, "true", 1, 1);
  var f: YamlScanResult = MakeEmptyScanResult();
  f.Tokenize("false");
  AssertTrue(f.ok);
  AssertEqI32(f.Len(), 2);
  yaml_expect_tok(f.Get(0), kYamlTokBool, "false", 1, 1);
  var n: YamlScanResult = MakeEmptyScanResult();
  n.Tokenize("null");
  AssertTrue(n.ok);
  AssertEqI32(n.Len(), 2);
  yaml_expect_tok(n.Get(0), kYamlTokNull, "null", 1, 1);
}

@test
func test_yaml_scan_flow_map() {
  var toks: YamlScanResult = MakeEmptyScanResult();
  toks.Tokenize("{a: 1, b: 2}");
  AssertTrue(toks.ok);
  AssertEqI32(toks.Len(), 10);
  yaml_expect_tok(toks.Get(0), kYamlTokLBrace, "{", 1, 1);
  yaml_expect_tok(toks.Get(1), kYamlTokPlain, "a", 1, 2);
  yaml_expect_tok(toks.Get(2), kYamlTokColon, ":", 1, 3);
  yaml_expect_tok(toks.Get(3), kYamlTokInt, "1", 1, 5);
  yaml_expect_tok(toks.Get(4), kYamlTokComma, ",", 1, 6);
  yaml_expect_tok(toks.Get(5), kYamlTokPlain, "b", 1, 8);
  yaml_expect_tok(toks.Get(6), kYamlTokColon, ":", 1, 9);
  yaml_expect_tok(toks.Get(7), kYamlTokInt, "2", 1, 11);
  yaml_expect_tok(toks.Get(8), kYamlTokRBrace, "}", 1, 12);
  yaml_expect_tok(toks.Get(9), kYamlTokStreamEnd, yaml_empty_view(), 1, 13);
}

@test
func test_yaml_scan_tab_indent_error() {
  var r: YamlScanResult = MakeEmptyScanResult();
  r.Tokenize("name:\n\tx: 1");
  AssertFalse(r.ok);
  AssertEqI32(r.error.line, 2);
  AssertEqI32(r.error.column, 1);
  AssertTrue(r.error.message.Contains("tabs"));
}

@test
func test_yaml_scan_block_dash_and_flow_seq() {
  var dash: YamlScanResult = MakeEmptyScanResult();
  dash.Tokenize("- a");
  AssertTrue(dash.ok);
  AssertEqI32(dash.Len(), 3);
  yaml_expect_tok(dash.Get(0), kYamlTokDash, "-", 1, 1);
  yaml_expect_tok(dash.Get(1), kYamlTokPlain, "a", 1, 3);
  var seq: YamlScanResult = MakeEmptyScanResult();
  seq.Tokenize("[true, false, null]");
  AssertTrue(seq.ok);
  AssertEqI32(seq.Len(), 8);
  yaml_expect_tok(seq.Get(0), kYamlTokLBracket, "[", 1, 1);
  yaml_expect_tok(seq.Get(1), kYamlTokBool, "true", 1, 2);
  yaml_expect_tok(seq.Get(2), kYamlTokComma, ",", 1, 6);
  yaml_expect_tok(seq.Get(3), kYamlTokBool, "false", 1, 8);
  yaml_expect_tok(seq.Get(4), kYamlTokComma, ",", 1, 13);
  yaml_expect_tok(seq.Get(5), kYamlTokNull, "null", 1, 15);
  yaml_expect_tok(seq.Get(6), kYamlTokRBracket, "]", 1, 19);
}

@test
func test_yaml_scan_forbidden_indicators() {
  var a: YamlScanResult = MakeEmptyScanResult();
  a.Tokenize("x: &a 1");
  AssertFalse(a.ok);
  AssertEqI32(a.error.line, 1);
  AssertEqI32(a.error.column, 4);
  var t: YamlScanResult = MakeEmptyScanResult();
  t.Tokenize("x: !!str y");
  AssertFalse(t.ok);
  var d: YamlScanResult = MakeEmptyScanResult();
  d.Tokenize("%YAML 1.2\n");
  AssertFalse(d.ok);
  var b: YamlScanResult = MakeEmptyScanResult();
  b.Tokenize("x: |\n  body");
  AssertFalse(b.ok);
  AssertTrue(b.error.message.Contains("block scalars"));
}
