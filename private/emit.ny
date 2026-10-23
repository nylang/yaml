/**
 * @brief Canonical block YAML emit (yaml.md §1.5).
 * @note Same TU as `Yaml` layouts so `holds` / `get_if` on `Yaml.node` resolve.
 */
part of YamlTypes;

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
    if !yaml_plain_char(yaml_parse_byte(s, i)) {
      return false;
    }
    i = i + 1;
  }
  if (s == "-") {
    return false;
  }
  let k: int32 = yaml_classify_plain(s);
  if k == kYamlTokNull {
    return false;
  }
  if k == kYamlTokBool {
    return false;
  }
  return k != kYamlTokInt;
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
    return yaml_utf8_cp(48 + d);
  }
  return yaml_utf8_cp(87 + d);
}

func yaml_u00(b: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(6);
  buf.Append("\\u00");
  buf.Append(yaml_hex_char((b / 16) & 15));
  buf.Append(yaml_hex_char(b & 15));
  return buf.Take();
}

func yaml_emit_quote(s: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(s.length + 2);
  buf.Append("\"");
  var i: int32 = 0;
  let n: int32 = s.length;
  while i < n {
    let b: int32 = yaml_parse_byte(s, i);
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

func yaml_emit_scalar_text(s: string) -> string {
  if yaml_emit_plain_ok(s) {
    return s;
  }
  return yaml_emit_quote(s);
}

func yaml_i64_text(v: int64) -> string {
  if v == (0 as int64) {
    return "0";
  }
  let min64: int64 = (0 as int64) - (9223372036854775807 as int64) - (1 as int64);
  if v == min64 {
    return "-9223372036854775808";
  }
  var neg: bool = v < (0 as int64);
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
    memcpy(dest, (&ch) as *const uint8, 1 as uintptr);
    pos = pos - 1;
    tmp = tmp / ten;
  }
  if neg {
    var minus: uint8 = 45 as uint8;
    memcpy(p, (&minus) as *const uint8, 1 as uintptr);
  }
  return out;
}

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
        if !yaml_trees_equal((*pa), (*pb)) {
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
        if !yaml_trees_equal((*ea).value, (*eb).value) {
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
      self.buf.Append(yaml_i64_text(n.value));
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
func yaml_emit_text(node: Yaml) -> string {
  var em: YamlEmitter = YamlEmitter{ buf: StringBuffer.NewWithCapacity(64) };
  em.EmitYaml(node, 0, false);
  em.buf.Append("\n");
  return em.buf.Take();
}

pub func YamlTreesEqual(a: Yaml, b: Yaml) -> bool {
  return yaml_trees_equal(a, b);
}
