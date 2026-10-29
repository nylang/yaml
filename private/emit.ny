// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module YamlEncoding;
import "stdlib:stdlib.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
import "private/scalar.ny";
import "private/lexical.ny";

/**
 * @brief Canonical block YAML emit (yaml.md §1.5).
 * @note Same TU as `Yaml` layouts so `holds` / `get_if` on `Yaml.node` resolve.
 */

struct YamlEmitter {
  buf: StringBuffer;
}

func yaml_plain_char(b: int32) -> bool {
  if (b >= 65) && (b <= 90) {
    return true;
  }

  if (b >= 97) && (b <= 122) {
    return true;
  }

  if (b >= 48) && (b <= 57) {
    return true;
  }

  if b == 95 {
    return true;
  }

  if b == 46 {
    return true;
  }

  if b == 47 {
    return true;
  }

  if b == 43 {
    return true;
  }

  return b == 45;
}

func yaml_emit_plain_ok(s: string) -> bool {
  let n: int32 = s.length;
  if n <= 0 {
    return false;
  }

  var i: int32 = 0;
  while i < n {
    if !yaml_plain_char(YamlParseByte(s, i)) {
      return false;
    }

    i = i + 1;
  }

  if (s == "-") {
    return false;
  }

  let k: int32 = YamlClassifyPlain(s);
  if k == kYamlTokNull {
    return false;
  }

  if k == kYamlTokBool {
    return false;
  }

  return k != kYamlTokInt;
}

// Escape payload bytes independently of YAML structure so scalar content cannot introduce a new node.

func yaml_emit_scalar_text(s: string) -> string {
  if yaml_emit_plain_ok(s) {
    return s;
  }

  return YamlEmitQuote(s);
}

// Render the signed minimum without a signed negation overflow.

// Compare parsed tree content rather than serialized layout when checking YAML round trips.
func yaml_trees_equal(a: Yaml, b: Yaml) -> bool {
  if a.node.holds<YamlNull>() {
    return b.node.holds<YamlNull>();
  }

  if a.node.holds<YamlBool>() {
    if !b.node.holds<YamlBool>() {
      return false;
    }

    let ab: YamlBool? = a.node.get_if<YamlBool>();
    let bb: YamlBool? = b.node.get_if<YamlBool>();
    if ab == nil {
      return false;
    }

    if bb == nil {
      return false;
    }

    let abv: YamlBool = ab as YamlBool;
    let bbv: YamlBool = bb as YamlBool;

    return abv.value == bbv.value;
  }

  if a.node.holds<YamlInt>() {
    if !b.node.holds<YamlInt>() {
      return false;
    }

    let ai: YamlInt? = a.node.get_if<YamlInt>();
    let bi: YamlInt? = b.node.get_if<YamlInt>();
    if ai == nil {
      return false;
    }

    if bi == nil {
      return false;
    }

    let aiv: YamlInt = ai as YamlInt;
    let biv: YamlInt = bi as YamlInt;

    return aiv.value == biv.value;
  }

  if a.node.holds<YamlStr>() {
    if !b.node.holds<YamlStr>() {
      return false;
    }

    let asv: YamlStr? = a.node.get_if<YamlStr>();
    let bsv: YamlStr? = b.node.get_if<YamlStr>();
    if asv == nil {
      return false;
    }

    if bsv == nil {
      return false;
    }

    let asvv: YamlStr = asv as YamlStr;
    let bsvv: YamlStr = bsv as YamlStr;

    return (asvv.value == bsvv.value);
  }

  if a.node.holds<YamlSeq>() {
    if !b.node.holds<YamlSeq>() {
      return false;
    }

    let aseq: YamlSeq? = a.node.get_if<YamlSeq>();
    let bseq: YamlSeq? = b.node.get_if<YamlSeq>();
    if aseq == nil {
      return false;
    }

    if bseq == nil {
      return false;
    }

    var sa: YamlSeq = aseq as YamlSeq;
    var sb: YamlSeq = bseq as YamlSeq;
    let n: int32 = sa.Len();
    if n != sb.Len() {
      return false;
    }

    var i: int32 = 0;
    while i < n {
      unsafe {
        let pa: *mut Yaml = &mut sa.items.buf[i];
        let pb: *mut Yaml = &mut sb.items.buf[i];
        if !yaml_trees_equal((*pa),(*pb)) {
          return false;
        }
      }

      i = i + 1;
    }

    return true;
  }

  if a.node.holds<YamlMap>() {
    if !b.node.holds<YamlMap>() {
      return false;
    }

    let am: YamlMap? = a.node.get_if<YamlMap>();
    let bm: YamlMap? = b.node.get_if<YamlMap>();
    if am == nil {
      return false;
    }

    if bm == nil {
      return false;
    }

    var ma: YamlMap = am as YamlMap;
    var mb: YamlMap = bm as YamlMap;
    let n: int32 = ma.Len();
    if n != mb.Len() {
      return false;
    }

    var i: int32 = 0;
    while i < n {
      unsafe {
        let ea: *mut YamlMapEntry = &mut ma.entries.buf[i];
        let eb: *mut YamlMapEntry = &mut mb.entries.buf[i];
        if ((*ea).key != (*eb).key) {
          return false;
        }

        if !yaml_trees_equal((*ea).value,(*eb).value) {
          return false;
        }
      }

      i = i + 1;
    }

    return true;
  }

  return false;
}

method(YamlEmitter) PutIndent(n: int32) -> void {
  var i: int32 = 0;
  while i < n {
    self.buf.Append("  ");
    i = i + 1;
  }
}

