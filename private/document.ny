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

/**
 * @brief Copy `s` into `durable` and adopt as a heap string (survives scratch Reset).
 * @note Requires process-heap durable (`CreateAllocator`); drop frees via `_nyra_*`.
 */
method(YamlDomState) CopyDurable(s: string) -> string {
  if s.length <= 0 {
    return "";
  }

  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = self.durable.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return "";
  }

  memcpy(p, s.data as *const uint8, n);

  return string.AdoptFrom(p as *const int8, s.length);
}

static method(YamlDomState) New(durable: Allocator) -> YamlDomState {
  return YamlDomState{
    durable: durable,
    top: ptr<YamlDomFrame>.null(),
    depth: 0,
    root: Yaml.Null(),
    has_root: false,
    failed: false
  };
}

static method(YamlMap) WithAllocator(durable: Allocator) -> YamlMap {
  return YamlMap{entries: Array<YamlMapEntry>.NewWithAllocator(durable)};
}

static method(YamlSeq) WithAllocator(durable: Allocator) -> YamlSeq {
  return YamlSeq{items: Array<Yaml>.NewWithAllocator(durable)};
}

static method(YamlDomFrame) Allocate(
  durable: Allocator,
  is_map: bool,
  prev: *mut YamlDomFrame
) -> *mut YamlDomFrame {
  let nbytes: int64 = sizeof(YamlDomFrame) as int64;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8i64);
  if raw == (ptr<int8>.null()) {
    return ptr<YamlDomFrame>.null();
  }

  return YamlDomFrame.Initialize(raw, durable, is_map, prev);
}

static method(YamlDomFrame) Initialize(raw: *mut int8, durable: Allocator, is_map: bool,
  prev: *mut YamlDomFrame) -> *mut YamlDomFrame {
  // Owned field assignment drops the previous value; raw heap bytes have none.
  memset(raw as *mut uint8, 0u8, sizeof(YamlDomFrame) as uintptr);
  let fp: *mut YamlDomFrame = cast<YamlDomFrame>.pointer(raw);
  unsafe {
    (*fp).is_map = is_map;
    (*fp).map = YamlMap.WithAllocator(durable);
    (*fp).seq = YamlSeq.WithAllocator(durable);
    (*fp).pending_key = "";
    (*fp).has_pending_key = false;
    (*fp).prev = prev;
  }

  return fp;
}

static method(YamlDomFrame) Release(fp: *mut YamlDomFrame) -> void {
  if fp == (ptr<YamlDomFrame>.null()) {
    return;
  }

  unsafe {
    (*fp).pending_key = "";
    (*fp).map = YamlMap{entries: Array<YamlMapEntry>{}};
    (*fp).seq = YamlSeq{items: Array<Yaml>{}};
    (*fp).prev = ptr<YamlDomFrame>.null();
  }

  _nyra_free(cast<int8>.pointer(fp));
}

method(YamlDomState) ClearStack() -> void {
  unsafe {
    var cur: *mut YamlDomFrame = self.top;
    while cur != (ptr<YamlDomFrame>.null()) {
      let prev: *mut YamlDomFrame = (*cur).prev;
      YamlDomFrame.Release(cur);
      cur = prev;
    }

    self.top = ptr<YamlDomFrame>.null();
    self.depth = 0;
  }
}

method(YamlDomState) PushMap() -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = YamlDomFrame.Allocate(self.durable, true,self.top);
    if fp == (ptr<YamlDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    self.top = fp;
    self.depth = self.depth + 1;
  }

  return true;
}

method(YamlDomState) PushSeq() -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = YamlDomFrame.Allocate(self.durable, false,self.top);
    if fp == (ptr<YamlDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    self.top = fp;
    self.depth = self.depth + 1;
  }

  return true;
}

method(YamlDomState) AddValue(v: Yaml) -> bool {
  unsafe {
    if self.failed {
      return false;
    }

    let fp: *mut YamlDomFrame = self.top;
    if fp == (ptr<YamlDomFrame>.null()) {
      self.root = v;
      self.has_root = true;

      return true;
    }

    if (*fp).is_map {
      if ! (*fp).has_pending_key {
        self.failed = true;

        return false;
      }

      let key: string = (*fp).pending_key;
      (*fp).pending_key = "";
      (*fp).has_pending_key = false;
      (*fp).map.entries.Push(YamlMapEntry{key: key, value: v});

      return true;
    }

    (*fp).seq.items.Push(v);

    return true;
  }
}

