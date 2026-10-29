// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlTests;

/**
 * @brief Toolchain corpus vs Go yaml.v3 dumps + §1.5 Emit round-trip (m_v0.7_p4 / m_v0.18_p4).
 */

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
  yaml_assert_dump_match(
    "tests/data/corpus/kernel/package.yaml",
    "tests/data/dumps/kernel_package.yaml.dump"
  );
  yaml_assert_corpus_round_trip("tests/data/corpus/kernel/package.yaml");
}

@test
func test_yaml_corpus_stdlib_package() {
  yaml_assert_dump_match(
    "tests/data/corpus/stdlib/package.yaml",
    "tests/data/dumps/stdlib_package.yaml.dump"
  );
  yaml_assert_corpus_round_trip("tests/data/corpus/stdlib/package.yaml");
}

@test
func test_yaml_corpus_ntest_package() {
  yaml_assert_dump_match("tests/data/corpus/ntest/package.yaml", "tests/data/dumps/ntest_package.yaml.dump");
  yaml_assert_corpus_round_trip("tests/data/corpus/ntest/package.yaml");
}

@test
func test_yaml_corpus_precompiled_lib() {
  yaml_assert_dump_match(
    "tests/data/corpus/precompiled/lib/package.yaml",
    "tests/data/dumps/precompiled_lib_package.yaml.dump"
  );
  yaml_assert_corpus_round_trip("tests/data/corpus/precompiled/lib/package.yaml");
}

@test
func test_yaml_corpus_precompiled_app() {
  yaml_assert_dump_match(
    "tests/data/corpus/precompiled/app/package.yaml",
    "tests/data/dumps/precompiled_app_package.yaml.dump"
  );
  yaml_assert_corpus_round_trip("tests/data/corpus/precompiled/app/package.yaml");
}

@test
func test_yaml_corpus_closed_lib() {
  yaml_assert_dump_match(
    "tests/data/corpus/precompiled/closed_lib/package.yaml",
    "tests/data/dumps/precompiled_closed_lib_package.yaml.dump"
  );
  yaml_assert_corpus_round_trip("tests/data/corpus/precompiled/closed_lib/package.yaml");
}

@test
func test_yaml_corpus_locators() {
  yaml_assert_dump_match("tests/data/corpus/design/locators.yaml", "tests/data/dumps/locators.yaml.dump");
  yaml_assert_corpus_round_trip("tests/data/corpus/design/locators.yaml");
}

@test
func test_yaml_corpus_nyra_lock() {
  yaml_assert_dump_match("tests/data/corpus/design/nyra.lock", "tests/data/dumps/nyra.lock.dump");
  yaml_assert_corpus_round_trip("tests/data/corpus/design/nyra.lock");
}

@test
func test_yaml_corpus_manifest() {
  yaml_assert_dump_match("tests/data/corpus/design/manifest.yaml", "tests/data/dumps/manifest.yaml.dump");
  yaml_assert_corpus_round_trip("tests/data/corpus/design/manifest.yaml");
}

@test
func test_yaml_corpus_flow() {
  yaml_assert_dump_match("tests/data/corpus/design/flow.yaml", "tests/data/dumps/flow.yaml.dump");
  yaml_assert_corpus_round_trip("tests/data/corpus/design/flow.yaml");
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
  yaml_assert_dump_match("tests/data/corpus/design/quoted.yaml", "tests/data/dumps/quoted.yaml.dump");
  yaml_assert_corpus_round_trip("tests/data/corpus/design/quoted.yaml");
}

@test
func test_yaml_corpus_neg_anchors() {
  yaml_assert_parse_err_file("tests/data/corpus/negative/anchors.yaml");
}

@test
func test_yaml_corpus_neg_tabs() {
  yaml_assert_parse_err_file("tests/data/corpus/negative/tabs-indent.yaml");
}

@test
func test_yaml_corpus_neg_dup_keys() {
  yaml_assert_parse_err_file("tests/data/corpus/negative/duplicate-keys.yaml");
}
