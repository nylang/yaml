// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module YamlDump;
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";

/**
 * @brief Canonical JSON-like dump of a `Yaml` tree (m_v0.7_p4 vs Go yaml.v3).
 * @note Recursive Dump / DumpMap / DumpSeq (compiler no longer infinite-inlines methods).
 */

struct YamlDumper {
  buf: StringBuffer;
}

method(YamlDumper) PutNull() -> void {
  self.buf.Append("{\"t\":\"null\"}");
}

method(YamlDumper) PutBool(v: bool) -> void {
  self.buf.Append("{\"t\":\"bool\",\"v\":");
  if v {
    self.buf.Append("true");
  } else {
    self.buf.Append("false");
  }

  self.buf.Append("}");
}

method(YamlDumper) PutInt(v: int64) -> void {
  self.buf.Append("{\"t\":\"int\",\"v\":");
  self.buf.Append(YamlI64Text(v));
  self.buf.Append("}");
}

method(YamlDumper) PutStr(s: string) -> void {
  self.buf.Append("{\"t\":\"str\",\"v\":");
  self.buf.Append(YamlEmitQuote(s));
  self.buf.Append("}");
}

method(YamlDumper) PutEmptySeq() -> void {
  self.buf.Append("{\"t\":\"seq\",\"v\":[]}");
}

method(YamlDumper) PutEmptyMap() -> void {
  self.buf.Append("{\"t\":\"map\",\"v\":[]}");
}

method(YamlDumper) DumpLeaf(node: Yaml) -> void {
  if node.node.holds<YamlNull>() {
    self.PutNull();
    return;
  }

  if node.node.holds<YamlBool>() {
    let bv: YamlBool? = node.node.get_if<YamlBool>();
    if bv != nil {
      let b: YamlBool = bv as YamlBool;
      self.PutBool(b.value);
    }

    return;
  }

  if node.node.holds<YamlInt>() {
    let iv: YamlInt? = node.node.get_if<YamlInt>();
    if iv != nil {
      let n: YamlInt = iv as YamlInt;
      self.PutInt(n.value);
    }

    return;
  }

  if node.node.holds<YamlStr>() {
    let sv: YamlStr? = node.node.get_if<YamlStr>();
    if sv != nil {
      let s: YamlStr = sv as YamlStr;
      self.PutStr(s.value);
    }

    return;
  }

  if node.node.holds<YamlSeq>() {
    self.PutEmptySeq();
    return;
  }

  if node.node.holds<YamlMap>() {
    self.PutEmptyMap();
    return;
  }

  self.PutNull();
}

method(YamlDumper) Dump(node: Yaml) -> void {
  if node.node.holds<YamlSeq>() {
    let seq: YamlSeq? = node.node.get_if<YamlSeq>();
    if seq != nil {
      self.DumpSeq(seq as YamlSeq);
    }

    return;
  }

  if node.node.holds<YamlMap>() {
    let map: YamlMap? = node.node.get_if<YamlMap>();
    if map != nil {
      self.DumpMap(map as YamlMap);
    }

    return;
  }

  self.DumpLeaf(node);
}

method(YamlDumper) DumpSeq(seqv: YamlSeq) -> void {
  let n: int32 = seqv.Len();
  if n <= 0 {
    self.PutEmptySeq();
    return;
  }

  self.buf.Append("{\"t\":\"seq\",\"v\":[");
  var i: int32 = 0;
  while i < n {
    if i > 0 {
      self.buf.Append(",");
    }

    unsafe {
      let item: *mut Yaml = &mut seqv.items.buf[i];
      self.Dump((*item));
    }

    i = i + 1;
  }

  self.buf.Append("]}");
}

method(YamlDumper) DumpMap(mapv: YamlMap) -> void {
  let n: int32 = mapv.Len();
  if n <= 0 {
    self.PutEmptyMap();
    return;
  }

  self.buf.Append("{\"t\":\"map\",\"v\":[");
  var i: int32 = 0;
  while i < n {
    if i > 0 {
      self.buf.Append(",");
    }

    self.buf.Append("{\"k\":");
    unsafe {
      let ep: *mut YamlMapEntry = &mut mapv.entries.buf[i];
      self.buf.Append(YamlEmitQuote((*ep).key));
      self.buf.Append(",\"v\":");
      self.Dump((*ep).value);
    }

    self.buf.Append("}");
    i = i + 1;
  }

  self.buf.Append("]}");
}

/**
 * @brief One-line JSON-like dump plus trailing newline (matches Go yamlcorpus dumps).
 */
pub func YamlCanonicalDump(node: Yaml) -> string {
  var d: YamlDumper = YamlDumper{buf: StringBuffer.NewWithCapacity(64)};
  d.Dump(node);
  d.buf.Append("\n");

  return d.buf.Take();
}