method(YamlEmitter) EmitMap(mapv: YamlMap, indent: int32, after_dash: bool) -> void {
  let n: int32 = mapv.Len();
  if n <= 0 {
    if !after_dash {
      self.PutIndent(indent);
    }

    self.buf.Append("{}");
    return;
  }

  var i: int32 = 0;
  while i < n {
    if i > 0 {
      self.buf.Append("\n");
    }

    if (i > 0) || !after_dash {
      self.PutIndent(indent);
    }

    unsafe {
      let ep: *mut YamlMapEntry = &mut mapv.entries.buf[i];
      self.buf.Append(yaml_emit_scalar_text((*ep).key));
      if (*ep).value.node.holds<YamlMap>() {
        let m: YamlMap? = (*ep).value.node.get_if<YamlMap>();
        if m != nil {
          var mv: YamlMap = m as YamlMap;
          if mv.Len() > 0 {
            self.buf.Append(":\n");
            self.EmitMap(mv, indent + 1, false);
          } else {
            self.buf.Append(": ");
            self.buf.Append("{}");
          }
        }
      } else {
        if (*ep).value.node.holds<YamlSeq>() {
          let s: YamlSeq? = (*ep).value.node.get_if<YamlSeq>();
          if s != nil {
            var sv: YamlSeq = s as YamlSeq;
            if sv.Len() > 0 {
              self.buf.Append(":\n");
              self.EmitSeq(sv, indent + 1, false);
            } else {
              self.buf.Append(": ");
              self.buf.Append("[]");
            }
          }
        } else {
          self.buf.Append(": ");
          self.EmitYaml((*ep).value, indent + 1, true);
        }
      }
    }

    i = i + 1;
  }
}

method(YamlEmitter) EmitSeq(seqv: YamlSeq, indent: int32, after_dash: bool) -> void {
  let n: int32 = seqv.Len();
  if n <= 0 {
    if !after_dash {
      self.PutIndent(indent);
    }

    self.buf.Append("[]");
    return;
  }

  var i: int32 = 0;
  while i < n {
    if i > 0 {
      self.buf.Append("\n");
    }

    if (i > 0) || !after_dash {
      self.PutIndent(indent);
    }

    self.buf.Append("- ");
    unsafe {
      let item: *mut Yaml = &mut seqv.items.buf[i];
      if (*item).node.holds<YamlMap>() {
        let m: YamlMap? = (*item).node.get_if<YamlMap>();
        if m != nil {
          var mv: YamlMap = m as YamlMap;
          if mv.Len() > 0 {
            self.EmitMap(mv, indent + 1, true);
          } else {
            self.buf.Append("{}");
          }
        }
      } else {
        if (*item).node.holds<YamlSeq>() {
          let s: YamlSeq? = (*item).node.get_if<YamlSeq>();
          if s != nil {
            var sv: YamlSeq = s as YamlSeq;
            if sv.Len() > 0 {
              self.buf.Append("\n");
              self.EmitSeq(sv, indent + 1, false);
            } else {
              self.buf.Append("[]");
            }
          }
        } else {
          self.EmitYaml((*item), indent + 1, true);
        }
      }
    }

    i = i + 1;
  }
}

method(YamlEmitter) EmitYaml(node: Yaml, indent: int32, after_dash: bool) -> void {
  if node.node.holds<YamlNull>() {
    if !after_dash {
      self.PutIndent(indent);
    }

    self.buf.Append("null");
    return;
  }

  if node.node.holds<YamlBool>() {
    let bv: YamlBool? = node.node.get_if<YamlBool>();
    if bv != nil {
      if !after_dash {
        self.PutIndent(indent);
      }

      let b: YamlBool = bv as YamlBool;
      if b.value {
        self.buf.Append("true");
      } else {
        self.buf.Append("false");
      }
    }

    return;
  }

  if node.node.holds<YamlInt>() {
    let iv: YamlInt? = node.node.get_if<YamlInt>();
    if iv != nil {
      if !after_dash {
        self.PutIndent(indent);
      }

      let n: YamlInt = iv as YamlInt;
      self.buf.Append(YamlI64Text(n.value));
    }

    return;
  }

  if node.node.holds<YamlStr>() {
    let sv: YamlStr? = node.node.get_if<YamlStr>();
    if sv != nil {
      if !after_dash {
        self.PutIndent(indent);
      }

      let s: YamlStr = sv as YamlStr;
      self.buf.Append(yaml_emit_scalar_text(copy(s.value)));
    }

    return;
  }

  if node.node.holds<YamlSeq>() {
    let seq: YamlSeq? = node.node.get_if<YamlSeq>();
    if seq != nil {
      self.EmitSeq(seq as YamlSeq, indent, after_dash);
    }

    return;
  }

  if node.node.holds<YamlMap>() {
    let map: YamlMap? = node.node.get_if<YamlMap>();
    if map != nil {
      self.EmitMap(map as YamlMap, indent, after_dash);
    }

    return;
  }

  if !after_dash {
    self.PutIndent(indent);
  }

  self.buf.Append("null");
}

/**
 * @brief Serialize `node` to toolchain-style block YAML (insertion-order maps).
 * @note Product entry is `YamlWriter.Emit` (yaml.md §0.4 / §1.5); this is the shared body.
 */
pub func YamlEmitText(node: Yaml) -> string {
  var em: YamlEmitter = YamlEmitter{buf: StringBuffer.NewWithCapacity(64)};
  em.EmitYaml(node, 0, false);
  em.buf.Append("\n");

  return em.buf.Take();
}

/**
 * @brief Compare YAML node kinds and scalar/collection contents recursively.
 * @returns True when both YAML trees match structurally and by value.
 */
pub func YamlTreesEqual(a: Yaml, b: Yaml) -> bool {
  return yaml_trees_equal(a, b);
}
