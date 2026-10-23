/**
 * @brief YamlReader / YamlHandler event unit tests (m_v0.18_p1).
 * @note Recorder state lives behind a pointer so by-value iface upcast (stack temp)
 *       still mutates the same arrays. SoT `ref mut YamlHandler` awaits codegen Load.
 * @note MemStack/MemArena must be Init'd in-place (ctx points at self).
 */
part of YamlTypes;

pub static kYamlEvNull: int32 = 1;
pub static kYamlEvBool: int32 = 2;
pub static kYamlEvInt64: int32 = 3;
pub static kYamlEvString: int32 = 4;
pub static kYamlEvStartObject: int32 = 5;
pub static kYamlEvKey: int32 = 6;
pub static kYamlEvEndObject: int32 = 7;
pub static kYamlEvStartArray: int32 = 8;
pub static kYamlEvEndArray: int32 = 9;

/**
 * @brief Mutable event log (pointed at by the Handler shell).
 */
struct YamlEvState {
  kinds: Array<int32>;
  bools: Array<int32>;
  ints: Array<int64>;
  strings: Array<string>;
  counts: Array<int32>;
  abort_at: int32;
  seen: int32;
}

/**
 * @brief Thin Handler shell — only a pointer; safe to pass as by-value YamlHandler.
 */
struct YamlEventRecorder implements YamlHandler {
  st: *mut YamlEvState;
}

func yaml_ev_state_new() -> YamlEvState {
  return YamlEvState{
    kinds: Array<int32>{},
    bools: Array<int32>{},
    ints: Array<int64>{},
    strings: Array<string>{},
    counts: Array<int32>{},
    abort_at: -1,
    seen: 0
  };
}

func yaml_ev_push_kind(st: *mut YamlEvState, k: int32) -> bool {
  unsafe {
    (*st).seen = (*st).seen + 1;
    if ((*st).abort_at >= 0) && ((*st).seen > (*st).abort_at) {
      return false;
    }
    (*st).kinds.Push(k);
    return true;
  }
}

method(YamlEventRecorder) Null() -> bool {
  return yaml_ev_push_kind(self.st, kYamlEvNull);
}

method(YamlEventRecorder) Bool(b: bool) -> bool {
  if !yaml_ev_push_kind(self.st, kYamlEvBool) {
    return false;
  }
  unsafe {
    if b {
      (*self.st).bools.Push(1);
    } else {
      (*self.st).bools.Push(0);
    }
  }
  return true;
}

method(YamlEventRecorder) Int64(v: int64) -> bool {
  if !yaml_ev_push_kind(self.st, kYamlEvInt64) {
    return false;
  }
  unsafe {
    (*self.st).ints.Push(v);
  }
  return true;
}

method(YamlEventRecorder) String(s: string) -> bool {
  if !yaml_ev_push_kind(self.st, kYamlEvString) {
    return false;
  }
  unsafe {
    (*self.st).strings.Push(copy(s));
  }
  return true;
}

method(YamlEventRecorder) StartObject() -> bool {
  return yaml_ev_push_kind(self.st, kYamlEvStartObject);
}

method(YamlEventRecorder) Key(k: string) -> bool {
  if !yaml_ev_push_kind(self.st, kYamlEvKey) {
    return false;
  }
  unsafe {
    (*self.st).strings.Push(copy(k));
  }
  return true;
}

method(YamlEventRecorder) EndObject(member_count: int32) -> bool {
  if !yaml_ev_push_kind(self.st, kYamlEvEndObject) {
    return false;
  }
  unsafe {
    (*self.st).counts.Push(member_count);
  }
  return true;
}

method(YamlEventRecorder) StartArray() -> bool {
  return yaml_ev_push_kind(self.st, kYamlEvStartArray);
}

method(YamlEventRecorder) EndArray(element_count: int32) -> bool {
  if !yaml_ev_push_kind(self.st, kYamlEvEndArray) {
    return false;
  }
  unsafe {
    (*self.st).counts.Push(element_count);
  }
  return true;
}

/**
 * @brief Slice the Allocator ABI row from an in-place-Init'd MemStack (ctx → stack).
 */
func yaml_scratch_from_stack(stack: ref mut MemStack) -> Allocator {
  unsafe {
    let sp: *mut MemStack = cast<MemStack>.pointer(stack);
    let ap: *mut Allocator = cast<Allocator>.pointer(sp);
    return *ap;
  }
}

/**
 * @brief Slice the Allocator ABI row from an in-place-Init'd MemArena (ctx → arena).
 */
func yaml_scratch_from_arena(arena: ref mut MemArena) -> Allocator {
  unsafe {
    let ap: *mut MemArena = cast<MemArena>.pointer(arena);
    let bp: *mut Allocator = cast<Allocator>.pointer(ap);
    return *bp;
  }
}

@test
func test_yaml_reader_empty_null_event() {
  var state: YamlEvState = yaml_ev_state_new();
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 1);
  AssertEqI32(state.kinds.Get(0), kYamlEvNull);
}

@test
func test_yaml_reader_map_name_string() {
  var state: YamlEvState = yaml_ev_state_new();
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("name: x", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 4);
  AssertEqI32(state.kinds.Get(0), kYamlEvStartObject);
  AssertEqI32(state.kinds.Get(1), kYamlEvKey);
  AssertEqI32(state.kinds.Get(2), kYamlEvString);
  AssertEqI32(state.kinds.Get(3), kYamlEvEndObject);
  AssertEqI32(state.strings.Len(), 2);
  AssertEqString(state.strings.Get(0), "name");
  AssertEqString(state.strings.Get(1), "x");
  AssertEqI32(state.counts.Len(), 1);
  AssertEqI32(state.counts.Get(0), 1);
}

