// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module YamlScanner;
part "../tests/scan_selftest.ny";
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";
import "private/lexical.ny";
import "ntest:ntest.ny";

/**
 * @brief Internal token kinds (int32; enum sizeof is not usable in Array<T>).
 * @note Comment is skipped and has no kind. Values are documented in m_v0.7_p1 Record.
 */

/**
 * @brief One scanner token. `line` / `column` are 1-based (token start).
 */
pub struct YamlToken {
  kind: int32;
  lexeme: string;
  line: int32;
  column: int32;
}

struct YamlScanner {
  text_data: *const int8;
  text_len: int32;
  pos: int32;
  line: int32;
  column: int32;
  line_start: bool;
  content_bol: bool;
  flow_depth: int32;
  failed: bool;
  err_line: int32;
  err_column: int32;
  err_message: string;
  kinds: Array<int32>;
  lines: Array<int32>;
  columns: Array<int32>;
  lex_starts: Array<int32>;
  lex_lens: Array<int32>;
  indents: Array<int32>;
}

method(YamlScanner) Src() -> string {
  return string.ViewFrom(self.text_data, self.text_len);
}

func yaml_is_break(b: int32) -> bool {
  if b == 10 {
    return true;
  }

  return b == 13;
}

func yaml_is_space(b: int32) -> bool {
  return b == 32;
}

func yaml_is_blank(b: int32) -> bool {
  if yaml_is_space(b) {
    return true;
  }

  return b == 9;
}

func yaml_is_hex(b: int32) -> bool {
  if YamlIsDigit(b) {
    return true;
  }

  if (b >= 65) && (b <= 70) {
    return true;
  }

  if (b >= 97) && (b <= 102) {
    return true;
  }

  return false;
}

func yaml_hex_val(b: int32) -> int32 {
  if YamlIsDigit(b) {
    return b - 48;
  }

  if (b >= 65) && (b <= 70) {
    return b - 55;
  }

  if (b >= 97) && (b <= 102) {
    return b - 87;
  }

  return 0;
}

func yaml_empty_view() -> string {
  return "";
}

func yaml_byte_string(b: uint8) -> string {
  var out: string = string.Alloc(1);
  var src: uint8 = b;
  memcpy((out.data as *mut uint8),(&src) as *const uint8, 1 as uintptr);

  return out;
}

