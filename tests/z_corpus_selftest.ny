// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlTests;

/**
 * @brief Toolchain corpus vs Go yaml.v3 dumps + §1.5 Emit round-trip (m_v0.7_p4 / m_v0.18_p4).
 */

@test
func test_yaml_dump_inline_flow_map() {
  let doc: Yaml = Yaml.ParseOrNull("{a: 1, b: 2}");
  let d: string = doc.CanonicalDump();
  AssertTrue(d.Contains("\"t\":\"int\""));
  AssertTrue(d.Contains("\"v\":1"));
  AssertTrue(d.Contains("\"v\":2"));
  AssertTrueMsg(d.Contains("\"a\""), d);
  AssertTrueMsg(d.Contains("\"b\""), d);
}

@test
func test_yaml_dump_two_block_keys() {
  let doc: Yaml = Yaml.ParseOrNull("name: kernel\nversion: 0.0.1\n");
  let d: string = doc.CanonicalDump();
  AssertTrueMsg(d.Contains("\"name\""), d);
  AssertTrueMsg(d.Contains("\"version\""), d);
}

@test
func test_yaml_corpus_kernel_package() {
  YamlFixture.Resolve("tests/data/corpus/kernel/package.yaml").AssertDumpMatch(
    "tests/data/dumps/kernel_package.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/kernel/package.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_stdlib_package() {
  YamlFixture.Resolve("tests/data/corpus/stdlib/package.yaml").AssertDumpMatch(
    "tests/data/dumps/stdlib_package.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/stdlib/package.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_ntest_package() {
  YamlFixture.Resolve("tests/data/corpus/ntest/package.yaml").AssertDumpMatch(
    "tests/data/dumps/ntest_package.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/ntest/package.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_precompiled_lib() {
  YamlFixture.Resolve("tests/data/corpus/precompiled/lib/package.yaml").AssertDumpMatch(
    "tests/data/dumps/precompiled_lib_package.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/precompiled/lib/package.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_precompiled_app() {
  YamlFixture.Resolve("tests/data/corpus/precompiled/app/package.yaml").AssertDumpMatch(
    "tests/data/dumps/precompiled_app_package.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/precompiled/app/package.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_closed_lib() {
  YamlFixture.Resolve("tests/data/corpus/precompiled/closed_lib/package.yaml").AssertDumpMatch(
    "tests/data/dumps/precompiled_closed_lib_package.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/precompiled/closed_lib/package.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_locators() {
  YamlFixture.Resolve("tests/data/corpus/design/locators.yaml").AssertDumpMatch(
    "tests/data/dumps/locators.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/design/locators.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_nyra_lock() {
  YamlFixture.Resolve("tests/data/corpus/design/nyra.lock").AssertDumpMatch(
    "tests/data/dumps/nyra.lock.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/design/nyra.lock").AssertRoundTrip();
}

@test
func test_yaml_corpus_manifest() {
  YamlFixture.Resolve("tests/data/corpus/design/manifest.yaml").AssertDumpMatch(
    "tests/data/dumps/manifest.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/design/manifest.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_flow() {
  YamlFixture.Resolve("tests/data/corpus/design/flow.yaml").AssertDumpMatch(
    "tests/data/dumps/flow.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/design/flow.yaml").AssertRoundTrip();
}

@test
func test_yaml_dump_quoted_its() {
  let doc: Yaml = Yaml.ParseOrNull("single: 'it''s'\nempty: \"\"\n");
  let d: string = doc.CanonicalDump();
  AssertTrueMsg(d.Contains("it's"), d);
  AssertTrueMsg(d.Contains("\"empty\""), d);
}

@test
func test_yaml_corpus_quoted() {
  YamlFixture.Resolve("tests/data/corpus/design/quoted.yaml").AssertDumpMatch(
    "tests/data/dumps/quoted.yaml.dump"
  );
  YamlFixture.Resolve("tests/data/corpus/design/quoted.yaml").AssertRoundTrip();
}

@test
func test_yaml_corpus_neg_anchors() {
  YamlFixture.Resolve("tests/data/corpus/negative/anchors.yaml").AssertParseError();
}

@test
func test_yaml_corpus_neg_tabs() {
  YamlFixture.Resolve("tests/data/corpus/negative/tabs-indent.yaml").AssertParseError();
}

@test
func test_yaml_corpus_neg_dup_keys() {
  YamlFixture.Resolve("tests/data/corpus/negative/duplicate-keys.yaml").AssertParseError();
}