@test
func test_yaml_reader_seq_scalars() {
  var state: YamlEvState = yaml_ev_state_new();
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("[true, false, null, 42, hi]", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 7);
  AssertEqI32(state.kinds.Get(0), kYamlEvStartArray);
  AssertEqI32(state.kinds.Get(1), kYamlEvBool);
  AssertEqI32(state.kinds.Get(2), kYamlEvBool);
  AssertEqI32(state.kinds.Get(3), kYamlEvNull);
  AssertEqI32(state.kinds.Get(4), kYamlEvInt64);
  AssertEqI32(state.kinds.Get(5), kYamlEvString);
  AssertEqI32(state.kinds.Get(6), kYamlEvEndArray);
  AssertEqI32(state.bools.Len(), 2);
  AssertEqI32(state.bools.Get(0), 1);
  AssertEqI32(state.bools.Get(1), 0);
  AssertEqI32(state.ints.Len(), 1);
  AssertEqI64(state.ints.Get(0), 42 as int64);
  AssertEqI32(state.strings.Len(), 1);
  AssertEqString(state.strings.Get(0), "hi");
  AssertEqI32(state.counts.Get(0), 5);
}

@test
func test_yaml_reader_nested_map() {
  var state: YamlEvState = yaml_ev_state_new();
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("dependencies:\n  stdlib:\n    path: ../stdlib\n", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 10);
  AssertEqI32(state.kinds.Get(0), kYamlEvStartObject);
  AssertEqI32(state.kinds.Get(1), kYamlEvKey);
  AssertEqI32(state.kinds.Get(2), kYamlEvStartObject);
  AssertEqI32(state.kinds.Get(3), kYamlEvKey);
  AssertEqI32(state.kinds.Get(4), kYamlEvStartObject);
  AssertEqI32(state.kinds.Get(5), kYamlEvKey);
  AssertEqI32(state.kinds.Get(6), kYamlEvString);
  AssertEqI32(state.kinds.Get(7), kYamlEvEndObject);
  AssertEqI32(state.kinds.Get(8), kYamlEvEndObject);
  AssertEqI32(state.kinds.Get(9), kYamlEvEndObject);
  AssertEqString(state.strings.Get(0), "dependencies");
  AssertEqString(state.strings.Get(1), "stdlib");
  AssertEqString(state.strings.Get(2), "path");
  AssertEqString(state.strings.Get(3), "../stdlib");
}

@test
func test_yaml_reader_handler_abort() {
  var state: YamlEvState = yaml_ev_state_new();
  state.abort_at = 1;
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("name: x", rec, scratch);
  AssertTrue(r.IsErr());
  let eo: YamlError? = r.get_if<YamlError>();
  AssertTrue(eo != nil);
  let e: YamlError = eo as YamlError;
  AssertEqString(e.Message(), "handler aborted");
}

@test
func test_yaml_reader_int_and_bool_root() {
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: YamlReader = YamlReader.New();

  var state_i: YamlEvState = yaml_ev_state_new();
  var rec_i: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state_i) };
  let ri: Result<Unit, YamlError> = reader.Parse("7", rec_i, scratch);
  AssertTrue(ri.IsOk());
  AssertEqI32(state_i.kinds.Get(0), kYamlEvInt64);
  AssertEqI64(state_i.ints.Get(0), 7 as int64);

  var state_b: YamlEvState = yaml_ev_state_new();
  var rec_b: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state_b) };
  let rb: Result<Unit, YamlError> = reader.Parse("true", rec_b, scratch);
  AssertTrue(rb.IsOk());
  AssertEqI32(state_b.kinds.Get(0), kYamlEvBool);
  AssertEqI32(state_b.bools.Get(0), 1);
}

@test
func test_yaml_reader_memstack_scratch() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var stack: MemStack = MemStack{};
  stack.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = yaml_scratch_from_stack(stack);
  let mark: uintptr = stack.Mark();
  var state: YamlEvState = yaml_ev_state_new();
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("a: 1\nb: two\n", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 6);
  stack.Reset(mark);
  AssertEqString(state.strings.Get(0), "a");
  AssertEqString(state.strings.Get(1), "b");
  AssertEqString(state.strings.Get(2), "two");
  var state2: YamlEvState = yaml_ev_state_new();
  var rec2: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state2) };
  let r2: Result<Unit, YamlError> = reader.Parse("x: y", rec2, scratch);
  AssertTrue(r2.IsOk());
  AssertEqString(state2.strings.Get(0), "x");
  AssertEqString(state2.strings.Get(1), "y");
  _nyra_free(chunk);
}

@test
func test_yaml_reader_memarena_scratch() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var arena: MemArena = MemArena{};
  arena.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = yaml_scratch_from_arena(arena);
  var state: YamlEvState = yaml_ev_state_new();
  var rec: YamlEventRecorder = YamlEventRecorder{ st: cast<YamlEvState>.pointer(& mut state) };
  var reader: YamlReader = YamlReader.New();
  let r: Result<Unit, YamlError> = reader.Parse("name: x", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 4);
  AssertEqString(state.strings.Get(0), "name");
  AssertEqString(state.strings.Get(1), "x");
  arena.ResetAll();
  arena.Release();
  _nyra_free(chunk);
}
