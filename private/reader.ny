/**
 * @brief YamlReader + Handler event publish (m_v0.18_p1).
 * @note Parse path: existing v1 recursive-descent tree → RapidJSON-order SAX events.
 * @note Key/String payloads are copied into `scratch` (MemStack/MemArena as Allocator).
 * @see docs/design/compiler/yaml.md §0.3–0.6
 */
part of YamlTypes;

func yaml_reader_ok() -> Result<Unit, YamlError> {
  let r: Result<Unit, YamlError> = UnitValue();
  return r;
}

func yaml_reader_fail(line: int32, column: int32, message: string) -> Result<Unit, YamlError> {
  var msg: string = message;
  if message.length > 0 {
    var out: string = string.Alloc(message.length);
    memcpy((out.data as *mut uint8), message.data, message.length as uintptr);
    msg = out;
  }
  let err: YamlError = YamlError{ line: line, column: column, message: msg };
  let r: Result<Unit, YamlError> = err;
  return r;
}

func yaml_reader_io_kind(e: IoError) -> string {
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
 * @brief Copy `s` into `scratch`; return a view over the scratch bytes (not heap-owned).
 * @note Handler may observe scratch-backed strings; Document (p2) must copy into durable.
 */
func yaml_scratch_copy(scratch: Allocator, s: string) -> string {
  if s.length <= 0 {
    return yaml_empty_str();
  }
  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = scratch.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return yaml_empty_str();
  }
  memcpy(p, s.data as *const uint8, n);
  return string.ViewFrom(p as *const int8, s.length);
}

func yaml_publish_node(node: Yaml, handler: YamlHandler, scratch: Allocator) -> bool {
  if node.node.holds<YamlNull>() {
    return handler.Null();
  }
  if node.node.holds<YamlBool>() {
    let bv: YamlBool? = node.node.get_if<YamlBool>();
    if bv == nil {
      return handler.Null();
    }
    let b: YamlBool = bv as YamlBool;
    return handler.Bool(b.value);
  }
  if node.node.holds<YamlInt>() {
    let iv: YamlInt? = node.node.get_if<YamlInt>();
    if iv == nil {
      return handler.Null();
    }
    let n: YamlInt = iv as YamlInt;
    return handler.Int64(n.value);
  }
  if node.node.holds<YamlStr>() {
    let sv: YamlStr? = node.node.get_if<YamlStr>();
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
  if node.node.holds<YamlSeq>() {
    let seq_opt: YamlSeq? = node.node.get_if<YamlSeq>();
    if seq_opt == nil {
      return handler.Null();
    }
    var seqv: YamlSeq = seq_opt as YamlSeq;
    return yaml_publish_seq(seqv, handler, scratch);
  }
  if node.node.holds<YamlMap>() {
    let map_opt: YamlMap? = node.node.get_if<YamlMap>();
    if map_opt == nil {
      return handler.Null();
    }
    var mapv: YamlMap = map_opt as YamlMap;
    return yaml_publish_map(mapv, handler, scratch);
  }
  return handler.Null();
}

func yaml_publish_map(mapv: YamlMap, handler: YamlHandler, scratch: Allocator) -> bool {
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

func yaml_publish_seq(seqv: YamlSeq, handler: YamlHandler, scratch: Allocator) -> bool {
  if !handler.StartArray() {
    return false;
  }
  let n: int32 = seqv.Len();
  var i: int32 = 0;
  while i < n {
    unsafe {
      let ip: *mut Yaml = &mut seqv.items.buf[i];
      if !yaml_publish_node(*ip, handler, scratch) {
        return false;
      }
    }
    i = i + 1;
  }
  return handler.EndArray(n);
}

/**
 * @brief Construct a Reader.
 */
pub static method(YamlReader) New() -> YamlReader {
  return YamlReader{ _pad: 0 };
}

/**
 * @brief Parse `text` → Handler events; Key/String temps on `scratch`.
 */
pub method(YamlReader) Parse(
  text: string,
  handler: YamlHandler,
  scratch: Allocator
) -> Result<Unit, YamlError> {
  // Touch scratch up front so MemStack/MemArena wiring is exercised even for empty docs.
  let frame: *mut uint8 = scratch.Alloc(1 as uintptr);
  if frame == (ptr<uint8>.null()) {
    return yaml_reader_fail(1, 1, "scratch allocator exhausted");
  }

  let parsed: Result<Yaml, YamlError> = yaml_parse_result(text);
  if parsed.IsErr() {
    let eo: YamlError? = parsed.get_if<YamlError>();
    if eo == nil {
      return yaml_reader_fail(1, 1, "parse failed");
    }
    let e: YamlError = eo as YamlError;
    return yaml_reader_fail(e.line, e.column, e.message);
  }
  let root_opt: Yaml? = parsed.get_if<Yaml>();
  if root_opt == nil {
    return yaml_reader_fail(1, 1, "parse failed");
  }
  let root: Yaml = root_opt as Yaml;
  if !yaml_publish_node(root, handler, scratch) {
    return yaml_reader_fail(1, 1, "handler aborted");
  }
  return yaml_reader_ok();
}

/**
 * @brief Read `path` with stdlib `File`, then `Parse`.
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
      return yaml_reader_fail(0, 0, "I/O error reading YAML file: ".Concat(path));
    }
    let msg: string = yaml_reader_io_kind(eo as IoError).Concat(" reading YAML file: ").Concat(path);
    return yaml_reader_fail(0, 0, msg);
  }
  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return yaml_reader_fail(0, 0, "I/O error reading YAML file: ".Concat(path));
  }
  let src: string = text_opt as string;
  let heap_text: string = copy(src);
  return self.Parse(heap_text, handler, scratch);
}
