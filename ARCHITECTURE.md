# yaml module architecture

The public model and interface remain separate from syntax, event publication,
durable construction and output. This structure does not change the YAML grammar.

- `public/yaml.ny` owns node layouts and accessors, without parser or Writer parts.
- `private/lexical.ny` owns token kinds and plain-scalar classification shared by
  input scanning and output quoting. `YamlToken` lives here, below scanning,
  so classification never creates a lexical-to-scanner dependency cycle.
- `private/scalar.ny` owns scalar construction, UTF-8 conversion and quoted scalar
  formatting using the model and lexical contracts.
- `private/scan.ny` owns lexical scanning and token storage. Its result offers
  token, delimiter and diagnostic queries, borrowing source text only during parse.
- `private/parse.ny` owns a separate private document cursor and constructed map/seq
  state. It queries completed tokens through scanner operations; no token array or
  scanner source pointer is read directly. Reader obtains an owned tree through
  `YamlParseResult`, without seeing either mutable implementation state.
- `private/reader.ny` owns tree-to-Handler event publication and scratch copies.
- `private/document.ny` with `writer.ny` owns the durable DOM frame stack and event
  Writer. `YamlDomState` owns its stack/allocator policy; `YamlDomFrame` owns
  frame lifetime. Only this TU can inspect or initialize raw builder frame storage.
- `private/emit.ny` defines `YamlEmitter`, owning a buffer for one output;
  `Yaml.Equals` owns structural comparison.
- `private/dump.ny` owns diagnostic tree formatting, independent of grammar input
  and durable frame allocation.

Reader depends on syntax operations. DOM depends on Reader events and encoding.
Emission and diagnostic formatting share scalar formatting, rather than importing
one another's mutable implementation. Scanner and poisoned-allocation unit checks
remain beside the private state they inspect. Product/corpus tests form a separate
selftest TU. Internal syntax/debug helpers are not added to the product barrel.

Public projections, equality and canonical output belong to `Yaml`; scalar
encoding belongs to `YamlStr` and checked integer parsing to `YamlI64Parse`.
Integer output and scratch string copies use shared runtime capabilities.
`YamlFixture` owns test path/identity and fixture operations. The public source
migration removes old aliases and requires matching 1.0.5 kernel/stdlib plus a
consumer rebuild. The parent focused receipt is
`docs/roadmaps/m_v1.0.5/yaml-owner-refactor.json` (82 macOS arm64 tests).
