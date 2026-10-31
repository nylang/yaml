// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/**
 * @brief Product face for package `yaml` — Handler/Reader/Document/Writer + DOM query.
 * @note Layouts and accessors live in `public/`; Reader/Document/Writer in `private/`.
 * @note m_v0.18_p3 hard cut: free `Parse`/`ParseFile`/`Emit` deleted; use
 *   Document/Reader/Writer.
 * @see docs/design/compiler/yaml.md §0
 */
import "stdlib:stdlib.ny";

/**
 * @brief SAX handler for `YamlReader` (RapidJSON-style Object/Array event names).
 * @note Return `true` to continue, `false` to abort the Reader (Parse → Err).
 * @see docs/design/compiler/yaml.md §0.3
 */
pub interface YamlHandler {
  Null() -> bool;
  Bool(b: bool) -> bool;
  Int64(v: int64) -> bool;
  String(s: string) -> bool;
  StartObject() -> bool;
  Key(k: string) -> bool;
  EndObject(member_count: int32) -> bool;
  StartArray() -> bool;
  EndArray(element_count: int32) -> bool;
}

/**
 * @brief UTF-8 bytes → Handler events; parse temps on caller `scratch` Allocator.
 * @see docs/design/compiler/yaml.md §0.4
 */
pub struct YamlReader;

/**
 * @brief Construct a Reader (stateless; scratch is per-Parse).
 * @returns The YamlReader value described above, retaining the documented ownership and
 *   default-state semantics.
 */
pub static method(YamlReader) New() -> YamlReader;

/**
 * @brief Parse `text` and publish Handler events in document order.
 * @param text UTF-8 source; empty input is one `Null` event.
 * @param handler SAX receiver (iface by value — Drawable peer; fat pointer mutates impl state).
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Key/String temps; not durable
 *   nodes.
 * @returns Ok on full publish; Err on scan/parse failure or handler abort.
 * @note SoT spells `ref mut YamlHandler`; host-nyra iface dispatch requires by-value iface
 *   today.
 */
pub method(YamlReader) Parse(
  text: string,
  handler: YamlHandler,
  scratch: Allocator
) -> Result<Unit, YamlError>;

/**
 * @brief Read `path` then `Parse`.
 * @returns Ok with Unit on success; Err with YamlError on the failure paths described above.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub method(YamlReader) ParseFile(
  path: string,
  handler: YamlHandler,
  scratch: Allocator
) -> Result<Unit, YamlError>;

/**
 * @brief Durable DOM document built by a Handler adapter fed by `YamlReader`.
 * @note Nodes/strings retained on `durable`; parse temps on `scratch` (yaml.md §0.6).
 * @see docs/design/compiler/yaml.md §0.4–0.5
 */
pub struct YamlDocument;

/**
 * @brief Parse `text` into a durable DOM via Reader → Document Handler adapter.
 * @param text UTF-8 source; empty input is one `YamlNull` root.
 * @param durable Allocator for Key/String (and Document storage); typical hosted:
 *   `CreateAllocator`.
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Reader temps; Reset after Ok must
 *   not pin Document.
 * @returns Ok with YamlDocument on success; Err with YamlError on the failure paths described
 *   above.
 */