func yaml_codepoint_utf8(cp: int32) -> string {
  if cp <= 0 {
    return yaml_empty_view();
  }

  if cp < 128 {
    return yaml_byte_string(cp as uint8);
  }

  if cp <= 2047 {
    var out: string = string.Alloc(2);
    var b0: uint8 = (192 + (cp / 64)) as uint8;
    var b1: uint8 = (128 + (cp - (cp / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8),(&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1,(&b1) as *const uint8, 1 as uintptr);

    return out;
  }

  if cp <= 65535 {
    var out: string = string.Alloc(3);
    var b0: uint8 = (224 + (cp / 4096)) as uint8;
    let r1: int32 = cp - (cp / 4096) * 4096;
    var b1: uint8 = (128 + (r1 / 64)) as uint8;
    var b2: uint8 = (128 + (r1 - (r1 / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8),(&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1,(&b1) as *const uint8, 1 as uintptr);
    let p2: *mut uint8 = (((out.data as *mut int8) as intptr) + (2 as intptr)) as *mut uint8;
    memcpy(p2,(&b2) as *const uint8, 1 as uintptr);

    return out;
  }

  return yaml_empty_view();
}

func yaml_is_flow_indicator(b: int32) -> bool {
  if b == 44 {
    return true;
  }

  if b == 91 {
    return true;
  }

  if b == 93 {
    return true;
  }

  if b == 123 {
    return true;
  }

  return b == 125;
}

func yaml_is_colon_break(text: string, pos: int32) -> bool {
  let n: int32 = YamlByteAt(text, pos + 1);
  if n < 0 {
    return true;
  }

  if yaml_is_break(n) {
    return true;
  }

  if yaml_is_blank(n) {
    return true;
  }

  if n == 35 {
    return true;
  }

  return yaml_is_flow_indicator(n);
}

// Classify plain scalars before publication; quoted strings bypass implicit scalar interpretation.

/**
 * @brief Scanner outcome. Not `Result<Array<…>, E>`: that variant arm hits compiler sizeof on
 *   `owned <T>[]?`.
 */
pub struct YamlScanResult {
  ok: bool;
  src_data: *const int8;
  src_len: int32;
  kinds: Array<int32>;
  lines: Array<int32>;
  columns: Array<int32>;
  lex_starts: Array<int32>;
  lex_lens: Array<int32>;
  error: YamlError;
}

func yaml_empty_i32() -> Array<int32> {
  return Array<int32>{};
}

func yaml_empty_indents() -> Array<int32> {
  return Array<int32>{};
}

/**
 * @brief Initialize an empty token result without parser or document state.
 * @returns A valid empty token result borrowing no source payload.
 */
pub func MakeEmptyScanResult() -> YamlScanResult {
  return YamlScanResult{
    ok: true,
    src_data: 0 as *const int8,
    src_len: 0,
    kinds: yaml_empty_i32(),
    lines: yaml_empty_i32(),
    columns: yaml_empty_i32(),
    lex_starts: yaml_empty_i32(),
    lex_lens: yaml_empty_i32(),
    error: YamlError{line: 0, column: 0, message: yaml_empty_view()}
  };
}

pub method(YamlScanResult) Len() -> int32 {
  return self.kinds.Len();
}

pub method(YamlScanResult) Get(i: int32) -> YamlToken {
  let start: int32 = self.lex_starts.Get(i);
  let n: int32 = self.lex_lens.Get(i);
  var lex: string = yaml_empty_view();
  if n > 0 {
    let p: *const int8 = ((self.src_data as intptr) + (start as intptr)) as *const int8;
    lex = string.ViewFrom(p, n);
  }

  return YamlToken{
    kind: self.kinds.Get(i),
    lexeme: lex,
    line: self.lines.Get(i),
    column: self.columns.Get(i)
  };
}

method(YamlScanner) FailAt(line: int32, column: int32, message: string) -> void {
  if self.failed {
    return;
  }

  self.failed = true;
  self.err_line = line;
  self.err_column = column;
  self.err_message = message;
}

method(YamlScanner) FailHere(message: string) -> void {
  self.FailAt(self.line, self.column, message);
}

method(YamlScanner) Emit(kind: int32, src_start: int32, src_len: int32, line: int32, column: int32) -> void {
  if self.failed {
    return;
  }

  self.kinds.Push(kind);
  self.lines.Push(line);
  self.columns.Push(column);
  self.lex_starts.Push(src_start);
  self.lex_lens.Push(src_len);
}

method(YamlScanner) EmitPunct(kind: int32) -> void {
  let ln: int32 = self.line;
  let col: int32 = self.column;
  self.Emit(kind, self.pos, 1, ln, col);
  self.pos = self.pos + 1;
  self.column = self.column + 1;
  self.content_bol = false;
}

method(YamlScanner) ConsumeNewline() -> void {
  let b: int32 = YamlByteAt(self.Src(), self.pos);
  if b == 13 {
    self.pos = self.pos + 1;
    let n: int32 = YamlByteAt(self.Src(), self.pos);
    if n == 10 {
      self.pos = self.pos + 1;
    }
  } else {
    if b == 10 {
      self.pos = self.pos + 1;
    }
  }

  self.line = self.line + 1;
  self.column = 1;
  self.line_start = true;
  self.content_bol = false;
}

method(YamlScanner) SkipCommentBody() -> void {
  while self.pos < self.text_len {
    let b: int32 = YamlByteAt(self.Src(), self.pos);
    if yaml_is_break(b) {
      return;
    }

    let n: int32 = self.Src().Utf8LenAt(self.pos);
    if n < 1 {
      self.FailHere("invalid UTF-8");
      return;
    }

    self.pos = self.pos + n;
    self.column = self.column + 1;
  }
}

method(YamlScanner) SkipInlineSpace() -> void {
  while self.pos < self.text_len {
    let b: int32 = YamlByteAt(self.Src(), self.pos);
    if yaml_is_space(b) {
      self.pos = self.pos + 1;
      self.column = self.column + 1;
      continue;
    }

    if b == 9 {
      self.pos = self.pos + 1;
      self.column = self.column + 1;
      continue;
    }

    return;
  }
}

method(YamlScanner) SkipBom() -> void {
  if self.text_len < 3 {
    return;
  }

  if YamlByteAt(self.Src(), 0) != 239 {
    return;
  }

  if YamlByteAt(self.Src(), 1) != 187 {
    return;
  }

  if YamlByteAt(self.Src(), 2) != 191 {
    return;
  }

  self.pos = 3;
}

method(YamlScanner) ApplyIndent(n: int32) -> void {
  if self.flow_depth > 0 {
    return;
  }

  if self.indents.Len() <= 0 {
    self.FailHere("internal indent stack is empty");
    return;
  }

  var top: int32 = self.indents.Get(self.indents.Len() - 1);
  if n == top {
    return;
  }

  if n > top {
    self.indents.Push(n);
    self.Emit(kYamlTokIndent, 0, 0, self.line, self.column);
    return;
  }

  while self.indents.Len() > 1 {
    top = self.indents.Get(self.indents.Len() - 1);
    if n >= top {
      break;
    }

    let _d: int32 = self.indents.Pop();
    self.Emit(kYamlTokDedent, 0, 0, self.line, self.column);
  }

  top = self.indents.Get(self.indents.Len() - 1);
  if n != top {
    self.FailHere("invalid indentation");
  }
}

method(YamlScanner) CloseIndents() -> void {
  while self.indents.Len() > 1 {
    let _d: int32 = self.indents.Pop();
    self.Emit(kYamlTokDedent, 0, 0, self.line, self.column);
  }
}

method(YamlScanner) HandleLineStart() -> void {
  var indent: int32 = 0;
  while self.pos < self.text_len {
    let b: int32 = YamlByteAt(self.Src(), self.pos);
    if yaml_is_space(b) {
      self.pos = self.pos + 1;
      self.column = self.column + 1;
      indent = indent + 1;
      continue;
    }

    if b == 9 {
      self.FailHere("tabs are not allowed as indentation");
      return;
    }

    break;
  }

  if self.pos >= self.text_len {
    self.line_start = false;
    return;
  }

  let b: int32 = YamlByteAt(self.Src(), self.pos);
  if yaml_is_break(b) {
    self.ConsumeNewline();
    return;
  }

  if b == 35 {
    self.SkipCommentBody();
    return;
  }

  self.ApplyIndent(indent);
  self.line_start = false;
  self.content_bol = true;
}

method(YamlScanner) LooksLikeDocMarker() -> bool {
  if !self.content_bol {
    return false;
  }

  let b0: int32 = YamlByteAt(self.Src(), self.pos);
  let b1: int32 = YamlByteAt(self.Src(), self.pos + 1);
  let b2: int32 = YamlByteAt(self.Src(), self.pos + 2);
  let b3: int32 = YamlByteAt(self.Src(), self.pos + 3);
  if (b0 == 45) && (b1 == 45) && (b2 == 45) {
    if b3 < 0 {
      return true;
    }

    if yaml_is_break(b3) {
      return true;
    }

    if yaml_is_blank(b3) {
      return true;
    }

    return b3 == 35;
  }

  if (b0 == 46) && (b1 == 46) && (b2 == 46) {
    if b3 < 0 {
      return true;
    }

    if yaml_is_break(b3) {
      return true;
    }

    if yaml_is_blank(b3) {
      return true;
    }

    return b3 == 35;
  }

  return false;
}

method(YamlScanner) ScanDoubleQuoted() -> void {
  let start_line: int32 = self.line;
  let start_col: int32 = self.column;
  self.pos = self.pos + 1;
  self.column = self.column + 1;
  let inner_start: int32 = self.pos;
  while self.pos < self.text_len {
    let b: int32 = YamlByteAt(self.Src(), self.pos);
    if b == 34 {
      let inner_len: int32 = self.pos - inner_start;
      self.Emit(kYamlTokStr, inner_start, inner_len, start_line, start_col);
      self.pos = self.pos + 1;
      self.column = self.column + 1;
      self.content_bol = false;
      return;
    }

    if b == 92 {
      self.pos = self.pos + 1;
      self.column = self.column + 1;
      if self.pos >= self.text_len {
        self.FailHere("unterminated quoted scalar");
        return;
      }

      let n: int32 = self.Src().Utf8LenAt(self.pos);
      if n < 1 {
        self.FailHere("invalid UTF-8");
        return;
      }

      self.pos = self.pos + n;
      self.column = self.column + 1;
      continue;
    }

    if yaml_is_break(b) {
      self.ConsumeNewline();
      continue;
    }

    let n: int32 = self.Src().Utf8LenAt(self.pos);
    if n < 1 {
      self.FailHere("invalid UTF-8");
      return;
    }

    self.pos = self.pos + n;
    self.column = self.column + 1;
  }

  self.FailAt(start_line, start_col, "unterminated quoted scalar");
}

method(YamlScanner) ScanSingleQuoted() -> void {
  let start_line: int32 = self.line;
  let start_col: int32 = self.column;
  self.pos = self.pos + 1;
  self.column = self.column + 1;
  let inner_start: int32 = self.pos;
  while self.pos < self.text_len {
    let b: int32 = YamlByteAt(self.Src(), self.pos);
    if b == 39 {
      let n: int32 = YamlByteAt(self.Src(), self.pos + 1);
      if n == 39 {
        self.pos = self.pos + 2;
        self.column = self.column + 2;
        continue;
      }

      let inner_len: int32 = self.pos - inner_start;
      self.Emit(kYamlTokStr, inner_start, inner_len, start_line, start_col);
      self.pos = self.pos + 1;
      self.column = self.column + 1;
      self.content_bol = false;
      return;
    }

    if yaml_is_break(b) {
      self.ConsumeNewline();
      continue;
    }

    let n: int32 = self.Src().Utf8LenAt(self.pos);
    if n < 1 {
      self.FailHere("invalid UTF-8");
      return;
    }

    self.pos = self.pos + n;
    self.column = self.column + 1;
  }

  self.FailAt(start_line, start_col, "unterminated quoted scalar");
}

method(YamlScanner) ScanPlain() -> void {
  let start: int32 = self.pos;
  let start_line: int32 = self.line;
  let start_col: int32 = self.column;
  while self.pos < self.text_len {
    let b: int32 = YamlByteAt(self.Src(), self.pos);
    if yaml_is_break(b) {
      break;
    }

    if b == 58 {
      if yaml_is_colon_break(self.Src(), self.pos) {
        break;
      }
    } else {
      if self.flow_depth > 0 {
        if yaml_is_flow_indicator(b) {
          break;
        }
      }

      if b == 35 {
        if start < self.pos {
          let prev: int32 = YamlByteAt(self.Src(), self.pos - 1);
          if yaml_is_blank(prev) {
            break;
          }
        } else {
          break;
        }
      }

      if yaml_is_blank(b) {
        var j: int32 = self.pos;
        while j < self.text_len {
          let w: int32 = YamlByteAt(self.Src(), j);
          if !yaml_is_blank(w) {
            break;
          }

          j = j + 1;
        }

        let nxt: int32 = YamlByteAt(self.Src(), j);
        if nxt < 0 {
          break;
        }

        if yaml_is_break(nxt) {
          break;
        }

        if nxt == 35 {
          break;
        }

        if self.flow_depth > 0 {
          if yaml_is_flow_indicator(nxt) {
            break;
          }
        }

        if nxt == 58 {
          if yaml_is_colon_break(self.Src(), j) {
            break;
          }
        }
      }
    }

    let n: int32 = self.Src().Utf8LenAt(self.pos);
    if n < 1 {
      self.FailHere("invalid UTF-8");
      return;
    }

    self.pos = self.pos + n;
    self.column = self.column + 1;
  }

  let len: int32 = self.pos - start;
  if len <= 0 {
    self.FailHere("unexpected character");
    return;
  }

  var end: int32 = self.pos;
  while end > start {
    let last: int32 = YamlByteAt(self.Src(), end - 1);
    if !yaml_is_blank(last) {
      break;
    }

    end = end - 1;
  }

  let nlex: int32 = end - start;
  let p: *const int8 = ((self.text_data as intptr) + (start as intptr)) as *const int8;
  let lexeme: string = string.ViewFrom(p, nlex);
  let kind: int32 = YamlClassifyPlain(lexeme);
  self.Emit(kind, start, nlex, start_line, start_col);
  self.content_bol = false;
}

method(YamlScanner) ScanToken() -> void {
  if self.LooksLikeDocMarker() {
    self.FailHere("multi-document streams are not supported in v1");
    return;
  }

  let b: int32 = YamlByteAt(self.Src(), self.pos);
  if b == 38 {
    self.FailHere("anchors and aliases are not supported in v1");
    return;
  }

  if b == 42 {
    self.FailHere("anchors and aliases are not supported in v1");
    return;
  }

  if b == 33 {
    self.FailHere("tags are not supported in v1");
    return;
  }

  if b == 37 {
    self.FailHere("YAML directives are not supported in v1");
    return;
  }

  if (b == 124) || (b == 62) {
    self.FailHere("block scalars are not supported in v1");
    return;
  }

  if b == 63 {
    let n: int32 = YamlByteAt(self.Src(), self.pos + 1);
    if (n < 0) || yaml_is_blank(n) || yaml_is_break(n) {
      self.FailHere("complex keys are not supported in v1");
      return;
    }
  }

  if b == 123 {
    self.flow_depth = self.flow_depth + 1;
    self.EmitPunct(kYamlTokLBrace);
    return;
  }

  if b == 125 {
    if self.flow_depth > 0 {
      self.flow_depth = self.flow_depth - 1;
    }

    self.EmitPunct(kYamlTokRBrace);
    return;
  }

  if b == 91 {
    self.flow_depth = self.flow_depth + 1;
    self.EmitPunct(kYamlTokLBracket);
    return;
  }

  if b == 93 {
    if self.flow_depth > 0 {
      self.flow_depth = self.flow_depth - 1;
    }

    self.EmitPunct(kYamlTokRBracket);
    return;
  }

  if b == 44 {
    self.EmitPunct(kYamlTokComma);
    return;
  }

  if b == 58 {
    self.EmitPunct(kYamlTokColon);
    return;
  }

  if b == 45 {
    let n: int32 = YamlByteAt(self.Src(), self.pos + 1);
    if (n < 0) || yaml_is_blank(n) || yaml_is_break(n) || yaml_is_flow_indicator(n) {
      self.EmitPunct(kYamlTokDash);
      return;
    }
  }

  if b == 34 {
    self.ScanDoubleQuoted();
    return;
  }

  if b == 39 {
    self.ScanSingleQuoted();
    return;
  }

  self.ScanPlain();
}

/**
 * @brief Tokenize one v1 YAML document into `self` (caller owns this result). Comments omitted.
 */
pub method(YamlScanResult) Tokenize(text: string) -> void {
  self.ok = true;
  self.kinds.Clear();
  self.lines.Clear();
  self.columns.Clear();
  self.lex_starts.Clear();
  self.lex_lens.Clear();
  self.src_data = text.data as *const int8;
  self.src_len = text.length;
  self.error = YamlError{line: 0, column: 0, message: yaml_empty_view()};
  var sc: YamlScanner = YamlScanner{
    text_data: text.data as *const int8,
    text_len: text.length,
    pos: 0,
    line: 1,
    column: 1,
    line_start: true,
    content_bol: false,
    flow_depth: 0,
    failed: false,
    err_line: 1,
    err_column: 1,
    err_message: string.ViewFrom(0 as *const int8, 0),
    kinds: yaml_empty_i32(),
    lines: yaml_empty_i32(),
    columns: yaml_empty_i32(),
    lex_starts: yaml_empty_i32(),
    lex_lens: yaml_empty_i32(),
    indents: yaml_empty_indents()
  };
  sc.indents.Push(0);
  sc.SkipBom();
  while !sc.failed {
    if sc.pos >= sc.text_len {
      break;
    }

    if sc.line_start {
      sc.HandleLineStart();
      continue;
    }

    sc.SkipInlineSpace();
    if sc.failed {
      break;
    }

    if sc.pos >= sc.text_len {
      break;
    }

    let b: int32 = YamlByteAt(sc.Src(), sc.pos);
    if yaml_is_break(b) {
      sc.ConsumeNewline();
      continue;
    }

    if b == 35 {
      sc.SkipCommentBody();
      continue;
    }

    sc.ScanToken();
  }

  if sc.failed {
    self.ok = false;
    self.error = YamlError{line: sc.err_line, column: sc.err_column, message: sc.err_message};
    sc.kinds.Destroy();
    sc.lines.Destroy();
    sc.columns.Destroy();
    sc.lex_starts.Destroy();
    sc.lex_lens.Destroy();
    sc.indents.Destroy();
    return;
  }

  sc.CloseIndents();
  sc.Emit(kYamlTokStreamEnd, 0, 0, sc.line, sc.column);
  var i: int32 = 0;
  let n: int32 = sc.kinds.Len();
  while i < n {
    self.kinds.Push(sc.kinds.Get(i));
    self.lines.Push(sc.lines.Get(i));
    self.columns.Push(sc.columns.Get(i));
    self.lex_starts.Push(sc.lex_starts.Get(i));
    self.lex_lens.Push(sc.lex_lens.Get(i));
    i = i + 1;
  }

  sc.kinds.Destroy();
  sc.lines.Destroy();
  sc.columns.Destroy();
  sc.lex_starts.Destroy();
  sc.lex_lens.Destroy();
  sc.indents.Destroy();
}

/** @brief Whether tokenization completed without a lexical error.
 * @returns True for a valid token sequence; false when Error contains the lexical diagnostic.
 */
pub method(YamlScanResult) IsOk() -> bool {
  return self.ok;
}

/** @brief Copy the scanner diagnostic without exposing mutable scanner state.
 * @returns The lexical diagnostic, meaningful when IsOk is false.
 */
pub method(YamlScanResult) Error() -> YamlError {
  return self.error;
}

/** @brief Read the source delimiter preceding a token's borrowed lexeme.
 * @returns The delimiter byte, or double quote for an absent/invalid token location.
 * @note The source must remain alive, as required for Get's borrowed lexemes.
 */
pub method(YamlScanResult) QuoteAt(index: int32) -> int32 {
  if index < 0 || index >= self.Len() {
    return 34;
  }

  let start: int32 = self.lex_starts.Get(index);
  if start <= 0 {
    return 34;
  }

  let source: string = string.ViewFrom(self.src_data, self.src_len);

  return YamlByteAt(source, start - 1);
}
