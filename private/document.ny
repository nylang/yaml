// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module YamlDom;
part "writer.ny";
part "../tests/dom_storage_selftest.ny";
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";
import "private/reader.ny";
import "private/emit.ny";
import "ntest:ntest.ny";

/**
 * @brief YamlDocument + Handler adapter DOM build (m_v0.18_p2).
 * @note Reader publishes SAX events; private builder copies Key/String into `durable`.
 * @note Open containers use a malloc'd linked stack (not `Array<private struct>` — that breaks
 *   sizeof across some barrel import edges). Map/seq shells use `Array.NewWithAllocator(durable)`
 *   so Push/grow honor Document durable (Y01).
 * @see docs/design/compiler/yaml.md §0.4–0.6
 */

/**
 * @brief One open map or seq while the Handler adapter builds the tree (RapidJSON stack peer).
 */
struct YamlDomFrame {
  is_map: bool;
  map: YamlMap;
  seq: YamlSeq;
  pending_key: string;
  has_pending_key: bool;
  prev: *mut YamlDomFrame;
}

/**
 * @brief Mutable DOM build state (pointed at by the by-value Handler shell).
 */
struct YamlDomState {
  durable: Allocator;
  top: *mut YamlDomFrame;
  depth: int32;
  root: Yaml;
  has_root: bool;
  failed: bool;
}

/**
 * @brief Thin Handler shell — only a pointer; safe to pass as by-value YamlHandler.
 */
struct YamlDomBuilder implements YamlHandler {
  st: *mut YamlDomState;
}

func yaml_doc_fail(line: int32, column: int32, message: string) -> Result<YamlDocument, YamlError> {
  var msg: string = message;
  if message.length > 0 {
    var out: string = string.Alloc(message.length);
    memcpy((out.data as *mut uint8), message.data, message.length as uintptr);
    msg = out;
  }

  let err: YamlError = YamlError{line: line, column: column, message: msg};

  return Err<YamlDocument, YamlError>(err);
}

func yaml_dom_fail() -> Result<YamlDocument, YamlError> {
  return yaml_doc_fail(1, 1, "document build failed");
}

func yaml_doc_ok(doc: YamlDocument) -> Result<YamlDocument, YamlError> {
  return Ok<YamlDocument, YamlError>(doc);
}

func yaml_doc_io_kind(e: IoError) -> string {
  if e == IoError.NotFound {
    return "file not found";
  }

  if e == IoError.PermissionDenied {
    return "permission denied";
  }

  if e == IoError.IsADirectory {
    return "path is a directory";
  }

  if e == IoError.NotADirectory {
    return "path is not a directory";
  }

  if e == IoError.InvalidArgument {
    return "invalid path";
  }

  return "I/O error";
}

/**
 * @brief Copy `s` into `durable` and adopt as a heap string (survives scratch Reset).
 * @note Requires process-heap durable (`CreateAllocator`); drop frees via `_nyra_*`.
 */
func yaml_durable_copy(durable: Allocator, s: string) -> string {
  if s.length <= 0 {
    return YamlEmptyStr();
  }

  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = durable.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return YamlEmptyStr();
  }

  memcpy(p, s.data as *const uint8, n);

  return string.AdoptFrom(p as *const int8, s.length);
}

func yaml_dom_state_new(durable: Allocator) -> YamlDomState {
  return YamlDomState{
    durable: durable,
    top: ptr<YamlDomFrame>.null(),
    depth: 0,
    root: YamlNullNode(),
    has_root: false,
    failed: false
  };
}

func yaml_dom_empty_map(durable: Allocator) -> YamlMap {
  return YamlMap{entries: Array<YamlMapEntry>.NewWithAllocator(durable)};
}

func yaml_dom_empty_seq(durable: Allocator) -> YamlSeq {
  return YamlSeq{items: Array<Yaml>.NewWithAllocator(durable)};
}

func yaml_dom_frame_alloc(
  durable: Allocator,
  is_map: bool,
  prev: *mut YamlDomFrame
) -> *mut YamlDomFrame {
  let nbytes: int64 = sizeof(YamlDomFrame) as int64;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8 as int64);
  if raw == (ptr<int8>.null()) {
    return ptr<YamlDomFrame>.null();
  }

  return yaml_dom_frame_initialize(raw, durable, is_map, prev);
}