pub static method(YamlDocument) Parse(
  text: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<YamlDocument, YamlError>;

/**
 * @brief Read `path` then `YamlDocument.Parse`.
 * @returns Ok with YamlDocument on success; Err with YamlError on the failure paths described
 *   above.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub static method(YamlDocument) ParseFile(
  path: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<YamlDocument, YamlError>;

/**
 * @brief Document root node (retain-copy of the durable tree root).
 * @returns The Yaml value described above, retaining the documented ownership and default-state
 *   semantics.
 */
pub method(YamlDocument) Root() -> Yaml;

/**
 * @brief YAML `null` / `Null` / `NULL` / `~` (YAML 1.2 core). Arm 0 of `Yaml`.
 */
pub struct YamlNull;

/**
 * @brief YAML bool scalar (`true` / `True` / `TRUE` / `false` / `False` / `FALSE`). Arm 1.
 */
pub struct YamlBool;

/**
 * @brief Decimal integer that fits `int64`. Arm 2.
 */
pub struct YamlInt;

/**
 * @brief String scalar (plain or quoted; quotes discarded). Arm 3.
 */
pub struct YamlStr;

/**
 * @brief Sequence node; `items` insertion order. Arm 4.
 */
pub struct YamlSeq;

/**
 * @brief One mapping entry; keys are strings only.
 */
pub struct YamlMapEntry;

/**
 * @brief Mapping node; `entries` insertion / parse order. Arm 5.
 */
pub struct YamlMap;

/**
 * @brief In-memory YAML document tree.
 * @note yaml.md §1.3 escape hatch: `struct Yaml { node: variant<…> }` because recursive `typedef
 *   Yaml = variant<…>` through `Array<Yaml>` is rejected. Do not rename to YamlNode.
 */
pub struct Yaml;

/**
 * @brief SAX/DOM Writer — implements `YamlHandler`; events or `Accept` → toolchain YAML text.
 * @see docs/design/compiler/yaml.md §0.4 · §1.5
 *
 * @note Handler methods are on the product face; private shell implements `YamlHandler` for
 *   `Accept` (host-nyra pub-struct `implements` itable edge — DomBuilder peer).
 */
pub struct YamlWriter;

/**
 * @brief Construct an empty Writer (Handler state on the heap).
 * @returns The YamlWriter value described above, retaining the documented ownership and
 *   default-state semantics.
 */
pub static method(YamlWriter) New() -> YamlWriter;

/**
 * @brief UTF-8 YAML text accumulated from Handler events / `Accept`.
 * @returns UTF-8 YAML text accumulated from Handler events / `Accept`.
 */
pub method(YamlWriter) GetString() -> string;

/**
 * @brief Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 * @returns Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 */
pub static method(YamlWriter) Emit(node: Yaml) -> string;

/**
 * @brief Append a null scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Null() -> bool;

/**
 * @brief Append a boolean scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Bool(b: bool) -> bool;

/**
 * @brief Append a signed integer scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Int64(v: int64) -> bool;

/**
 * @brief Append a string scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) String(s: string) -> bool;

/**
 * @brief Begin an object/mapping container.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) StartObject() -> bool;

/**
 * @brief Set the next object/mapping key.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Key(k: string) -> bool;

/**
 * @brief Finish the current object/mapping event with its member count.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) EndObject(member_count: int32) -> bool;

/**
 * @brief Begin an array/sequence container.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) StartArray() -> bool;

/**
 * @brief Finish the current array/sequence event with its element count.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) EndArray(element_count: int32) -> bool;

/**
 * @brief Walk this DOM node publishing Handler events (Object/Array names).
 * @returns `false` if any Handler method aborts.
 */
pub method(Yaml) Accept(handler: YamlHandler) -> bool;

/**
 * @brief Parse or I/O failure from this library (not a compiler `NYxxxx`).
 * @note `line` / `column` are 1-based for scan/parse errors; I/O may use 0.
 */
pub struct YamlError;

/**
 * @brief First entry whose key equals `key`, or `nil` if absent.
 * @param key Mapping key (string keys only).
 * @returns Matching value, or `nil`.
 */
pub method(YamlMap) Get(key: string) -> Yaml?;

/**
 * @brief Entry count.
 * @returns Number of `entries`.
 */
pub method(YamlMap) Len() -> int32;

/**
 * @brief Key of the entry at 0-based `index`, or `nil` if out of range.
 * @returns The matching payload, or nil for the absent/out-of-range case described above.
 * @note Cross-package field access on `YamlMapEntry` is not available; use this helper.
 */
pub method(YamlMap) KeyAt(index: int32) -> string?;

/**
 * @brief Value of the entry at 0-based `index`, or `nil` if out of range.
 * @returns The matching payload, or nil for the absent/out-of-range case described above.
 */
pub method(YamlMap) ValueAt(index: int32) -> Yaml?;

/**
 * @brief Element at 0-based `index`, or `nil` if out of range.
 * @param index Sequence index.
 * @returns Matching item, or `nil`.
 */
pub method(YamlSeq) Get(index: int32) -> Yaml?;

/**
 * @brief Item count.
 * @returns Number of `items`.
 */
pub method(YamlSeq) Len() -> int32;

/**
 * @brief UTF-8 payload of a string scalar (cross-package accessor).
 * @returns UTF-8 payload of a string scalar (cross-package accessor).
 */
pub method(YamlStr) Text() -> string;

/**
 * @brief Read the boolean scalar payload.
 * @returns The stored boolean value.
 */
pub method(YamlBool) Value() -> bool;

/**
 * @brief Integer scalar payload.
 * @returns Integer scalar payload.
 */
pub method(YamlInt) I64() -> int64;

/**
 * @brief Read a representable signed integer from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub method(Yaml) AsInt() -> int64?;

/**
 * @brief Read a mapping from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub method(Yaml) AsMap() -> YamlMap?;

/**
 * @brief Read a sequence from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub method(Yaml) AsSeq() -> YamlSeq?;

/**
 * @brief 1-based line (0 for I/O errors).
 * @returns 1-based line (0 for I/O errors).
 */
pub method(YamlError) Line() -> int32;

/**
 * @brief 1-based column (0 for I/O errors).
 * @returns 1-based column (0 for I/O errors).
 */
pub method(YamlError) Column() -> int32;

/**
 * @brief English error detail (no `NYxxxx`).
 * @returns English error detail (no `NYxxxx`).
 */
pub method(YamlError) Message() -> string;

/**
 * @brief Compare two YAML trees structurally and by scalar values.
 * @returns True when node kinds and their recursive contents match.
 * @note Existing comparison entry retained across implementation module separation.
 */
pub method(Yaml) Equals(b: Yaml) -> bool;

/**
 * @brief Format the existing canonical diagnostic tree dump.
 * @returns A JSON-like diagnostic representation followed by one newline.
 * @note This diagnostic format is distinct from YamlWriter.Emit's YAML document text.
 */
pub method(Yaml) CanonicalDump() -> string;

/**
 * @brief Read a string scalar without coercing other YAML kinds.
 * @returns Owned text for a string node, including empty text; nil for every other kind.
 */
pub method(Yaml) AsStr() -> string?;

/**
 * @brief Read an optional string-valued mapping entry.
 * @param key Mapping key borrowed during lookup.
 * @returns Owned string payload; empty text for missing, non-string or empty values.
 */
pub method(YamlMap) TextOrEmpty(key: string) -> string;

/**
 * @brief Read a boolean scalar without coercing other YAML kinds.
 * @returns The stored true or false value; nil for every non-boolean kind.
 */
pub method(Yaml) AsBool() -> bool?;
