// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief YAML scalar values, UTF-8 conversion and quoted serialization. */
module YamlScalar;
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/lexical.ny";

/**
 * @brief Provide an empty YAML string value without allocating payload storage.
 * @returns An empty borrowed string value.
 */
pub func YamlEmptyStr() -> string {
  return string.ViewFrom(0 as *const int8, 0);
}

/**
 * @brief Retain YAML text beyond the source buffer lifetime.
 * @returns A language-owned copy, or an empty value for empty input.
 */
pub func YamlCopyStr(s: string) -> string {
  if s.length <= 0 {
    return YamlEmptyStr();
  }

  var out: string = string.Alloc(s.length);
  memcpy((out.data as *mut uint8), s.data, s.length as uintptr);

  return out;
}

/**
 * @brief Construct a null scalar for syntax and DOM event consumers.
 * @returns A YAML value holding the null variant.
 */
pub func YamlNullNode() -> Yaml {
  return Yaml{node: YamlNull{_pad: 0}};
}

/**
 * @brief Construct a boolean scalar without parser state.
 * @returns A YAML value holding the supplied boolean.
 */
pub func YamlBoolNode(v: bool) -> Yaml {
  return Yaml{node: YamlBool{value: v}};
}

/**
 * @brief Construct an integer scalar without parser state.
 * @returns A YAML value retaining the supplied signed integer.
 */
pub func YamlIntNode(v: int64) -> Yaml {
  return Yaml{node: YamlInt{value: v}};
}

/**
 * @brief Construct a text scalar using ordinary language ownership.
 * @returns A YAML string node retaining the supplied text.
 */
pub func YamlStrNode(v: string) -> Yaml {
  return Yaml{node: YamlStr{value: v}};
}

/**
 * @brief Read a YAML parser source byte with an explicit bounds sentinel.
 * @returns A widened byte, or -1 outside the source range.
 */
pub func YamlParseByte(s: string, i: int32) -> int32 {
  if i < 0 {
    return -1;
  }

  if i >= s.length {
    return -1;
  }

  return (s[i] as int32) & 255;
}

/**
 * @brief Encode a Unicode scalar used by YAML escape processing.
 * @returns UTF-8 text for the supplied code point under the parser validation contract.
 */
pub func YamlUtf8Cp(cp: int32) -> string {
  if cp <= 0 {
    return YamlEmptyStr();
  }

  if cp < 128 {
    var out: string = string.Alloc(1);
    var b0: uint8 = cp as uint8;
    memcpy((out.data as *mut uint8),(&b0) as *const uint8, 1 as uintptr);

    return out;
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

  return YamlEmptyStr();
}
/**
 * @brief Escape a YAML string into an unambiguous double-quoted scalar.
 * @returns Quoted text preserving the original string payload.
 */
pub func YamlEmitQuote(s: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(s.length + 2);
  buf.Append("\"");
  var i: int32 = 0;
  let n: int32 = s.length;
  while i < n {
    let b: int32 = YamlParseByte(s, i);
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
      buf.Append(yaml_u00(b));
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

/**
 * @brief Format a YAML integer without locale or floating-point conversion.
 * @returns Exact signed base-10 text.
 */
pub func YamlI64Text(v: int64) -> string {
  if v == (0 as int64) {
    return "0";
  }

  let min64: int64 = (0 as int64) - (9223372036854775807 as int64) - (1 as int64);
  if v == min64 {
    return "-9223372036854775808";
  }

  var neg: bool = v <(0 as int64);
  var mag: uint64 = v as uint64;
  if neg {
    mag = ((0 as int64) - v) as uint64;
  }

  var tmp: uint64 = mag;
  var nd: int32 = 0;
  let ten: uint64 = 10u64;
  while tmp > 0u64 {
    tmp = tmp / ten;
    nd = nd + 1;
  }

  var cap: int32 = nd;
  if neg {
    cap = nd + 1;
  }

  var out: string = string.Alloc(cap);
  var p: *mut uint8 = (out.data as *mut uint8);
  var pos: int32 = cap - 1;
  tmp = mag;
  while tmp > 0u64 {
    let d: uint64 = tmp - (tmp / ten) * ten;
    var ch: uint8 = ((d as int32) + 48) as uint8;
    let dest: *mut uint8 = ((p as intptr) + (pos as intptr)) as *mut uint8;
    memcpy(dest,(&ch) as *const uint8, 1 as uintptr);
    pos = pos - 1;
    tmp = tmp / ten;
  }

  if neg {
    var minus: uint8 = 45 as uint8;
    memcpy(p,(&minus) as *const uint8, 1 as uintptr);
  }

  return out;
}

func yaml_hex_char(n: int32) -> string {
  var d: int32 = n;
  if d < 0 {
    d = 0;
  }

  if d > 15 {
    d = 15;
  }

  if d < 10 {
    return YamlUtf8Cp(48 + d);
  }

  return YamlUtf8Cp(87 + d);
}

func yaml_u00(b: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(6);
  buf.Append("\\u00");
  buf.Append(yaml_hex_char((b / 16) & 15));
  buf.Append(yaml_hex_char(b & 15));

  return buf.Take();
}
