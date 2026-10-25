/**
 * @brief YamlWriter + Yaml.Accept (m_v0.18_p3).
 * @note Accept body is inlined — host-nyra crashes when `method(Yaml)` passes `self` by value
 *       into another `Yaml`-typed parameter (retainStringsInValue / ExtractValue).
 * @see docs/design/compiler/yaml.md §0.4 · §1.5
 */
part of YamlTypes;

pub struct YamlWriter {
  st: *mut int8;
}

/**
 * @brief Walk DOM publishing Handler events (Object/Array names).
 */
pub method(Yaml) Accept(handler: YamlHandler) -> bool {
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
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
    let view: string = yaml_scratch_copy(scratch, s.value);
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
        if !yaml_publish_node(*ip, handler, scratch) {
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
        let kview: string = yaml_scratch_copy(scratch, (*ep).key);
        if ((*ep).key.length > 0) && (kview.length <= 0) {
          return false;
        }
        if !handler.Key(kview) {
          return false;
        }
        if !yaml_publish_node((*ep).value, handler, scratch) {
          return false;
        }
      }
      i = i + 1;
    }
    return handler.EndObject(n);
  }
  return handler.Null();
}

pub static method(YamlWriter) New() -> YamlWriter {
  let nbytes: int64 = 1024 as int64;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8 as int64);
  if raw == (ptr<int8>.null()) {
    return YamlWriter{ st: ptr<int8>.null() };
  }
  // A recycled heap block can contain owned fields from unrelated values.
  memset(raw as *mut uint8, 0 as uint8, nbytes as uintptr);
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(raw);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  unsafe {
    (*sp).durable = durable;
    (*sp).top = ptr<YamlDomFrame>.null();
    (*sp).depth = 0;
    (*sp).root = yaml_null_node();
    (*sp).has_root = false;
    (*sp).failed = false;
  }
  return YamlWriter{ st: raw };
}

pub method(YamlWriter) GetString() -> string {
  if self.st == (ptr<int8>.null()) {
    return copy("null\n");
  }
  unsafe {
    let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
    if (*sp).failed || !(*sp).has_root {
      return copy("null\n");
    }
    if (*sp).depth != 0 {
      return copy("null\n");
    }
    return yaml_emit_text((*sp).root);
  }
}

/**
 * @brief Serialize via New → Accept(DomBuilder) → GetString (yaml.md §0.4).
 */
pub static method(YamlWriter) Emit(node: Yaml) -> string {
  var w: YamlWriter = YamlWriter.New();
  if w.st == (ptr<int8>.null()) {
    return copy("null\n");
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(w.st);
  var builder: YamlDomBuilder = YamlDomBuilder{ st: sp };
  let ok: bool = node.Accept(builder);
  if !ok {
    return copy("null\n");
  }
  return w.GetString();
}

pub method(YamlWriter) Null() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_add_value(sp, yaml_null_node());
}

pub method(YamlWriter) Bool(b: bool) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_add_value(sp, yaml_bool_node(b));
}

pub method(YamlWriter) Int64(v: int64) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_add_value(sp, yaml_int_node(v));
}

pub method(YamlWriter) String(s: string) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  unsafe {
    let heap_s: string = yaml_durable_copy((*sp).durable, s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*sp).failed = true;
      return false;
    }
    return yaml_dom_add_value(sp, yaml_str_node(heap_s));
  }
}

pub method(YamlWriter) StartObject() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_push_map(sp);
}

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
    if !(*fp).is_map {
      (*sp).failed = true;
      return false;
    }
    let heap_k: string = yaml_durable_copy((*sp).durable, k);
    if (k.length > 0) && (heap_k.length <= 0) {
      (*sp).failed = true;
      return false;
    }
    (*fp).pending_key = heap_k;
    (*fp).has_pending_key = true;
    return true;
  }
}

pub method(YamlWriter) EndObject(member_count: int32) -> bool {
  let _mc: int32 = member_count;
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_end_map(sp);
}

pub method(YamlWriter) StartArray() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_push_seq(sp);
}

pub method(YamlWriter) EndArray(element_count: int32) -> bool {
  let _ec: int32 = element_count;
  if self.st == (ptr<int8>.null()) {
    return false;
  }
  let sp: *mut YamlDomState = cast<YamlDomState>.pointer(self.st);
  return yaml_dom_end_seq(sp);
}