func yaml_dom_frame_initialize(raw: *mut int8, durable: Allocator, is_map: bool,
  prev: *mut YamlDomFrame) -> *mut YamlDomFrame {
  // Owned field assignment drops the previous value; raw heap bytes have none.
  memset(raw as *mut uint8, 0 as uint8, sizeof(YamlDomFrame) as uintptr);
  let fp: *mut YamlDomFrame = cast<YamlDomFrame>.pointer(raw);
  unsafe {
    (*fp).is_map = is_map;
    (*fp).map = yaml_dom_empty_map(durable);
    (*fp).seq = yaml_dom_empty_seq(durable);
    (*fp).pending_key = YamlEmptyStr();
    (*fp).has_pending_key = false;
    (*fp).prev = prev;
  }

  return fp;
}

func yaml_dom_frame_free(fp: *mut YamlDomFrame) -> void {
  if fp == (ptr<YamlDomFrame>.null()) {
    return;
  }

  unsafe {
    (*fp).pending_key = YamlEmptyStr();
    (*fp).map = YamlMap{entries: Array<YamlMapEntry>{}};
    (*fp).seq = YamlSeq{items: Array<Yaml>{}};
    (*fp).prev = ptr<YamlDomFrame>.null();
  }

  _nyra_free(cast<int8>.pointer(fp));
}

func yaml_dom_clear_stack(st: *mut YamlDomState) -> void {
  unsafe {
    var cur: *mut YamlDomFrame = (*st).top;
    while cur != (ptr<YamlDomFrame>.null()) {
      let prev: *mut YamlDomFrame = (*cur).prev;
      yaml_dom_frame_free(cur);
      cur = prev;
    }

    (*st).top = ptr<YamlDomFrame>.null();
    (*st).depth = 0;
  }
}

func yaml_dom_push_map(st: *mut YamlDomState) -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = yaml_dom_frame_alloc((*st).durable, true,(*st).top);
    if fp == (ptr<YamlDomFrame>.null()) {
      (*st).failed = true;

      return false;
    }

    (*st).top = fp;
    (*st).depth = (*st).depth + 1;
  }

  return true;
}

func yaml_dom_push_seq(st: *mut YamlDomState) -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = yaml_dom_frame_alloc((*st).durable, false,(*st).top);
    if fp == (ptr<YamlDomFrame>.null()) {
      (*st).failed = true;

      return false;
    }

    (*st).top = fp;
    (*st).depth = (*st).depth + 1;
  }

  return true;
}

func yaml_dom_add_value(st: *mut YamlDomState, v: Yaml) -> bool {
  unsafe {
    if (*st).failed {
      return false;
    }

    let fp: *mut YamlDomFrame = (*st).top;
    if fp == (ptr<YamlDomFrame>.null()) {
      (*st).root = v;
      (*st).has_root = true;

      return true;
    }

    if (*fp).is_map {
      if ! (*fp).has_pending_key {
        (*st).failed = true;

        return false;
      }

      let key: string = (*fp).pending_key;
      (*fp).pending_key = YamlEmptyStr();
      (*fp).has_pending_key = false;
      (*fp).map.entries.Push(YamlMapEntry{key: key, value: v});

      return true;
    }

    (*fp).seq.items.Push(v);

    return true;
  }
}

func yaml_dom_end_map(st: *mut YamlDomState) -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = (*st).top;
    if fp == (ptr<YamlDomFrame>.null()) {
      (*st).failed = true;

      return false;
    }

    if ! (*fp).is_map {
      (*st).failed = true;

      return false;
    }

    let node: Yaml = Yaml{node:(*fp).map};
    (*fp).map = YamlMap{entries: Array<YamlMapEntry>{}};
    (*st).top = (*fp).prev;
    (*st).depth = (*st).depth - 1;
    yaml_dom_frame_free(fp);

    return yaml_dom_add_value(st, node);
  }
}

func yaml_dom_end_seq(st: *mut YamlDomState) -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = (*st).top;
    if fp == (ptr<YamlDomFrame>.null()) {
      (*st).failed = true;

      return false;
    }

    if (*fp).is_map {
      (*st).failed = true;

      return false;
    }

    let node: Yaml = Yaml{node:(*fp).seq};
    (*fp).seq = YamlSeq{items: Array<Yaml>{}};
    (*st).top = (*fp).prev;
    (*st).depth = (*st).depth - 1;
    yaml_dom_frame_free(fp);

    return yaml_dom_add_value(st, node);
  }
}

