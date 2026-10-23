/**
 * @brief Product face for package `yaml` — Handler/Reader/Document/Writer + DOM query.
 * @note Layouts and accessors live in `public/`; Reader/Document/Writer in `private/`.
 * @note m_v0.18_p3 hard cut: free `Parse`/`ParseFile`/`Emit` deleted; use Document/Reader/Writer.
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
 */
pub static method(YamlReader) New() -> YamlReader;

/**
 * @brief Parse `text` and publish Handler events in document order.
 * @param text UTF-8 source; empty input is one `Null` event.
 * @param handler SAX receiver (iface by value — Drawable peer; fat pointer mutates impl state).
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Key/String temps; not durable nodes.
 * @returns Ok on full publish; Err on scan/parse failure or handler abort.
 * @note SoT spells `ref mut YamlHandler`; host-nyra iface dispatch requires by-value iface today.
 */
pub method(YamlReader) Parse(
  text: string,
  handler: YamlHandler,
  scratch: Allocator
) -> Result<Unit, YamlError>;

/**
 * @brief Read `path` then `Parse`.
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
 * @param durable Allocator for Key/String (and Document storage); typical hosted: `CreateAllocator`.
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Reader temps; Reset after Ok must not pin Document.
 */
pub static method(YamlDocument) Parse(
  text: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<YamlDocument, YamlError>;

/**
 * @brief Read `path` then `YamlDocument.Parse`.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub static method(YamlDocument) ParseFile(
  path: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<YamlDocument, YamlError>;

/**
 * @brief Document root node (retain-copy of the durable tree root).
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
 * @note yaml.md §1.3 escape hatch: `struct Yaml { node: variant<…> }` because recursive
 *       `typedef Yaml = variant<…>` through `Array<Yaml>` is rejected. Do not rename to YamlNode.
 */
pub struct Yaml;

/**
 * @brief SAX/DOM Writer — implements `YamlHandler`; events or `Accept` → toolchain YAML text.
 * @see docs/design/compiler/yaml.md §0.4 · §1.5
 */
/**
 * @note Handler methods are on the product face; private shell implements `YamlHandler`
 *       for `Accept` (host-nyra pub-struct `implements` itable edge — DomBuilder peer).
 */
pub struct YamlWriter;

/**
 * @brief Construct an empty Writer (Handler state on the heap).
 */
pub static method(YamlWriter) New() -> YamlWriter;

/**
 * @brief UTF-8 YAML text accumulated from Handler events / `Accept`.
 */
pub method(YamlWriter) GetString() -> string;

/**
 * @brief Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 */
pub static method(YamlWriter) Emit(node: Yaml) -> string;

pub method(YamlWriter) Null() -> bool;
pub method(YamlWriter) Bool(b: bool) -> bool;
pub method(YamlWriter) Int64(v: int64) -> bool;
pub method(YamlWriter) String(s: string) -> bool;
pub method(YamlWriter) StartObject() -> bool;
pub method(YamlWriter) Key(k: string) -> bool;
pub method(YamlWriter) EndObject(member_count: int32) -> bool;
pub method(YamlWriter) StartArray() -> bool;
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
 * @note Cross-package field access on `YamlMapEntry` is not available; use this helper.
 */
pub method(YamlMap) KeyAt(index: int32) -> string?;

/**
 * @brief Value of the entry at 0-based `index`, or `nil` if out of range.
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
 */
pub method(YamlStr) Text() -> string;

/**
 * @brief Integer scalar payload.
 */
pub method(YamlInt) I64() -> int64;

pub func YamlAsInt(doc: Yaml) -> int64?;
pub func YamlAsMap(doc: Yaml) -> YamlMap?;
pub func YamlAsSeq(doc: Yaml) -> YamlSeq?;

/**
 * @brief 1-based line (0 for I/O errors).
 */
pub method(YamlError) Line() -> int32;

/**
 * @brief 1-based column (0 for I/O errors).
 */
pub method(YamlError) Column() -> int32;

/**
 * @brief English error detail (no `NYxxxx`).
 */
pub method(YamlError) Message() -> string;
