// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module YamlEvents;
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";
import "private/parse.ny";

/**
 * @brief YamlReader + Handler event publish (m_v0.18_p1).
 * @note Parse path: existing v1 recursive-descent tree → RapidJSON-order SAX events.
 * @note Key/String payloads are copied into `scratch` (MemStack/MemArena as Allocator).
 * @see docs/design/compiler/yaml.md §0.3–0.6
 */

/**
 * @brief Copy `s` into `scratch`; return a view over the scratch bytes (not heap-owned).
 * @note Handler may observe scratch-backed strings; Document (p2) must copy into durable.
 */
// Publish child events in document order and stop immediately when the handler rejects an event.
/**
 * @brief Walk a retained YAML tree and publish Handler events using caller scratch storage.
 * @returns False on Handler refusal; true after the node and all children were published.
 */
pub method(Yaml) Publish(handler: YamlHandler, scratch: Allocator) -> bool {
  if self.node.holds<YamlNull>() {
    return handler.Null();
  }

  if self.node.holds<YamlBool>() {
    let bv: YamlBool? = self.node.get_if<YamlBool>();
    if bv == nil {
      return handler.Null();
    }

    let b: YamlBool = bv as YamlBool;

    return handler.Bool(b.value);
  }

  if self.node.holds<YamlInt>() {
    let iv: YamlInt? = self.node.get_if<YamlInt>();
    if iv == nil {
      return handler.Null();
    }

    let n: YamlInt = iv as YamlInt;

    return handler.Int64(n.value);
  }

  if self.node.holds<YamlStr>() {
    let sv: YamlStr? = self.node.get_if<YamlStr>();
    if sv == nil {
      return handler.Null();
    }

    let s: YamlStr = sv as YamlStr;
    let copied_view: string? = scratch.CopyStringView(s.value);
    let view: string = copied_view != nil ? copied_view as string : "";
    if (s.value.length > 0) && (view.length <= 0) {
      return false;
    }

    return handler.String(view);
  }

  if self.node.holds<YamlSeq>() {
    let seq_opt: YamlSeq? = self.node.get_if<YamlSeq>();
    if seq_opt == nil {
      return handler.Null();
    }

    var seqv: YamlSeq = seq_opt as YamlSeq;

    return seqv.Publish(handler, scratch);
  }

  if self.node.holds<YamlMap>() {
    let map_opt: YamlMap? = self.node.get_if<YamlMap>();
    if map_opt == nil {
      return handler.Null();
    }

    var mapv: YamlMap = map_opt as YamlMap;

    return mapv.Publish(handler, scratch);
  }

  return handler.Null();
}

method(YamlMap) Publish(handler: YamlHandler, scratch: Allocator) -> bool {
  if !handler.StartObject() {
    return false;
  }

  let n: int32 = self.Len();
  var i: int32 = 0;
  while i < n {
    unsafe {
      let ep: *mut YamlMapEntry = &mut self.entries.buf[i];
      let copied_kview: string? = scratch.CopyStringView((*ep).key);
      let kview: string = copied_kview != nil ? copied_kview as string : "";
      if ((*ep).key.length > 0) && (kview.length <= 0) {
        return false;
      }

      if !handler.Key(kview) {
        return false;
      }

      if !((*ep).value).Publish(handler, scratch) {
        return false;
      }
    }

    i = i + 1;
  }

  return handler.EndObject(n);
}

method(YamlSeq) Publish(handler: YamlHandler, scratch: Allocator) -> bool {
  if !handler.StartArray() {
    return false;
  }

  let n: int32 = self.Len();
  var i: int32 = 0;
  while i < n {
    unsafe {
      let ip: *mut Yaml = &mut self.items.buf[i];
      if !(*ip).Publish(handler, scratch) {
        return false;
      }
    }

    i = i + 1;
  }

  return handler.EndArray(n);
}

/**
 * @brief Construct a Reader (stateless; scratch is per-Parse).
 * @returns The YamlReader value described above, retaining the documented ownership and
 *   default-state semantics.
 */
pub static method(YamlReader) New() -> YamlReader {
  return YamlReader{_pad: 0};
}

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
) -> Result<Unit, YamlError> {
  // Touch scratch up front so MemStack/MemArena wiring is exercised even for empty docs.
  let frame: *mut uint8 = scratch.Alloc(1up);
  if frame == (ptr<uint8>.null()) {
    return Err<Unit, YamlError>(YamlError.New(1, 1, "scratch allocator exhausted"));
  }

  let parsed: Result<Yaml, YamlError> = Yaml.ParseSyntax(text);
  if parsed.IsErr() {
    let eo: YamlError? = parsed.get_if<YamlError>();
    if eo == nil {
      return Err<Unit, YamlError>(YamlError.New(1, 1, "parse failed"));
    }

    let e: YamlError = eo as YamlError;

    return Err<Unit, YamlError>(YamlError.New(e.line, e.column, e.message));
  }

  let root_opt: Yaml? = parsed.get_if<Yaml>();
  if root_opt == nil {
    return Err<Unit, YamlError>(YamlError.New(1, 1, "parse failed"));
  }

  let root: Yaml = root_opt as Yaml;
  if !root.Publish(handler, scratch) {
    return Err<Unit, YamlError>(YamlError.New(1, 1, "handler aborted"));
  }

  return Ok<Unit, YamlError>(UnitValue());
}

/**
 * @brief Read `path` then `Parse`.
 * @returns Ok with Unit on success; Err with YamlError on the failure paths described above.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub method(YamlReader) ParseFile(
  path: string,
  handler: YamlHandler,
  scratch: Allocator
) -> Result<Unit, YamlError> {
  let f: File = File.New(path);
  let rd: Result<string, IoError> = f.ReadAsString();
  if rd.IsErr() {
    let eo: IoError? = rd.get_if<IoError>();
    if eo == nil {
      return Err<Unit, YamlError>(YamlError.New(0, 0, "I/O error reading YAML file: ".Concat(path)));
    }

    let msg: string = YamlError.IoDescription(eo as IoError).Concat(" reading YAML file: ").Concat(path);

    return Err<Unit, YamlError>(YamlError.New(0, 0, msg));
  }

  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return Err<Unit, YamlError>(YamlError.New(0, 0, "I/O error reading YAML file: ".Concat(path)));
  }

  let src: string = text_opt as string;
  let heap_text: string = copy(src);

  return self.Parse(heap_text, handler, scratch);
}
