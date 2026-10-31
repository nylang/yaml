// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlDom;

/**
 * @brief YamlWriter + Yaml.Accept (m_v0.18_p3).
 * @note Accept body is inlined — host-nyra crashes when `method(Yaml)` passes `self` by value
 *   into another `Yaml`-typed parameter (retainStringsInValue / ExtractValue).
 * @see docs/design/compiler/yaml.md §0.4 · §1.5
 */

/**
 * @brief SAX/DOM Writer — implements `YamlHandler`; events or `Accept` → toolchain YAML text.
 * @see docs/design/compiler/yaml.md §0.4 · §1.5
 *
 * @note Handler methods are on the product face; private shell implements `YamlHandler` for
 *   `Accept` (host-nyra pub-struct `implements` itable edge — DomBuilder peer).
 */
pub struct YamlWriter {
  st: *mut int8;
}

/**
 * @brief Walk this DOM node publishing Handler events (Object/Array names).
 * @returns `false` if any Handler method aborts.
 */
pub method(Yaml) Accept(handler: YamlHandler) -> bool {
  var scratch: Allocator = Allocator.ProcessHeap(0i64, 8i64);
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
    if !handler.StartArray() {
      return false;
    }

    let n: int32 = seqv.Len();
    var i: int32 = 0;
    while i < n {
      unsafe {
        let ip: *mut Yaml = &mut seqv.items.buf[i];
        // Child walk via free helper (not method(Yaml) self-pass).
        if !(*ip).Publish(handler, scratch) {
          return false;
        }
      }

      i = i + 1;
    }

    return handler.EndArray(n);
  }

  if self.node.holds<YamlMap>() {
    let map_opt: YamlMap? = self.node.get_if<YamlMap>();
    if map_opt == nil {
      return handler.Null();
    }

    var mapv: YamlMap = map_opt as YamlMap;
    if !handler.StartObject() {
      return false;
    }

    let n: int32 = mapv.Len();
    var i: int32 = 0;
    while i < n {
      unsafe {
        let ep: *mut YamlMapEntry = &mut mapv.entries.buf[i];
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

  return handler.Null();
}

/**
 * @brief Construct an empty Writer (Handler state on the heap).
 * @returns The YamlWriter value described above, retaining the documented ownership and
 *   default-state semantics.
 */
pub static method(YamlWriter) New() -> YamlWriter {
  let nbytes: int64 = 1024;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8i64);
  if raw == (ptr<int8>.null()) {
    return YamlWriter{st: ptr<int8>.null()};
  }

  // A recycled heap block can contain owned fields from unrelated values.
  memset(raw as *mut uint8, 0u8, nbytes as uintptr);
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(raw);
  var durable: Allocator = Allocator.ProcessHeap(0i64, 8i64);
  unsafe {
    (*sp).durable = durable;
    (*sp).top = ptr<YamlDomFrame>.null();
    (*sp).depth = 0;
    (*sp).root = Yaml.Null();
    (*sp).has_root = false;
    (*sp).failed = false;
  }

  return YamlWriter{st: raw};
}

/**
 * @brief UTF-8 YAML text accumulated from Handler events / `Accept`.
 * @returns UTF-8 YAML text accumulated from Handler events / `Accept`.
 */
pub method(YamlWriter) GetString() -> string {
  if self.st == (ptr<int8>.null()) {
    return copy("null\n");
  }

  unsafe {
    let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
    if (*sp).failed || ! (*sp).has_root {
      return copy("null\n");
    }

    if (*sp).depth != 0 {
      return copy("null\n");
    }

    return YamlEmitter.Emit((*sp).root);
  }
}

/**
 * @brief Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 * @returns Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 */
pub static method(YamlWriter) Emit(node: Yaml) -> string {
  var w: YamlWriter = YamlWriter.New();
  if w.st == (ptr<int8>.null()) {
    return copy("null\n");
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(w.st);
  var builder: YamlDomBuilder = YamlDomBuilder{st: sp};
  let ok: bool = node.Accept(builder);
  if !ok {
    return copy("null\n");
  }

  return w.GetString();
}

/**
 * @brief Append a null scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Null() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).AddValue(Yaml.Null());
  }
}

/**
 * @brief Append a boolean scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Bool(b: bool) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).AddValue(Yaml.FromBool(b));
  }
}

/**
 * @brief Append a signed integer scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Int64(v: int64) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).AddValue(Yaml.FromInt(v));
  }
}

/**
 * @brief Append a string scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) String(s: string) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  unsafe {
    let heap_s: string = (*sp).CopyDurable(s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*sp).failed = true;

      return false;
    }

    return (*sp).AddValue(Yaml.FromStr(heap_s));
  }
}

/**
 * @brief Begin an object/mapping container.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) StartObject() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).PushMap();
  }
}

/**
 * @brief Set the next object/mapping key.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) Key(k: string) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  unsafe {
    let fp: *mut YamlDomFrame = (*sp).top;
    if fp == (ptr<YamlDomFrame>.null()) {
      (*sp).failed = true;

      return false;
    }

    if ! (*fp).is_map {
      (*sp).failed = true;

      return false;
    }

    let heap_k: string = (*sp).CopyDurable(k);
    if (k.length > 0) && (heap_k.length <= 0) {
      (*sp).failed = true;

      return false;
    }

    (*fp).pending_key = heap_k;
    (*fp).has_pending_key = true;

    return true;
  }
}

/**
 * @brief Finish the current object/mapping event with its member count.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) EndObject(member_count: int32) -> bool {
  let _mc: int32 = member_count;
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).EndMap();
  }
}

/**
 * @brief Begin an array/sequence container.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) StartArray() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).PushSeq();
  }
}

/**
 * @brief Finish the current array/sequence event with its element count.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(YamlWriter) EndArray(element_count: int32) -> bool {
  let _ec: int32 = element_count;
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);

  unsafe {
    return (*sp).EndSeq();
  }
}
