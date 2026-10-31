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

static method(YamlScanner) IsBreak(b: int32) -> bool {
  if b == 10 {
    return true;
  }

  return b == 13;
}

static method(YamlScanner) IsSpace(b: int32) -> bool {
  return b == 32;
}

static method(YamlScanner) IsBlank(b: int32) -> bool {
  if YamlScanner.IsSpace(b) {
    return true;
  }

  return b == 9;
}

static method(YamlScanner) IsHex(b: int32) -> bool {
  if YamlToken.IsDigit(b) {
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

static method(YamlScanner) HexValue(b: int32) -> int32 {
  if YamlToken.IsDigit(b) {
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

/** @brief Retain one raw source byte as a language-owned string.
 * @returns A one-byte string including NUL when supplied. */
pub static method(YamlStr) FromByte(b: uint8) -> string {
  var out: string = string.Alloc(1);
  var src: uint8 = b;
  memcpy((out.data as *mut uint8),(&src) as *const uint8, 1up);

  return out;
}

static method(YamlScanner) IsFlowIndicator(b: int32) -> bool {
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

static method(YamlScanner) IsColonBreak(text: string, pos: int32) -> bool {
  let n: int32 = text.ByteAt(pos + 1);
  if n < 0 {
    return true;
  }

  if YamlScanner.IsBreak(n) {
    return true;
  }

  if YamlScanner.IsBlank(n) {
    return true;
  }

  if n == 35 {
    return true;
  }

  return YamlScanner.IsFlowIndicator(n);
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

/**
 * @brief Initialize an empty token result without parser or document state.
 * @returns A valid empty token result borrowing no source payload.
 */
pub static method(YamlScanResult) New() -> YamlScanResult {
  return YamlScanResult{
    ok: true,
    src_data: 0 as *const int8,
    src_len: 0,
    kinds: Array<int32>{},
    lines: Array<int32>{},
    columns: Array<int32>{},
    lex_starts: Array<int32>{},
    lex_lens: Array<int32>{},
    error: YamlError{line: 0, column: 0, message: ""}
  };
}

/** @brief Count the retained scanner tokens.
 * @returns Number of tokens, including structural/end tokens. */
pub method(YamlScanResult) Len() -> int32 {
  return self.kinds.Len();
}

/** @brief Read a token while borrowing its lexeme from the live source window.
 * @param i Valid token index smaller than Len.
 * @returns A token whose lexeme expires with the original source bytes. */
pub method(YamlScanResult) Get(i: int32) -> YamlToken {
  let start: int32 = self.lex_starts.Get(i);
  let n: int32 = self.lex_lens.Get(i);
  var lex: string = "";
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
  let b: int32 = (self.Src()).ByteAt(self.pos);
  if b == 13 {
    self.pos = self.pos + 1;
    let n: int32 = (self.Src()).ByteAt(self.pos);
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
    let b: int32 = (self.Src()).ByteAt(self.pos);
    if YamlScanner.IsBreak(b) {
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
    let b: int32 = (self.Src()).ByteAt(self.pos);
    if YamlScanner.IsSpace(b) {
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

  if (self.Src()).ByteAt(0) != 239 {
    return;
  }

  if (self.Src()).ByteAt(1) != 187 {
    return;
  }

  if (self.Src()).ByteAt(2) != 191 {
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
    let b: int32 = (self.Src()).ByteAt(self.pos);
    if YamlScanner.IsSpace(b) {
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

  let b: int32 = (self.Src()).ByteAt(self.pos);
  if YamlScanner.IsBreak(b) {
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

  let b0: int32 = (self.Src()).ByteAt(self.pos);
  let b1: int32 = (self.Src()).ByteAt(self.pos + 1);
  let b2: int32 = (self.Src()).ByteAt(self.pos + 2);
  let b3: int32 = (self.Src()).ByteAt(self.pos + 3);
  if (b0 == 45) && (b1 == 45) && (b2 == 45) {
    if b3 < 0 {
      return true;
    }

    if YamlScanner.IsBreak(b3) {
      return true;
    }

    if YamlScanner.IsBlank(b3) {
      return true;
    }

    return b3 == 35;
  }

  if (b0 == 46) && (b1 == 46) && (b2 == 46) {
    if b3 < 0 {
      return true;
    }

    if YamlScanner.IsBreak(b3) {
      return true;
    }

    if YamlScanner.IsBlank(b3) {
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
    let b: int32 = (self.Src()).ByteAt(self.pos);
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

    if YamlScanner.IsBreak(b) {
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
    let b: int32 = (self.Src()).ByteAt(self.pos);
    if b == 39 {
      let n: int32 = (self.Src()).ByteAt(self.pos + 1);
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

    if YamlScanner.IsBreak(b) {
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
    let b: int32 = (self.Src()).ByteAt(self.pos);
    if YamlScanner.IsBreak(b) {
      break;
    }

    if b == 58 {
      if YamlScanner.IsColonBreak(self.Src(), self.pos) {
        break;
      }
    } else {
      if self.flow_depth > 0 {
        if YamlScanner.IsFlowIndicator(b) {
          break;
        }
      }

      if b == 35 {
        if start < self.pos {
          let prev: int32 = (self.Src()).ByteAt(self.pos - 1);
          if YamlScanner.IsBlank(prev) {
            break;
          }
        } else {
          break;
        }
      }

      if YamlScanner.IsBlank(b) {
        var j: int32 = self.pos;
        while j < self.text_len {
          let w: int32 = (self.Src()).ByteAt(j);
          if !YamlScanner.IsBlank(w) {
            break;
          }

          j = j + 1;
        }

        let nxt: int32 = (self.Src()).ByteAt(j);
        if nxt < 0 {
          break;
        }

        if YamlScanner.IsBreak(nxt) {
          break;
        }

        if nxt == 35 {
          break;
        }

        if self.flow_depth > 0 {
          if YamlScanner.IsFlowIndicator(nxt) {
            break;
          }
        }

        if nxt == 58 {
          if YamlScanner.IsColonBreak(self.Src(), j) {
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
    let last: int32 = (self.Src()).ByteAt(end - 1);
    if !YamlScanner.IsBlank(last) {
      break;
    }

    end = end - 1;
  }

  let nlex: int32 = end - start;
  let p: *const int8 = ((self.text_data as intptr) + (start as intptr)) as *const int8;
  let lexeme: string = string.ViewFrom(p, nlex);
  let kind: int32 = YamlToken.Classify(lexeme);
  self.Emit(kind, start, nlex, start_line, start_col);
  self.content_bol = false;
}

method(YamlScanner) ScanToken() -> void {
  if self.LooksLikeDocMarker() {
    self.FailHere("multi-document streams are not supported in v1");
    return;
  }

  let b: int32 = (self.Src()).ByteAt(self.pos);
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
    let n: int32 = (self.Src()).ByteAt(self.pos + 1);
    if (n < 0) || YamlScanner.IsBlank(n) || YamlScanner.IsBreak(n) {
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
    let n: int32 = (self.Src()).ByteAt(self.pos + 1);
    if (n < 0) || YamlScanner.IsBlank(n) || YamlScanner.IsBreak(n) || YamlScanner.IsFlowIndicator(n) {
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
  self.error = YamlError{line: 0, column: 0, message: ""};
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
    kinds: Array<int32>{},
    lines: Array<int32>{},
    columns: Array<int32>{},
    lex_starts: Array<int32>{},
    lex_lens: Array<int32>{},
    indents: Array<int32>{}
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

    let b: int32 = (sc.Src()).ByteAt(sc.pos);
    if YamlScanner.IsBreak(b) {
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

  return source.ByteAt(start - 1);
}
