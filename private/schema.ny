// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Exposes YAML schema operations and borrows DOM nodes for a synchronous walk. */
import "interface/schema.ni";
import "public/yaml.ny";
import "schema:schema.ny";
import "stdlib:stdlib.ny";

/** @brief Compiled rules with a YAML entry point. */
pub struct YamlSchema {
  readonly rules: Schema;
}

pub static method(YamlSchema) Compile(rule: ref Yaml) -> Result<YamlSchema, SchemaError> {
  unsafe {
    let reader = YamlSchemaReader{root: &rule};
    let compiled = Schema.Compile(reader);
    if compiled.IsErr() {
      return Err<YamlSchema, SchemaError>(compiled.get_if<SchemaError>() as SchemaError);
    }

    return Ok<YamlSchema, SchemaError>(YamlSchema.FromCompiled(compiled.get_if<Schema>() as Schema));
  }
}

pub method(YamlSchema) Validate(value: ref Yaml) -> Result<Unit, SchemaError> {
  unsafe {
    let reader = YamlSchemaReader{root: &value};
    return (self.rules).Validate(reader);
  }
}

pub static method(YamlSchema) FromCompiled(rules: Schema) -> YamlSchema {
  return YamlSchema{rules: rules};
}

pub method(YamlSchema) Compiled() -> Schema {
  return self.rules;
}

// The caller retains the root and its collections through Compile or Validate.
struct YamlSchemaReader implements SchemaReader {
  readonly root: *const Yaml;
}

@override
method(YamlSchemaReader) Root() -> uintptr {
  return self.root as uintptr;
}

@override
method(YamlSchemaReader) Kind(node: uintptr) -> SchemaKind {
  unsafe {
    let value: *const Yaml = node as *const Yaml;
    if (*value).node.holds<YamlBool>() {
      return SchemaKind.Boolean;
    }

    if (*value).node.holds<YamlInt>() {
      return SchemaKind.Number;
    }

    if (*value).node.holds<YamlStr>() {
      return SchemaKind.String;
    }

    if (*value).node.holds<YamlSeq>() {
      return SchemaKind.Array;
    }

    if (*value).node.holds<YamlMap>() {
      return SchemaKind.Object;
    }
  }

  return SchemaKind.Null;
}

@override
method(YamlSchemaReader) Scalar(node: uintptr) -> SchemaScalar {
  unsafe {
    let value: *const Yaml = node as *const Yaml;
    let text: ref YamlStr? = (*value).node.get_ref_if<YamlStr>();
    if text != nil {
      return SchemaScalar{text: text!.value};
    }

    let number: ref YamlInt? = (*value).node.get_ref_if<YamlInt>();
    if number != nil {
      let signed: int64 = number!.value;
      if signed < 0i64 {
        return SchemaScalar{text: signed.ToString()};
      }

      return SchemaScalar{text: signed.ToString(), count: signed as uint64};
    }

    let boolean: ref YamlBool? = (*value).node.get_ref_if<YamlBool>();
    if boolean != nil {
      return SchemaScalar{boolean: boolean!.value};
    }
  }

  return SchemaScalar{};
}

@override
method(YamlSchemaReader) Len(node: uintptr) -> int32 {
  unsafe {
    let value: *const Yaml = node as *const Yaml;
    let items: ref YamlSeq? = (*value).node.get_ref_if<YamlSeq>();
    if items != nil {
      return items!.Len();
    }

    let entries: ref YamlMap? = (*value).node.get_ref_if<YamlMap>();
    if entries != nil {
      return entries!.Len();
    }
  }

  return 0;
}

@override
method(YamlSchemaReader) KeyAt(node: uintptr, index: int32) -> string {
  unsafe {
    let value: *const Yaml = node as *const Yaml;
    let entries: ref YamlMap? = (*value).node.get_ref_if<YamlMap>();
    if entries != nil {
      let item: *const YamlMapEntry = &entries!.entries.buf[index];
      return (*item).key;
    }
  }

  return "";
}

@override
method(YamlSchemaReader) ChildAt(node: uintptr, index: int32) -> uintptr {
  unsafe {
    let value: *const Yaml = node as *const Yaml;
    let items: ref YamlSeq? = (*value).node.get_ref_if<YamlSeq>();
    if items != nil {
      let item: *const Yaml = &items!.items.buf[index];
      return item as uintptr;
    }

    let entries: ref YamlMap? = (*value).node.get_ref_if<YamlMap>();
    if entries != nil {
      let item: *const YamlMapEntry = &entries!.entries.buf[index];
      let child: *const Yaml = &(*item).value;
      return child as uintptr;
    }
  }

  return 0up;
}
