/**
 * @brief Toolchain corpus vs Go yaml.v3 dumps + §1.5 Emit round-trip (m_v0.7_p4 / m_v0.18_p4).
 */
part of YamlTypes;

@test
func test_yaml_dump_inline_flow_map() {
  let doc: Yaml = YamlParseTree("{a: 1, b: 2}");
  let d: string = YamlCanonicalDump(doc);
  AssertTrue(d.Contains("\"t\":\"int\""));
  AssertTrue(d.Contains("\"v\":1"));
  AssertTrue(d.Contains("\"v\":2"));
  AssertTrueMsg(d.Contains("\"a\""), d);
  AssertTrueMsg(d.Contains("\"b\""), d);
}

@test
func test_yaml_dump_two_block_keys() {
  let doc: Yaml = YamlParseTree("name: kernel\nversion: 0.0.1\n");
  let d: string = YamlCanonicalDump(doc);
  AssertTrueMsg(d.Contains("\"name\""), d);
  AssertTrueMsg(d.Contains("\"version\""), d);
}

@test
func test_yaml_corpus_kernel_package() {
  yaml_assert_dump_match("tests/support/yaml/corpus/kernel/package.yaml", "tests/support/yaml/dumps/kernel_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/kernel/package.yaml");
}

@test
func test_yaml_corpus_stdlib_package() {
  yaml_assert_dump_match("tests/support/yaml/corpus/stdlib/package.yaml", "tests/support/yaml/dumps/stdlib_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/stdlib/package.yaml");
}

@test
func test_yaml_corpus_ntest_package() {
  yaml_assert_dump_match("tests/support/yaml/corpus/ntest/package.yaml", "tests/support/yaml/dumps/ntest_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/ntest/package.yaml");
}

@test
func test_yaml_corpus_precompiled_lib() {
  yaml_assert_dump_match("tests/support/yaml/corpus/precompiled/lib/package.yaml", "tests/support/yaml/dumps/precompiled_lib_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/precompiled/lib/package.yaml");
}

@test
func test_yaml_corpus_precompiled_app() {
  yaml_assert_dump_match("tests/support/yaml/corpus/precompiled/app/package.yaml", "tests/support/yaml/dumps/precompiled_app_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/precompiled/app/package.yaml");
}

@test
func test_yaml_corpus_closed_lib() {
  yaml_assert_dump_match("tests/support/yaml/corpus/precompiled/closed_lib/package.yaml", "tests/support/yaml/dumps/precompiled_closed_lib_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/precompiled/closed_lib/package.yaml");
}

@test
func test_yaml_corpus_locators() {
  yaml_assert_dump_match("tests/support/yaml/corpus/design/locators.yaml", "tests/support/yaml/dumps/locators.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/design/locators.yaml");
}

@test
func test_yaml_corpus_nyra_lock() {
  yaml_assert_dump_match("tests/support/yaml/corpus/design/nyra.lock", "tests/support/yaml/dumps/nyra.lock.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/design/nyra.lock");
}

@test
func test_yaml_corpus_manifest() {
  yaml_assert_dump_match("tests/support/yaml/corpus/design/manifest.yaml", "tests/support/yaml/dumps/manifest.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/design/manifest.yaml");
}

@test
func test_yaml_corpus_flow() {
  yaml_assert_dump_match("tests/support/yaml/corpus/design/flow.yaml", "tests/support/yaml/dumps/flow.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/design/flow.yaml");
}

@test
func test_yaml_dump_quoted_its() {
  let doc: Yaml = YamlParseTree("single: 'it''s'\nempty: \"\"\n");
  let d: string = YamlCanonicalDump(doc);
  AssertTrueMsg(d.Contains("it's"), d);
  AssertTrueMsg(d.Contains("\"empty\""), d);
}

@test
func test_yaml_corpus_quoted() {
  yaml_assert_dump_match("tests/support/yaml/corpus/design/quoted.yaml", "tests/support/yaml/dumps/quoted.yaml.dump");
  yaml_assert_corpus_round_trip("tests/support/yaml/corpus/design/quoted.yaml");
}

@test
func test_yaml_corpus_neg_anchors() {
  yaml_assert_parse_err_file("tests/support/yaml/corpus/negative/anchors.yaml");
}

@test
func test_yaml_corpus_neg_tabs() {
  yaml_assert_parse_err_file("tests/support/yaml/corpus/negative/tabs-indent.yaml");
}

@test
func test_yaml_corpus_neg_dup_keys() {
  yaml_assert_parse_err_file("tests/support/yaml/corpus/negative/duplicate-keys.yaml");
}