method(YamlDomBuilder) Null() -> bool {
  return yaml_dom_add_value(self.st, YamlNullNode());
}

method(YamlDomBuilder) Bool(b: bool) -> bool {
  return yaml_dom_add_value(self.st, YamlBoolNode(b));
}

method(YamlDomBuilder) Int64(v: int64) -> bool {
  return yaml_dom_add_value(self.st, YamlIntNode(v));
}

method(YamlDomBuilder) String(s: string) -> bool {
  unsafe {
    let heap_s: string = yaml_durable_copy((*self.st).durable, s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*self.st).failed = true;

      return false;
    }

    return yaml_dom_add_value(self.st, YamlStrNode(heap_s));
  }
}

method(YamlDomBuilder) StartObject() -> bool {
  return yaml_dom_push_map(self.st);
}

method(YamlDomBuilder) Key(k: string) -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = (*self.st).top;
    if fp == (ptr<YamlDomFrame>.null()) {
      (*self.st).failed = true;

      return false;
    }

    if ! (*fp).is_map {
      (*self.st).failed = true;

      return false;
    }

    let heap_k: string = yaml_durable_copy((*self.st).durable, k);
    if (k.length > 0) && (heap_k.length <= 0) {
      (*self.st).failed = true;

      return false;
    }

    (*fp).pending_key = heap_k;
    (*fp).has_pending_key = true;

    return true;
  }
}

method(YamlDomBuilder) EndObject(member_count: int32) -> bool {
  let _mc: int32 = member_count;

  return yaml_dom_end_map(self.st);
}

method(YamlDomBuilder) StartArray() -> bool {
  return yaml_dom_push_seq(self.st);
}

method(YamlDomBuilder) EndArray(element_count: int32) -> bool {
  let _ec: int32 = element_count;

  return yaml_dom_end_seq(self.st);
}

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
) -> Result<YamlDocument, YamlError> {
  let frame: *mut uint8 = durable.Alloc(1 as uintptr);
  if frame == (ptr<uint8>.null()) {
    return yaml_doc_fail(1, 1, "durable allocator exhausted");
  }

  var state: YamlDomState = yaml_dom_state_new(durable);
  let stp: *mut YamlDomState = cast<YamlDomState>.pointer(& mut state);
  var builder: YamlDomBuilder = YamlDomBuilder{st: stp};
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse(text, builder, scratch);
  if r.IsErr() {
    yaml_dom_clear_stack(stp);
    let eo: YamlError? = r.get_if<YamlError>();
    if eo == nil {
      return yaml_doc_fail(1, 1, "parse failed");
    }

    let e: YamlError = eo as YamlError;

    return yaml_doc_fail(e.line, e.column, e.message);
  }

  unsafe {
    if (*stp).failed || ! (*stp).has_root {
      yaml_dom_clear_stack(stp);

      return yaml_dom_fail();
    }

    if (*stp).depth != 0 {
      yaml_dom_clear_stack(stp);

      return yaml_dom_fail();
    }

    let doc: YamlDocument = YamlDocument{root:(*stp).root};
    (*stp).has_root = false;
    (*stp).root = YamlNullNode();

    return yaml_doc_ok(doc);
  }
}

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
) -> Result<YamlDocument, YamlError> {
  let f: File = File.New(path);
  let rd: Result<string, IoError> = f.ReadAsString();
  if rd.IsErr() {
    let eo: IoError? = rd.get_if<IoError>();
    if eo == nil {
      return yaml_doc_fail(0, 0, "I/O error reading YAML file: ".Concat(path));
    }

    let msg: string = yaml_doc_io_kind(eo as IoError).Concat(" reading YAML file: ").Concat(path);

    return yaml_doc_fail(0, 0, msg);
  }

  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return yaml_doc_fail(0, 0, "I/O error reading YAML file: ".Concat(path));
  }

  let src: string = text_opt as string;
  let heap_text: string = copy(src);

  return YamlDocument.Parse(heap_text, durable, scratch);
}

/**
 * @brief Document root node (retain-copy of the durable tree root).
 * @returns The Yaml value described above, retaining the documented ownership and default-state
 *   semantics.
 */
pub method(YamlDocument) Root() -> Yaml {
  return self.root;
}
