/**
 * @brief v1 recursive-descent tree parse for package `yaml` (internal).
 * @note Product face is `YamlDocument` / `YamlReader` (yaml.md §0.4). Free `Parse` deleted at m_v0.18_p3.
 * @note Writer/Emit live in `private/writer.ny` + `private/emit.ny`.
 * @see docs/design/compiler/yaml.md §1.3–1.4
 */
part of YamlTypes;

struct YamlI64Parse {
  value: int64;
  ok: bool;
}

func yaml_empty_str() -> string {
  return string.ViewFrom(0 as *const int8, 0);
}

func yaml_copy_str(s: string) -> string {
  if s.length <= 0 {
    return yaml_empty_str();
  }
  var out: string = string.Alloc(s.length);
  memcpy((out.data as *mut uint8), s.data, s.length as uintptr);
  return out;
}

func yaml_null_node() -> Yaml {
  return Yaml{ node: YamlNull{ _pad: 0 } };
}

func yaml_bool_node(v: bool) -> Yaml {
  return Yaml{ node: YamlBool{ value: v } };
}

func yaml_int_node(v: int64) -> Yaml {
  return Yaml{ node: YamlInt{ value: v } };
}

func yaml_str_node(v: string) -> Yaml {
  return Yaml{ node: YamlStr{ value: v } };
}

func yaml_parse_byte(s: string, i: int32) -> int32 {
  if i < 0 {
    return -1;
  }
  if i >= s.length {
    return -1;
  }
  return (s[i] as int32) & 255;
}

func yaml_hex_digit(b: int32) -> int32 {
  if (b >= 48) && (b <= 57) {
    return b - 48;
  }
  if (b >= 65) && (b <= 70) {
    return b - 55;
  }
  if (b >= 97) && (b <= 102) {
    return b - 87;
  }
  return -1;
}

