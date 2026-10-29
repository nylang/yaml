// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module YamlDocumentParser;
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";
import "private/lexical.ny";
import "private/scan.ny";

/**
 * @brief v1 recursive-descent tree parse for package `yaml` (internal).
 * @note Product face is `YamlDocument` / `YamlReader` (yaml.md §0.4). Free `Parse` deleted at
 *   m_v0.18_p3.
 * @note Writer/Emit live in `private/writer.ny` + `private/emit.ny`.
 * @see docs/design/compiler/yaml.md §1.3–1.4
 */

/** @brief Private document parser cursor over a completed borrowed token result. */
struct YamlParser {
  tokens: YamlScanResult;
  parse_i: int32;
  parse_failed: bool;
  parse_err_line: int32;
  parse_err_column: int32;
  parse_err_message: string;
  entry_key: string;
  entry_line: int32;
  entry_column: int32;
  entry_ok: bool;
  parse_arm: int32;
  parse_map: YamlMap;
  parse_seq: YamlSeq;
}

func yaml_parser_new(tokens: YamlScanResult) -> YamlParser {
  return YamlParser{
    tokens: move(tokens),
    parse_i: 0,
    parse_failed: false,
    parse_err_line: 1,
    parse_err_column: 1,
    parse_err_message: YamlEmptyStr(),
    entry_key: YamlEmptyStr(),
    entry_line: 1,
    entry_column: 1,
    entry_ok: false,
    parse_arm: 0,
    parse_map: YamlMap{entries: Array<YamlMapEntry>{}},
    parse_seq: YamlSeq{items: Array<Yaml>{}}
  };
}

struct YamlI64Parse {
  value: int64;
  ok: bool;
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

// Bound magnitude accumulation before arithmetic so malformed or overflowing scalars cannot wrap into valid integers.
func yaml_parse_i64(s: string) -> YamlI64Parse {
  var out: YamlI64Parse = YamlI64Parse{value: 0 as int64, ok: false};
  let n: int32 = s.length;
  if n <= 0 {
    return out;
  }

  var i: int32 = 0;
  var neg: bool = false;
  if YamlParseByte(s, 0) == 45 {
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
    let b: int32 = YamlParseByte(s, i);
    if (b < 48) || (b > 57) {
      return out;
    }

    let d: uint64 = (b - 48) as uint64;
    if mag >(lim / ten) {
      return out;
    }

    mag = mag * ten;
    if mag >(lim - d) {
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
    let b: int32 = YamlParseByte(s, i);
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

method(YamlParser) Tok(i: int32) -> YamlToken {
  if i < 0 {
    return YamlToken{kind: kYamlTokStreamEnd, lexeme: YamlEmptyStr(), line: 1, column: 1};
  }

  if i >= self.tokens.Len() {
    return YamlToken{kind: kYamlTokStreamEnd, lexeme: YamlEmptyStr(), line: 1, column: 1};
  }

  return self.tokens.Get(i);
}

method(YamlParser) Peek() -> YamlToken {
  return self.Tok(self.parse_i);
}

method(YamlParser) PeekKind() -> int32 {
  let i: int32 = self.parse_i;
  if i < 0 {
    return kYamlTokStreamEnd;
  }

  if i >= self.tokens.Len() {
    return kYamlTokStreamEnd;
  }

  return self.tokens.Get(i).kind;
}

method(YamlParser) PeekNextKind() -> int32 {
  let i: int32 = self.parse_i + 1;
  if i < 0 {
    return kYamlTokStreamEnd;
  }

  if i >= self.tokens.Len() {
    return kYamlTokStreamEnd;
  }

  return self.tokens.Get(i).kind;
}

method(YamlParser) FailAt(line: int32, column: int32, message: string) -> void {
  if self.parse_failed {
    return;
  }

  self.parse_failed = true;
  self.parse_err_line = line;
  self.parse_err_column = column;
  self.parse_err_message = YamlCopyStr(message);
}

method(YamlParser) FailHere(message: string) -> void {
  let i: int32 = self.parse_i;
  var ln: int32 = 1;
  var col: int32 = 1;
  if (i >= 0) && (i < self.tokens.Len()) {
    ln = self.tokens.Get(i).line;
    col = self.tokens.Get(i).column;
  }

  self.FailAt(ln, col, message);
}

method(YamlParser) Advance() -> YamlToken {
  let t: YamlToken = self.Peek();
  if t.kind != kYamlTokStreamEnd {
    if self.parse_i < self.tokens.Len() {
      self.parse_i = self.parse_i + 1;
    }
  }

  return t;
}

method(YamlParser) Skip() -> void {
  if self.PeekKind() != kYamlTokStreamEnd {
    if self.parse_i < self.tokens.Len() {
      self.parse_i = self.parse_i + 1;
    }
  }
}

method(YamlParser) Eat(kind: int32, message: string) -> void {
  if self.PeekKind() != kind {
    self.FailHere(message);
    return;
  }

  self.Skip();
}

method(YamlParser) QuoteKind(t: YamlToken) -> int32 {
  return self.tokens.QuoteAt(self.parse_i - 1);
}

method(YamlParser) UnescapeDouble(inner: string, line: int32, column: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(inner.length);
  var i: int32 = 0;
  let n: int32 = inner.length;
  while i < n {
    let b: int32 = YamlParseByte(inner, i);
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

      return YamlEmptyStr();
    }

    let e: int32 = YamlParseByte(inner, i);
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
      buf.Append(YamlUtf8Cp(0));
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

          return YamlEmptyStr();
        }

        let hv: int32 = yaml_hex_digit(YamlParseByte(inner, i));
        if hv < 0 {
          self.FailAt(line, column, "invalid escape in double-quoted scalar");
          buf.Destroy();

          return YamlEmptyStr();
        }

        cp = (cp * 16) + hv;
        i = i + 1;
        h = h + 1;
      }

      buf.Append(YamlUtf8Cp(cp));
      continue;
    }

    self.FailAt(line, column, "invalid escape in double-quoted scalar");
    buf.Destroy();

    return YamlEmptyStr();
  }

