/**
 * @brief Open layouts and accessors for the `yaml` document model.
 * @note `Yaml` is a wrapper struct (yaml.md §1.3). Walk `.node` with `holds` / `get_if` / `visit`.
 * @see docs/design/compiler/yaml.md §1.3
 */

module YamlTypes;
part "../tests/a_yaml_selftest.ny";
part "../private/scan.ny";
part "../tests/scan_selftest.ny";
part "../private/parse.ny";
part "../tests/parse_selftest.ny";
part "../private/reader.ny";
part "../tests/reader_selftest.ny";
part "../private/document.ny";
part "../tests/document_selftest.ny";
part "../private/emit.ny";
part "../private/writer.ny";
part "../tests/writer_selftest.ny";
part "../tests/emit_selftest.ny";
part "../private/dump.ny";
part "../tests/dump_selftest.ny";
part "../tests/z_corpus_selftest.ny";

import "stdlib:stdlib.ny";
import "ntest:ntest.ny";
import "interface/yaml.ni";

/**
 * @brief YAML `null` payload (no data).
 */
pub struct YamlNull {
  _pad: int8;
}

/**
 * @brief YAML bool payload.
 */
pub struct YamlBool {
  value: bool;
}

pub method(YamlBool) Value() -> bool {
  return self.value;
}

/**
 * @brief YAML integer payload (`int64` range).
 */
pub struct YamlInt {
  value: int64;
}

/**
 * @brief YAML string payload (UTF-8; original quotes discarded by Parse).
 */
pub struct YamlStr {
  value: string;
}

/**
 * @brief YAML sequence payload.
 */
pub struct YamlSeq {
  items: Array<Yaml>;
}

/**
 * @brief One string-keyed mapping entry.
 */
pub struct YamlMapEntry {
  key: string;
  value: Yaml;
}

/**
 * @brief YAML mapping payload (insertion order).
 */
pub struct YamlMap {
  entries: Array<YamlMapEntry>;
}

/**
 * @brief Document node: wrapper around the product variant (yaml.md §1.3 escape hatch).
 * @note Arm order 0–5: Null, Bool, Int, Str, Seq, Map. Walk `.node` with `holds` / `get_if` / `visit`.
 */
pub struct Yaml {
  node: variant<YamlNull, YamlBool, YamlInt, YamlStr, YamlSeq, YamlMap>;
}

/**
 * @brief Parse/I/O error payload.
 */
pub struct YamlError {
  line: int32;
  column: int32;
  message: string;
}

/**
 * @brief SAX Reader (yaml.md §0.4). Stateless shell — scratch is per-Parse.
 */
pub struct YamlReader {
  _pad: int8;
}

/**
 * @brief Durable DOM document (yaml.md §0.4). Built by Handler adapter from Reader events.
 * @note Key/String bytes are copied via the Parse-time `durable` Allocator; caller must keep
 *       that durable region alive for the Document lifetime (yaml.md §0.6).
 */
pub struct YamlDocument {
  root: Yaml;
}

/**
 * @brief First matching key, or `nil` if absent.
 */
pub method(YamlMap) Get(key: string) -> Yaml? {
  var i: int32 = 0;
  let n: int32 = self.entries.Len();
  while i < n {
    // Pointer walk: Array.Get of owned YamlMapEntry would move the slot out.
    unsafe {
      let ep: *mut YamlMapEntry = &mut self.entries.buf[i];
      if ((*ep).key == key) {
        let out: Yaml? = (*ep).value;
        return out;
      }
    }
    i = i + 1;
  }
  return nil;
}

/**
 * @brief Mapping entry count.
 */
pub method(YamlMap) Len() -> int32 {
  return self.entries.Len();
}

/**
 * @brief Key at `index`, or `nil` if out of range.
 * @note Reads via entry pointer (no Array.Get copy) so key/value drops do not double-free.
 */
pub method(YamlMap) KeyAt(index: int32) -> string? {
  if index < 0 {
    return nil;
  }
  if index >= self.entries.Len() {
    return nil;
  }
  unsafe {
    let ep: *mut YamlMapEntry = &mut self.entries.buf[index];
    let out: string? = copy((*ep).key);
    return out;
  }
}

/**
 * @brief Value at `index`, or `nil` if out of range.
 * @note Reads via entry pointer (no Array.Get copy) so key/value drops do not double-free.
 */
pub method(YamlMap) ValueAt(index: int32) -> Yaml? {
  if index < 0 {
    return nil;
  }
  if index >= self.entries.Len() {
    return nil;
  }
  unsafe {
    let ep: *mut YamlMapEntry = &mut self.entries.buf[index];
    let out: Yaml? = (*ep).value;
    return out;
  }
}

/**
 * @brief String scalar payload.
 */
pub method(YamlStr) Text() -> string {
  return copy(self.value);
}

/**
 * @brief Integer scalar payload.
 */
pub method(YamlInt) I64() -> int64 {
  return self.value;
}

/**
 * @brief If `doc` is an integer scalar, return its value.
 */
pub func YamlAsInt(doc: Yaml) -> int64? {
  let iv: YamlInt? = doc.node.get_if<YamlInt>();
  if iv == nil {
    return nil;
  }
  return (iv as YamlInt).I64();
}

/**
 * @brief If `doc` is a mapping node, return it.
 */
pub func YamlAsMap(doc: Yaml) -> YamlMap? {
  return doc.node.get_if<YamlMap>();
}

/**
 * @brief If `doc` is a sequence node, return it.
 */
pub func YamlAsSeq(doc: Yaml) -> YamlSeq? {
  return doc.node.get_if<YamlSeq>();
}

/**
 * @brief Error line.
 */
pub method(YamlError) Line() -> int32 {
  return self.line;
}

/**
 * @brief Error column.
 */
pub method(YamlError) Column() -> int32 {
  return self.column;
}

/**
 * @brief Error message text.
 */
pub method(YamlError) Message() -> string {
  return copy(self.message);
}

/**
 * @brief Sequence element at `index`, or `nil` if out of range.
 */
pub method(YamlSeq) Get(index: int32) -> Yaml? {
  if index < 0 {
    return nil;
  }
  if index >= self.items.Len() {
    return nil;
  }
  // Pointer read + optional pack moves the element (single owner). Prefer this
  // over Array.Get, which also moves but is easier to misuse across drops.
  unsafe {
    let ip: *mut Yaml = &mut self.items.buf[index];
    let out: Yaml? = *ip;
    return out;
  }
}

/**
 * @brief Sequence item count.
 */
pub method(YamlSeq) Len() -> int32 {
  return self.items.Len();
}
