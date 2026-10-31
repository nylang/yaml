// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief YAML scalar values, UTF-8 conversion and quoted serialization. */
module YamlScalar;
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/lexical.ny";

/**
 * @brief Construct a null scalar for syntax and DOM event consumers.
 * @returns A YAML value holding the null variant.
 */
pub static method(Yaml) Null() -> Yaml {
  return Yaml{node: YamlNull{_pad: 0}};
}

/**
 * @brief Construct a boolean scalar without parser state.
 * @returns A YAML value holding the supplied boolean.
 */
pub static method(Yaml) FromBool(v: bool) -> Yaml {
  return Yaml{node: YamlBool{value: v}};
}

/**
 * @brief Construct an integer scalar without parser state.
 * @returns A YAML value retaining the supplied signed integer.
 */
pub static method(Yaml) FromInt(v: int64) -> Yaml {
  return Yaml{node: YamlInt{value: v}};
}

/**
 * @brief Construct a text scalar using ordinary language ownership.
 * @returns A YAML string node retaining the supplied text.
 */
pub static method(Yaml) FromStr(v: string) -> Yaml {
  return Yaml{node: YamlStr{value: v}};
}

/**
 * @brief Encode a Unicode scalar used by YAML escape processing.
 * @returns UTF-8 text for the supplied code point under the parser validation contract.
 */
pub static method(YamlStr) EncodeCodePoint(cp: int32) -> string {
  if cp <= 0 {
    return "";
  }

  if cp < 128 {
    var out: string = string.Alloc(1);
    var b0: uint8 = cp as uint8;
    memcpy((out.data as *mut uint8),(&b0) as *const uint8, 1up);

    return out;
  }

  if cp <= 2047 {
    var out: string = string.Alloc(2);
    var b0: uint8 = (192 + (cp / 64)) as uint8;
    var b1: uint8 = (128 + (cp - (cp / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8),(&b0) as *const uint8, 1up);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1ip)) as *mut uint8;
    memcpy(p1,(&b1) as *const uint8, 1up);

    return out;
  }

  if cp <= 65535 {
    var out: string = string.Alloc(3);
    var b0: uint8 = (224 + (cp / 4096)) as uint8;
    let r1: int32 = cp - (cp / 4096) * 4096;
    var b1: uint8 = (128 + (r1 / 64)) as uint8;
    var b2: uint8 = (128 + (r1 - (r1 / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8),(&b0) as *const uint8, 1up);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1ip)) as *mut uint8;
    memcpy(p1,(&b1) as *const uint8, 1up);
    let p2: *mut uint8 = (((out.data as *mut int8) as intptr) + (2ip)) as *mut uint8;
    memcpy(p2,(&b2) as *const uint8, 1up);

    return out;
  }

  return "";
}
/**
 * @brief Escape a YAML string into an unambiguous double-quoted scalar.
 * @returns Quoted text preserving the original string payload.
 */
pub static method(YamlStr) Quote(s: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(s.length + 2);
  buf.Append("\"");
  var i: int32 = 0;
  let n: int32 = s.length;
  while i < n {
    let b: int32 = s.ByteAt(i);
    if b == 92 {
      buf.Append("\\\\");
      i = i + 1;
      continue;
    }

    if b == 34 {
      buf.Append("\\\"");
      i = i + 1;
      continue;
    }

    if b == 10 {
      buf.Append("\\n");
      i = i + 1;
      continue;
    }

    if b == 9 {
      buf.Append("\\t");
      i = i + 1;
      continue;
    }

    if (b < 32) || (b == 127) {
      buf.Append(YamlStr.EscapeByte(b));
      i = i + 1;
      continue;
    }

    var nch: int32 = s.Utf8LenAt(i);
    if nch < 1 {
      nch = 1;
    }

    buf.Append(s.View(i, nch));
    i = i + nch;
  }

  buf.Append("\"");

  return buf.Take();
}

static method(YamlStr) HexDigit(n: int32) -> string {
  var d: int32 = n;
  if d < 0 {
    d = 0;
  }

  if d > 15 {
    d = 15;
  }

  if d < 10 {
    return YamlStr.EncodeCodePoint(48 + d);
  }

  return YamlStr.EncodeCodePoint(87 + d);
}

static method(YamlStr) EscapeByte(b: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(6);
  buf.Append("\\u00");
  buf.Append(YamlStr.HexDigit((b / 16) & 15));
  buf.Append(YamlStr.HexDigit(b & 15));

  return buf.Take();
}