  if self.parse_failed {
    buf.Destroy();

    return YamlEmptyStr();
  }

  return buf.Take();
}

method(YamlParser) UnescapeSingle(inner: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(inner.length);
  var i: int32 = 0;
  let n: int32 = inner.length;
  while i < n {
    let b: int32 = YamlParseByte(inner, i);
    if b == 39 {
      if (i + 1 < n) && (YamlParseByte(inner, i + 1) == 39) {
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

method(YamlParser) LexemeAt(i: int32) -> string {
  if i < 0 || i >= self.tokens.Len() {
    return YamlEmptyStr();
  }

  return self.tokens.Get(i).lexeme;
}

method(YamlParser) QuoteByteAt(i: int32) -> int32 {
  return self.tokens.QuoteAt(i);
}

method(YamlParser) ParseKeyString() -> string {
  let i: int32 = self.parse_i;
  if i < 0 {
    self.FailHere("expected a mapping key");

    return YamlEmptyStr();
  }

  if i >= self.tokens.Len() {
    self.FailHere("expected a mapping key");

    return YamlEmptyStr();
  }

  let kind: int32 = self.tokens.Get(i).kind;
  if !yaml_is_scalar_kind(kind) {
    self.FailHere("expected a mapping key");

    return YamlEmptyStr();
  }

  let ln: int32 = self.tokens.Get(i).line;
  let col: int32 = self.tokens.Get(i).column;
  let view: string = self.LexemeAt(i);
  self.parse_i = i + 1;
  if kind == kYamlTokStr {
    let q: int32 = self.QuoteByteAt(i);
    if q == 39 {
      return YamlCopyStr(self.UnescapeSingle(view));
    }

    return YamlCopyStr(self.UnescapeDouble(view, ln, col));
  }

  if view.length <= 0 {
    return YamlEmptyStr();
  }

  var out: string = string.Alloc(view.length);
  memcpy((out.data as *mut uint8), view.data, view.length as uintptr);

  return out;
}

method(YamlParser) ParseScalar() -> Yaml {
  let i: int32 = self.parse_i;
  if i < 0 {
    self.FailHere("expected a scalar");

    return YamlNullNode();
  }

  if i >= self.tokens.Len() {
    self.FailHere("expected a scalar");

    return YamlNullNode();
  }

  let kind: int32 = self.tokens.Get(i).kind;
  let ln: int32 = self.tokens.Get(i).line;
  let col: int32 = self.tokens.Get(i).column;
  let view: string = self.LexemeAt(i);
  self.parse_i = i + 1;
  if kind == kYamlTokNull {
    return YamlNullNode();
  }

  if kind == kYamlTokBool {
    var v: bool = false;
    if view.length > 0 {
      let b0: int32 = YamlParseByte(view, 0);
      if (b0 == 116) || (b0 == 84) {
        v = true;
      }
    }

    return YamlBoolNode(v);
  }

  if kind == kYamlTokInt {
    let p: YamlI64Parse = yaml_parse_i64(view);
    if !p.ok {
      self.FailAt(ln, col, "integer overflow");

      return YamlNullNode();
    }

    return YamlIntNode(p.value);
  }

  if kind == kYamlTokStr {
    let q: int32 = self.QuoteByteAt(i);
    if q == 39 {
      var need_u: bool = false;
      var ui: int32 = 0;
      while ui < view.length {
        if YamlParseByte(view, ui) == 39 {
          need_u = true;
          break;
        }

        ui = ui + 1;
      }

      if need_u {
        return YamlStrNode(self.UnescapeSingle(view));
      }
    } else {
      var need_d: bool = false;
      var di: int32 = 0;
      while di < view.length {
        if YamlParseByte(view, di) == 92 {
          need_d = true;
          break;
        }

        di = di + 1;
      }

      if need_d {
        return YamlStrNode(self.UnescapeDouble(view, ln, col));
      }
    }

    if view.length <= 0 {
      return YamlStrNode(YamlEmptyStr());
    }

    var outs: string = string.Alloc(view.length);
    memcpy((outs.data as *mut uint8), view.data, view.length as uintptr);

    return YamlStrNode(outs);
  }

  if kind == kYamlTokPlain {
    if view.length <= 0 {
      return YamlStrNode(YamlEmptyStr());
    }

    var out: string = string.Alloc(view.length);
    memcpy((out.data as *mut uint8), view.data, view.length as uintptr);

    return YamlStrNode(out);
  }

  self.FailHere("expected a scalar");

  return YamlNullNode();
}

method(YamlParser) ParseFlowMap() -> void {
  self.Eat(kYamlTokLBrace, "expected '{'");
  var mapv: YamlMap = YamlMap{entries: Array<YamlMapEntry>{}};
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

    let kline: int32 = self.tokens.Get(self.parse_i).line;
    let kcol: int32 = self.tokens.Get(self.parse_i).column;
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
    mapv.entries.Push(YamlMapEntry{key: key, value: val});
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

method(YamlParser) ParseFlowSeq() -> void {
  self.Eat(kYamlTokLBracket, "expected '['");
  var seqv: YamlSeq = YamlSeq{items: Array<Yaml>{}};
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

method(YamlParser) ParseFlowNode() -> Yaml {
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

  return YamlNullNode();
}

method(YamlParser) ParseMapValue() -> Yaml {
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
      return YamlNullNode();
    }

    return self.ParseScalar();
  }

  if yaml_is_stop_kind(k) {
    return YamlNullNode();
  }

  self.FailHere("expected a mapping value");

  return YamlNullNode();
}

method(YamlParser) ParseBlockMap() -> void {
  // A compact sequence-item map ends before the next parent mapping key.
  let base_column: int32 = self.tokens.Get(self.parse_i).column;
  var mapv: YamlMap = YamlMap{entries: Array<YamlMapEntry>{}};
  var hashes: Array<int32> = Array<int32>{};
  while !self.parse_failed {
    let k: int32 = self.PeekKind();
    if yaml_is_stop_kind(k) {
      break;
    }

    if yaml_is_scalar_kind(k) && self.tokens.Get(self.parse_i).column < base_column {
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

        let kline: int32 = self.tokens.Get(self.parse_i).line;
        let kcol: int32 = self.tokens.Get(self.parse_i).column;
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
        mapv.entries.Push(YamlMapEntry{key: key, value: val});
      }

      continue;
    }

    if !yaml_is_scalar_kind(k) {
      break;
    }

    let kline2: int32 = self.tokens.Get(self.parse_i).line;
    let kcol2: int32 = self.tokens.Get(self.parse_i).column;
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
    mapv.entries.Push(YamlMapEntry{key: key2, value: val2});
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

        let kline3: int32 = self.tokens.Get(self.parse_i).line;
        let kcol3: int32 = self.tokens.Get(self.parse_i).column;
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
        mapv.entries.Push(YamlMapEntry{key: key3, value: val3});
      }
    }
  }

  self.parse_map = mapv;
}

method(YamlParser) ParseSeqItem() -> Yaml {
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

method(YamlParser) ParseBlockSeq() -> void {
  var seqv: YamlSeq = YamlSeq{items: Array<Yaml>{}};
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

method(YamlParser) ParseNode() -> Yaml {
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
    return YamlNullNode();
  }

  self.FailHere("unexpected token");

  return YamlNullNode();
}

method(YamlParser) TakeMap() -> Yaml {
  // Move the map arm out of the scan result (owned Array fat is single-owner).
  return Yaml{node: self.parse_map};
}

method(YamlParser) TakeSeq() -> Yaml {
  return Yaml{node: self.parse_seq};
}

method(YamlParser) FinishTrail() -> void {
  while self.PeekKind() == kYamlTokDedent {
    self.Skip();
  }

  if self.PeekKind() != kYamlTokStreamEnd {
    self.FailHere("unexpected content after document");
  }
}

method(YamlParser) FillDocument() -> void {
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

  let err: YamlError = YamlError{line: line, column: column, message: msg};

  return Err<Yaml, YamlError>(err);
}

/**
 * @brief Internal v1 parse → `Yaml` tree (Reader feed; not a product free `Parse`).
 */
pub func YamlParseResult(text: string) -> Result<Yaml, YamlError> {
  var tokens: YamlScanResult = MakeEmptyScanResult();
  tokens.Tokenize(text);
  if !tokens.IsOk() {
    let se: YamlError = tokens.Error();

    return yaml_parse_fail_result(se.line, se.column, se.message);
  }

  var scan: YamlParser = yaml_parser_new(move(tokens));
  scan.FillDocument();
  if scan.parse_failed {
    return yaml_parse_fail_result(scan.parse_err_line, scan.parse_err_column, scan.parse_err_message);
  }

  if scan.parse_arm == 5 {
    return Ok<Yaml, YamlError>(Yaml{node: scan.parse_map});
  }

  if scan.parse_arm == 4 {
    return Ok<Yaml, YamlError>(Yaml{node: scan.parse_seq});
  }

  if scan.parse_arm == 0 {
    return Ok<Yaml, YamlError>(YamlNullNode());
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
  let r: Result<Yaml, YamlError> = YamlParseResult(text);
  if r.IsErr() {
    return YamlNullNode();
  }

  let root: Yaml? = r.get_if<Yaml>();
  if root == nil {
    return YamlNullNode();
  }

  return root as Yaml;
}

/**
 * @brief Inspect syntax failures without exposing the mutable parse cursor.
 * @returns A copied diagnostic summary; failed is false when parsing succeeds.
 */
pub func YamlParseErrOf(text: string) -> YamlParseErr {
  var out: YamlParseErr = YamlParseErr{failed: false, line: 1, column: 1, message: YamlEmptyStr()};
  var tokens: YamlScanResult = MakeEmptyScanResult();
  tokens.Tokenize(text);
  if !tokens.IsOk() {
    out.failed = true;
    let se: YamlError = tokens.Error();
    out.line = se.line;
    out.column = se.column;
    out.message = YamlCopyStr(se.message);

    return out;
  }

  var scan: YamlParser = yaml_parser_new(move(tokens));
  scan.FillDocument();
  if scan.parse_failed {
    out.failed = true;
    out.line = scan.parse_err_line;
    out.column = scan.parse_err_column;
    out.message = YamlCopyStr(scan.parse_err_message);
  }

  return out;
}