func yaml_utf8_cp(cp: int32) -> string {
  if cp <= 0 {
    return yaml_empty_str();
  }
  if cp < 128 {
    var out: string = string.Alloc(1);
    var b0: uint8 = cp as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    return out;
  }
  if cp <= 2047 {
    var out: string = string.Alloc(2);
    var b0: uint8 = (192 + (cp / 64)) as uint8;
    var b1: uint8 = (128 + (cp - (cp / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1, (&b1) as *const uint8, 1 as uintptr);
    return out;
  }
  if cp <= 65535 {
    var out: string = string.Alloc(3);
    var b0: uint8 = (224 + (cp / 4096)) as uint8;
    let r1: int32 = cp - (cp / 4096) * 4096;
    var b1: uint8 = (128 + (r1 / 64)) as uint8;
    var b2: uint8 = (128 + (r1 - (r1 / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1, (&b1) as *const uint8, 1 as uintptr);
    let p2: *mut uint8 = (((out.data as *mut int8) as intptr) + (2 as intptr)) as *mut uint8;
    memcpy(p2, (&b2) as *const uint8, 1 as uintptr);
    return out;
  }
  return yaml_empty_str();
}

func yaml_parse_i64(s: string) -> YamlI64Parse {
  var out: YamlI64Parse = YamlI64Parse{ value: 0 as int64, ok: false };
  let n: int32 = s.length;
  if n <= 0 {
    return out;
  }
  var i: int32 = 0;
  var neg: bool = false;
  if yaml_parse_byte(s, 0) == 45 {
    neg = true;
    i = 1;
    if n == 1 {
      return out;
    }
  }
  var mag: uint64 = 0u64;
  let ten: uint64 = 10u64;
  let lim_pos: uint64 = 9223372036854775807u64;
  let lim_neg: uint64 = 9223372036854775808u64;
  var lim: uint64 = lim_pos;
  if neg {
    lim = lim_neg;
  }
  var any: bool = false;
  while i < n {
    let b: int32 = yaml_parse_byte(s, i);
    if (b < 48) || (b > 57) {
      return out;
    }
    let d: uint64 = (b - 48) as uint64;
    if mag > (lim / ten) {
      return out;
    }
    mag = mag * ten;
    if mag > (lim - d) {
      return out;
    }
    mag = mag + d;
    any = true;
    i = i + 1;
  }
  if !any {
    return out;
  }
  out.ok = true;
  if neg {
    if mag == lim_neg {
      out.value = (0 as int64) - (9223372036854775807 as int64) - (1 as int64);
      return out;
    }
    out.value = (0 as int64) - (mag as int64);
    return out;
  }
  out.value = mag as int64;
  return out;
}

func yaml_str_hash(s: string) -> int32 {
  var h: int32 = 5381;
  var i: int32 = 0;
  let n: int32 = s.length;
  while i < n {
    let b: int32 = yaml_parse_byte(s, i);
    h = (h * 33) + b;
    i = i + 1;
  }
  return h;
}

func yaml_is_scalar_kind(k: int32) -> bool {
  if k == kYamlTokPlain {
    return true;
  }
  if k == kYamlTokStr {
    return true;
  }
  if k == kYamlTokInt {
    return true;
  }
  if k == kYamlTokBool {
    return true;
  }
  return k == kYamlTokNull;
}

func yaml_is_stop_kind(k: int32) -> bool {
  if k == kYamlTokStreamEnd {
    return true;
  }
  if k == kYamlTokDedent {
    return true;
  }
  if k == kYamlTokDash {
    return true;
  }
  if k == kYamlTokRBrace {
    return true;
  }
  if k == kYamlTokRBracket {
    return true;
  }
  return k == kYamlTokComma;
}

method(YamlScanResult) Tok(i: int32) -> YamlToken {
  if i < 0 {
    return YamlToken{ kind: kYamlTokStreamEnd, lexeme: yaml_empty_str(), line: 1, column: 1 };
  }
  if i >= self.Len() {
    return YamlToken{ kind: kYamlTokStreamEnd, lexeme: yaml_empty_str(), line: 1, column: 1 };
  }
  return self.Get(i);
}

method(YamlScanResult) Peek() -> YamlToken {
  return self.Tok(self.parse_i);
}

method(YamlScanResult) PeekKind() -> int32 {
  let i: int32 = self.parse_i;
  if i < 0 {
    return kYamlTokStreamEnd;
  }
  if i >= self.Len() {
    return kYamlTokStreamEnd;
  }
  return self.kinds.Get(i);
}

method(YamlScanResult) PeekNextKind() -> int32 {
  let i: int32 = self.parse_i + 1;
  if i < 0 {
    return kYamlTokStreamEnd;
  }
  if i >= self.Len() {
    return kYamlTokStreamEnd;
  }
  return self.kinds.Get(i);
}

method(YamlScanResult) FailAt(line: int32, column: int32, message: string) -> void {
  if self.parse_failed {
    return;
  }
  self.parse_failed = true;
  self.parse_err_line = line;
  self.parse_err_column = column;
  self.parse_err_message = yaml_copy_str(message);
}

method(YamlScanResult) FailHere(message: string) -> void {
  let i: int32 = self.parse_i;
  var ln: int32 = 1;
  var col: int32 = 1;
  if (i >= 0) && (i < self.Len()) {
    ln = self.lines.Get(i);
    col = self.columns.Get(i);
  }
  self.FailAt(ln, col, message);
}

method(YamlScanResult) Advance() -> YamlToken {
  let t: YamlToken = self.Peek();
  if t.kind != kYamlTokStreamEnd {
    if self.parse_i < self.Len() {
      self.parse_i = self.parse_i + 1;
    }
  }
  return t;
}

method(YamlScanResult) Skip() -> void {
  if self.PeekKind() != kYamlTokStreamEnd {
    if self.parse_i < self.Len() {
      self.parse_i = self.parse_i + 1;
    }
  }
}

method(YamlScanResult) Eat(kind: int32, message: string) -> void {
  if self.PeekKind() != kind {
    self.FailHere(message);
    return;
  }
  self.Skip();
}

method(YamlScanResult) QuoteKind(t: YamlToken) -> int32 {
  let idx: int32 = self.parse_i - 1;
  if idx < 0 {
    return 34;
  }
  let start: int32 = self.lex_starts.Get(idx);
  if start <= 0 {
    return 34;
  }
  let p: *const int8 = ((self.src_data as intptr) + ((start - 1) as intptr)) as *const int8;
  let ch: string = string.ViewFrom(p, 1);
  return yaml_parse_byte(ch, 0);
}

method(YamlScanResult) UnescapeDouble(inner: string, line: int32, column: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(inner.length);
  var i: int32 = 0;
  let n: int32 = inner.length;
  while i < n {
    let b: int32 = yaml_parse_byte(inner, i);
    if b != 92 {
      var nch: int32 = inner.Utf8LenAt(i);
      if nch < 1 {
        nch = 1;
      }
      buf.Append(inner.View(i, nch));
      i = i + nch;
      continue;
    }
    i = i + 1;
    if i >= n {
      self.FailAt(line, column, "invalid escape in double-quoted scalar");
      buf.Destroy();
      return yaml_empty_str();
    }
    let e: int32 = yaml_parse_byte(inner, i);
    i = i + 1;
    if e == 110 {
      buf.Append("\n");
      continue;
    }
    if e == 116 {
      buf.Append("\t");
      continue;
    }
    if e == 114 {
      buf.Append("\r");
      continue;
    }
    if e == 92 {
      buf.Append("\\");
      continue;
    }
    if e == 34 {
      buf.Append("\"");
      continue;
    }
    if e == 47 {
      buf.Append("/");
      continue;
    }
    if e == 32 {
      buf.Append(" ");
      continue;
    }
    if e == 48 {
      buf.Append(yaml_utf8_cp(0));
      continue;
    }
    if (e == 120) || (e == 117) || (e == 85) {
      var need: int32 = 2;
      if e == 117 {
        need = 4;
      }
      if e == 85 {
        need = 8;
      }
      var cp: int32 = 0;
      var h: int32 = 0;
      while h < need {
        if i >= n {
          self.FailAt(line, column, "invalid escape in double-quoted scalar");
          buf.Destroy();
          return yaml_empty_str();
        }
        let hv: int32 = yaml_hex_digit(yaml_parse_byte(inner, i));
        if hv < 0 {
          self.FailAt(line, column, "invalid escape in double-quoted scalar");
          buf.Destroy();
          return yaml_empty_str();
        }
        cp = (cp * 16) + hv;
        i = i + 1;
        h = h + 1;
      }
      buf.Append(yaml_utf8_cp(cp));
      continue;
    }
    self.FailAt(line, column, "invalid escape in double-quoted scalar");
    buf.Destroy();
    return yaml_empty_str();
  }
  if self.parse_failed {
    buf.Destroy();
    return yaml_empty_str();
  }
  return buf.Take();
}

method(YamlScanResult) UnescapeSingle(inner: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(inner.length);
  var i: int32 = 0;
  let n: int32 = inner.length;
  while i < n {
    let b: int32 = yaml_parse_byte(inner, i);
    if b == 39 {
      if (i + 1 < n) && (yaml_parse_byte(inner, i + 1) == 39) {
        buf.Append("'");
        i = i + 2;
        continue;
      }
    }
    var nch: int32 = inner.Utf8LenAt(i);
    if nch < 1 {
      nch = 1;
    }
    buf.Append(inner.View(i, nch));
    i = i + nch;
  }
  return buf.Take();
}

method(YamlScanResult) LexemeAt(i: int32) -> string {
  if i < 0 {
    return yaml_empty_str();
  }
  if i >= self.Len() {
    return yaml_empty_str();
  }
  let start: int32 = self.lex_starts.Get(i);
  let n: int32 = self.lex_lens.Get(i);
  if n <= 0 {
    return yaml_empty_str();
  }
  let p: *const int8 = ((self.src_data as intptr) + (start as intptr)) as *const int8;
  return string.ViewFrom(p, n);
}

method(YamlScanResult) QuoteByteAt(i: int32) -> int32 {
  if i < 0 {
    return 34;
  }
  let start: int32 = self.lex_starts.Get(i);
  if start <= 0 {
    return 34;
  }
  let p: *const int8 = ((self.src_data as intptr) + ((start - 1) as intptr)) as *const int8;
  let ch: string = string.ViewFrom(p, 1);
  return yaml_parse_byte(ch, 0);
}

method(YamlScanResult) ParseKeyString() -> string {
  let i: int32 = self.parse_i;
  if i < 0 {
    self.FailHere("expected a mapping key");
    return yaml_empty_str();
  }
  if i >= self.Len() {
    self.FailHere("expected a mapping key");
    return yaml_empty_str();
  }
  let kind: int32 = self.kinds.Get(i);
  if !yaml_is_scalar_kind(kind) {
    self.FailHere("expected a mapping key");
    return yaml_empty_str();
  }
  let ln: int32 = self.lines.Get(i);
  let col: int32 = self.columns.Get(i);
  let view: string = self.LexemeAt(i);
  self.parse_i = i + 1;
  if kind == kYamlTokStr {
    let q: int32 = self.QuoteByteAt(i);
    if q == 39 {
      return yaml_copy_str(self.UnescapeSingle(view));
    }
    return yaml_copy_str(self.UnescapeDouble(view, ln, col));
  }
  if view.length <= 0 {
    return yaml_empty_str();
  }
  var out: string = string.Alloc(view.length);
  memcpy((out.data as *mut uint8), view.data, view.length as uintptr);
  return out;
}

method(YamlScanResult) ParseScalar() -> Yaml {
  let i: int32 = self.parse_i;
  if i < 0 {
    self.FailHere("expected a scalar");
    return yaml_null_node();
  }
  if i >= self.Len() {
    self.FailHere("expected a scalar");
    return yaml_null_node();
  }
  let kind: int32 = self.kinds.Get(i);
  let ln: int32 = self.lines.Get(i);
  let col: int32 = self.columns.Get(i);
  let view: string = self.LexemeAt(i);
  self.parse_i = i + 1;
  if kind == kYamlTokNull {
    return yaml_null_node();
  }
  if kind == kYamlTokBool {
    var v: bool = false;
    if view.length > 0 {
      let b0: int32 = yaml_parse_byte(view, 0);
      if (b0 == 116) || (b0 == 84) {
        v = true;
      }
    }
    return yaml_bool_node(v);
  }
  if kind == kYamlTokInt {
    let p: YamlI64Parse = yaml_parse_i64(view);
    if !p.ok {
      self.FailAt(ln, col, "integer overflow");
      return yaml_null_node();
    }
    return yaml_int_node(p.value);
  }
  if kind == kYamlTokStr {
    let q: int32 = self.QuoteByteAt(i);
    if q == 39 {
      var need_u: bool = false;
      var ui: int32 = 0;
      while ui < view.length {
        if yaml_parse_byte(view, ui) == 39 {
          need_u = true;
          break;
        }
        ui = ui + 1;
      }
      if need_u {
        return yaml_str_node(self.UnescapeSingle(view));
      }
    } else {
      var need_d: bool = false;
      var di: int32 = 0;
      while di < view.length {
        if yaml_parse_byte(view, di) == 92 {
          need_d = true;
          break;
        }
        di = di + 1;
      }
      if need_d {
        return yaml_str_node(self.UnescapeDouble(view, ln, col));
      }
    }
    if view.length <= 0 {
      return yaml_str_node(yaml_empty_str());
    }
    var outs: string = string.Alloc(view.length);
    memcpy((outs.data as *mut uint8), view.data, view.length as uintptr);
    return yaml_str_node(outs);
  }
  if kind == kYamlTokPlain {
    if view.length <= 0 {
      return yaml_str_node(yaml_empty_str());
    }
    var out: string = string.Alloc(view.length);
    memcpy((out.data as *mut uint8), view.data, view.length as uintptr);
    return yaml_str_node(out);
  }
  self.FailHere("expected a scalar");
  return yaml_null_node();
}

method(YamlScanResult) ParseFlowMap() -> void {
  self.Eat(kYamlTokLBrace, "expected '{'");
  var mapv: YamlMap = YamlMap{ entries: Array<YamlMapEntry>{} };
  var hashes: Array<int32> = Array<int32>{};
  if self.PeekKind() == kYamlTokRBrace {
    self.Skip();
    self.parse_map = mapv;
    return;
  }
  while !self.parse_failed {
    if self.PeekKind() == kYamlTokRBrace {
      break;
    }
    let kline: int32 = self.lines.Get(self.parse_i);
    let kcol: int32 = self.columns.Get(self.parse_i);
    let key: string = self.ParseKeyString();
    if self.parse_failed {
      break;
    }
    if (key == "<<") {
      self.FailAt(kline, kcol, "merge keys are not supported in v1");
      break;
    }
    self.Eat(kYamlTokColon, "expected ':' after mapping key");
    if self.parse_failed {
      break;
    }
    let val: Yaml = self.ParseFlowNode();
    if self.parse_failed {
      break;
    }
    var hd: int32 = 0;
    let hn: int32 = hashes.Len();
    var isdupf: bool = false;
    let kh: int32 = yaml_str_hash(key);
    while hd < hn {
      if hashes.Get(hd) == kh {
        self.FailAt(kline, kcol, "duplicate mapping key");
        isdupf = true;
        break;
      }
      hd = hd + 1;
    }
    if isdupf {
      break;
    }
    hashes.Push(kh);
    mapv.entries.Push(YamlMapEntry{ key: key, value: val });
    if self.PeekKind() == kYamlTokComma {
      self.Skip();
      if self.PeekKind() == kYamlTokRBrace {
        break;
      }
      continue;
    }
    break;
  }
  self.Eat(kYamlTokRBrace, "expected '}'");
  if !self.parse_failed {
    self.parse_map = mapv;
  }
}

method(YamlScanResult) ParseFlowSeq() -> void {
  self.Eat(kYamlTokLBracket, "expected '['");
  var seqv: YamlSeq = YamlSeq{ items: Array<Yaml>{} };
  if self.PeekKind() == kYamlTokRBracket {
    self.Skip();
    self.parse_seq = seqv;
    return;
  }
  while !self.parse_failed {
    if self.PeekKind() == kYamlTokRBracket {
      break;
    }
    let v: Yaml = self.ParseFlowNode();
    if self.parse_failed {
      break;
    }
    seqv.items.Push(v);
    if self.PeekKind() == kYamlTokComma {
      self.Skip();
      if self.PeekKind() == kYamlTokRBracket {
        break;
      }
      continue;
    }
    break;
  }
  self.Eat(kYamlTokRBracket, "expected ']'");
  self.parse_seq = seqv;
}

method(YamlScanResult) ParseFlowNode() -> Yaml {
  let k: int32 = self.PeekKind();
  if k == kYamlTokLBrace {
    self.ParseFlowMap();
    return self.TakeMap();
  }
  if k == kYamlTokLBracket {
    self.ParseFlowSeq();
    return self.TakeSeq();
  }
  if yaml_is_scalar_kind(k) {
    return self.ParseScalar();
  }
  self.FailHere("expected a flow node");
  return yaml_null_node();
}

method(YamlScanResult) ParseMapValue() -> Yaml {
  let k: int32 = self.PeekKind();
  if k == kYamlTokIndent {
    self.Skip();
    let v: Yaml = self.ParseNode();
    self.Eat(kYamlTokDedent, "expected dedent after indented value");
    return v;
  }
  if k == kYamlTokDash {
    self.ParseBlockSeq();
    return self.TakeSeq();
  }
  if k == kYamlTokLBrace {
    self.ParseFlowMap();
    return self.TakeMap();
  }
  if k == kYamlTokLBracket {
    self.ParseFlowSeq();
    return self.TakeSeq();
  }
  if yaml_is_scalar_kind(k) {
    if self.PeekNextKind() == kYamlTokColon {
      return yaml_null_node();
    }
    return self.ParseScalar();
  }
  if yaml_is_stop_kind(k) {
    return yaml_null_node();
  }
  self.FailHere("expected a mapping value");
  return yaml_null_node();
}

method(YamlScanResult) ParseBlockMap() -> void {
  // A compact sequence-item map ends before the next parent mapping key.
  let base_column: int32 = self.columns.Get(self.parse_i);
  var mapv: YamlMap = YamlMap{ entries: Array<YamlMapEntry>{} };
  var hashes: Array<int32> = Array<int32>{};
  while !self.parse_failed {
    let k: int32 = self.PeekKind();
    if yaml_is_stop_kind(k) {
      break;
    }
    if yaml_is_scalar_kind(k) && self.columns.Get(self.parse_i) < base_column {
      break;
    }
    if k == kYamlTokIndent {
      self.Skip();
      while !self.parse_failed {
        if self.PeekKind() == kYamlTokDedent {
          self.Skip();
          break;
        }
        if yaml_is_stop_kind(self.PeekKind()) {
          self.FailHere("expected dedent after nested mapping keys");
          break;
        }
        let kline: int32 = self.lines.Get(self.parse_i);
        let kcol: int32 = self.columns.Get(self.parse_i);
        let key: string = self.ParseKeyString();
        if self.parse_failed {
          break;
        }
        if (key == "<<") {
          self.FailAt(kline, kcol, "merge keys are not supported in v1");
          break;
        }
        self.Eat(kYamlTokColon, "expected ':' after mapping key");
        if self.parse_failed {
          break;
        }
        let val: Yaml = self.ParseMapValue();
        if self.parse_failed {
          break;
        }
        var hd: int32 = 0;
        let hn: int32 = hashes.Len();
        var isdup: bool = false;
        let kh: int32 = yaml_str_hash(key);
        while hd < hn {
          if hashes.Get(hd) == kh {
            self.FailAt(kline, kcol, "duplicate mapping key");
            isdup = true;
            break;
          }
          hd = hd + 1;
        }
        if isdup {
          break;
        }
        hashes.Push(kh);
        mapv.entries.Push(YamlMapEntry{ key: key, value: val });
      }
      continue;
    }
    if !yaml_is_scalar_kind(k) {
      break;
    }
    let kline2: int32 = self.lines.Get(self.parse_i);
    let kcol2: int32 = self.columns.Get(self.parse_i);
    let key2: string = self.ParseKeyString();
    if self.parse_failed {
      break;
    }
    if (key2 == "<<") {
      self.FailAt(kline2, kcol2, "merge keys are not supported in v1");
      break;
    }
    self.Eat(kYamlTokColon, "expected ':' after mapping key");
    if self.parse_failed {
      break;
    }
    let val2: Yaml = self.ParseMapValue();
    if self.parse_failed {
      break;
    }
    var hd2: int32 = 0;
    let hn2: int32 = hashes.Len();
    var isdup2: bool = false;
    let kh2: int32 = yaml_str_hash(key2);
    while hd2 < hn2 {
      if hashes.Get(hd2) == kh2 {
        self.FailAt(kline2, kcol2, "duplicate mapping key");
        isdup2 = true;
        break;
      }
      hd2 = hd2 + 1;
    }
    if isdup2 {
      break;
    }
    hashes.Push(kh2);
    mapv.entries.Push(YamlMapEntry{ key: key2, value: val2 });
    if self.PeekKind() == kYamlTokIndent {
      self.Skip();
      while !self.parse_failed {
        if self.PeekKind() == kYamlTokDedent {
          self.Skip();
          break;
        }
        if yaml_is_stop_kind(self.PeekKind()) {
          self.FailHere("expected dedent after continued mapping keys");
          break;
        }
        let kline3: int32 = self.lines.Get(self.parse_i);
        let kcol3: int32 = self.columns.Get(self.parse_i);
        let key3: string = self.ParseKeyString();
        if self.parse_failed {
          break;
        }
        if (key3 == "<<") {
          self.FailAt(kline3, kcol3, "merge keys are not supported in v1");
          break;
        }
        self.Eat(kYamlTokColon, "expected ':' after mapping key");
        if self.parse_failed {
          break;
        }
        let val3: Yaml = self.ParseMapValue();
        if self.parse_failed {
          break;
        }
        var hd3: int32 = 0;
        let hn3: int32 = hashes.Len();
        var isdup3: bool = false;
        let kh3: int32 = yaml_str_hash(key3);
        while hd3 < hn3 {
          if hashes.Get(hd3) == kh3 {
            self.FailAt(kline3, kcol3, "duplicate mapping key");
            isdup3 = true;
            break;
          }
          hd3 = hd3 + 1;
        }
        if isdup3 {
          break;
        }
        hashes.Push(kh3);
        mapv.entries.Push(YamlMapEntry{ key: key3, value: val3 });
      }
    }
  }
  self.parse_map = mapv;
}

method(YamlScanResult) ParseSeqItem() -> Yaml {
  if self.PeekKind() == kYamlTokIndent {
    self.Skip();
    let v: Yaml = self.ParseNode();
    self.Eat(kYamlTokDedent, "expected dedent after indented sequence item");
    return v;
  }
  if self.PeekKind() == kYamlTokDash {
    self.ParseBlockSeq();
    return self.TakeSeq();
  }
  return self.ParseNode();
}

method(YamlScanResult) ParseBlockSeq() -> void {
  var seqv: YamlSeq = YamlSeq{ items: Array<Yaml>{} };
  while !self.parse_failed {
    if self.PeekKind() != kYamlTokDash {
      break;
    }
    self.Skip();
    let item: Yaml = self.ParseSeqItem();
    if self.parse_failed {
      break;
    }
    seqv.items.Push(item);
  }
  self.parse_seq = seqv;
}

pub method(YamlScanResult) ParseNode() -> Yaml {
  let k: int32 = self.PeekKind();
  if k == kYamlTokIndent {
    self.Skip();
    let v: Yaml = self.ParseNode();
    self.Eat(kYamlTokDedent, "expected dedent");
    return v;
  }
  if k == kYamlTokLBrace {
    self.ParseFlowMap();
    return self.TakeMap();
  }
  if k == kYamlTokLBracket {
    self.ParseFlowSeq();
    return self.TakeSeq();
  }
  if k == kYamlTokDash {
    self.ParseBlockSeq();
    return self.TakeSeq();
  }
  if yaml_is_scalar_kind(k) {
    if self.PeekNextKind() == kYamlTokColon {
      self.ParseBlockMap();
      return self.TakeMap();
    }
    return self.ParseScalar();
  }
  if yaml_is_stop_kind(k) {
    return yaml_null_node();
  }
  self.FailHere("unexpected token");
  return yaml_null_node();
}

method(YamlScanResult) TakeMap() -> Yaml {
  // Move the map arm out of the scan result (owned Array fat is single-owner).
  return Yaml{ node: self.parse_map };
}

method(YamlScanResult) TakeSeq() -> Yaml {
  return Yaml{ node: self.parse_seq };
}

pub method(YamlScanResult) FinishTrail() -> void {
  while self.PeekKind() == kYamlTokDedent {
    self.Skip();
  }
  if self.PeekKind() != kYamlTokStreamEnd {
    self.FailHere("unexpected content after document");
  }
}

pub method(YamlScanResult) FillDocument() -> void {
  self.parse_arm = 0;
  if self.PeekKind() == kYamlTokStreamEnd {
    return;
  }
  let k: int32 = self.PeekKind();
  if k == kYamlTokLBrace {
    self.ParseFlowMap();
    if self.parse_failed {
      return;
    }
    self.parse_arm = 5;
    self.FinishTrail();
    return;
  }
  if k == kYamlTokLBracket {
    self.ParseFlowSeq();
    if self.parse_failed {
      return;
    }
    self.parse_arm = 4;
    self.FinishTrail();
    return;
  }
  if k == kYamlTokDash {
    self.ParseBlockSeq();
    if self.parse_failed {
      return;
    }
    self.parse_arm = 4;
    self.FinishTrail();
    return;
  }
  if yaml_is_scalar_kind(k) {
    if self.PeekNextKind() == kYamlTokColon {
      self.ParseBlockMap();
      if self.parse_failed {
        return;
      }
      self.parse_arm = 5;
      self.FinishTrail();
      return;
    }
  }
  self.parse_arm = 1;
}

/**
 * @brief Private parse-error probe for package selftests (not a product entrypoint).
 */
pub struct YamlParseErr {
  failed: bool;
  line: int32;
  column: int32;
  message: string;
}

func yaml_parse_fail_result(line: int32, column: int32, message: string) -> Result<Yaml, YamlError> {
  var msg: string = message;
  if message.length > 0 {
    var out: string = string.Alloc(message.length);
    memcpy((out.data as *mut uint8), message.data, message.length as uintptr);
    msg = out;
  }
  let err: YamlError = YamlError{ line: line, column: column, message: msg };
  return Err<Yaml, YamlError>(err);
}

/**
 * @brief Internal v1 parse → `Yaml` tree (Reader feed; not a product free `Parse`).
 */
func yaml_parse_result(text: string) -> Result<Yaml, YamlError> {
  var scan: YamlScanResult = MakeEmptyScanResult();
  scan.Tokenize(text);
  if !scan.ok {
    let se: YamlError = scan.error;
    return yaml_parse_fail_result(se.line, se.column, se.message);
  }
  scan.FillDocument();
  if scan.parse_failed {
    return yaml_parse_fail_result(scan.parse_err_line, scan.parse_err_column, scan.parse_err_message);
  }
  if scan.parse_arm == 5 {
    return Ok<Yaml, YamlError>(Yaml{ node: scan.parse_map });
  }
  if scan.parse_arm == 4 {
    return Ok<Yaml, YamlError>(Yaml{ node: scan.parse_seq });
  }
  if scan.parse_arm == 0 {
    return Ok<Yaml, YamlError>(yaml_null_node());
  }
  let n: Yaml = scan.ParseNode();
  scan.FinishTrail();
  if scan.parse_failed {
    return yaml_parse_fail_result(scan.parse_err_line, scan.parse_err_column, scan.parse_err_message);
  }
  return Ok<Yaml, YamlError>(n);
}

/**
 * @brief Test helper: parse or `YamlNull` on failure (private; not product API).
 */
pub func YamlParseTree(text: string) -> Yaml {
  let r: Result<Yaml, YamlError> = yaml_parse_result(text);
  if r.IsErr() {
    return yaml_null_node();
  }
  let root: Yaml? = r.get_if<Yaml>();
  if root == nil {
    return yaml_null_node();
  }
  return root as Yaml;
}

pub func YamlParseErrOf(text: string) -> YamlParseErr {
  var out: YamlParseErr = YamlParseErr{
    failed: false,
    line: 1,
    column: 1,
    message: yaml_empty_str()
  };
  var scan: YamlScanResult = MakeEmptyScanResult();
  scan.Tokenize(text);
  if !scan.ok {
    out.failed = true;
    let se: YamlError = scan.error;
    out.line = se.line;
    out.column = se.column;
    out.message = yaml_copy_str(se.message);
    return out;
  }
  scan.FillDocument();
  if scan.parse_failed {
    out.failed = true;
    out.line = scan.parse_err_line;
    out.column = scan.parse_err_column;
    out.message = yaml_copy_str(scan.parse_err_message);
  }
  return out;
}