method(YamlDomState) EndMap() -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = self.top;
    if fp == (ptr<YamlDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    if ! (*fp).is_map {
      self.failed = true;

      return false;
    }

    let node: Yaml = Yaml{node:(*fp).map};
    (*fp).map = YamlMap{entries: Array<YamlMapEntry>{}};
    self.top = (*fp).prev;
    self.depth = self.depth - 1;
    YamlDomFrame.Release(fp);

    return self.AddValue(node);
  }
}

method(YamlDomState) EndSeq() -> bool {
  unsafe {
    let fp: *mut YamlDomFrame = self.top;
    if fp == (ptr<YamlDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    if (*fp).is_map {
      self.failed = true;

      return false;
    }

    let node: Yaml = Yaml{node:(*fp).seq};
    (*fp).seq = YamlSeq{items: Array<Yaml>{}};
    self.top = (*fp).prev;
    self.depth = self.depth - 1;
    YamlDomFrame.Release(fp);

    return self.AddValue(node);
  }
}

method(YamlDomBuilder) Null() -> bool {
  unsafe {
    return (*self.st).AddValue(Yaml.Null());
  }
}

method(YamlDomBuilder) Bool(b: bool) -> bool {
  unsafe {
    return (*self.st).AddValue(Yaml.FromBool(b));
  }
}

method(YamlDomBuilder) Int64(v: int64) -> bool {
  unsafe {
    return (*self.st).AddValue(Yaml.FromInt(v));
  }
}

method(YamlDomBuilder) String(s: string) -> bool {
  unsafe {
    let heap_s: string = (*self.st).CopyDurable(s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*self.st).failed = true;

      return false;
    }

    return (*self.st).AddValue(Yaml.FromStr(heap_s));
  }
}

method(YamlDomBuilder) StartObject() -> bool {
  unsafe {
    return (*self.st).PushMap();
  }
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

    let heap_k: string = (*self.st).CopyDurable(k);
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

  unsafe {
    return (*self.st).EndMap();
  }
}

method(YamlDomBuilder) StartArray() -> bool {
  unsafe {
    return (*self.st).PushSeq();
  }
}

method(YamlDomBuilder) EndArray(element_count: int32) -> bool {
  let _ec: int32 = element_count;

  unsafe {
    return (*self.st).EndSeq();
  }
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
  let frame: *mut uint8 = durable.Alloc(1up);
  if frame == (ptr<uint8>.null()) {
    return Err<YamlDocument, YamlError>(YamlError.New(1, 1, "durable allocator exhausted"));
  }

  var state: YamlDomState = YamlDomState.New(durable);
  let stp: *mut YamlDomState = cast<YamlDomState>.pointer(& mut state);
  var builder: YamlDomBuilder = YamlDomBuilder{st: stp};
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse(text, builder, scratch);
  if r.IsErr() {
    state.ClearStack();
    let eo: YamlError? = r.get_if<YamlError>();
    if eo == nil {
      return Err<YamlDocument, YamlError>(YamlError.New(1, 1, "parse failed"));
    }

    let e: YamlError = eo as YamlError;

    return Err<YamlDocument, YamlError>(YamlError.New(e.line, e.column, e.message));
  }

  unsafe {
    if (*stp).failed || ! (*stp).has_root {
      state.ClearStack();

      return Err<YamlDocument, YamlError>(YamlError.New(1, 1, "document build failed"));
    }

    if (*stp).depth != 0 {
      state.ClearStack();

      return Err<YamlDocument, YamlError>(YamlError.New(1, 1, "document build failed"));
    }

    let doc: YamlDocument = YamlDocument{root:(*stp).root};
    (*stp).has_root = false;
    (*stp).root = Yaml.Null();

    return Ok<YamlDocument, YamlError>(doc);
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
      return Err<YamlDocument, YamlError>(YamlError.New(0, 0, "I/O error reading YAML file: ".Concat(path)));
    }

    let msg: string = YamlError.IoDescription(eo as IoError).Concat(" reading YAML file: ").Concat(path);

    return Err<YamlDocument, YamlError>(YamlError.New(0, 0, msg));
  }

  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return Err<YamlDocument, YamlError>(YamlError.New(0, 0, "I/O error reading YAML file: ".Concat(path)));
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
