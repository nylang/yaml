# YAML corpus and goldens

`corpus/` holds canonical source inputs and `dumps/` holds deliberate expected
trees. The `design/` and `negative/` corpus entries also serve the examples in
the NyraLang YAML contract (`docs/design/compiler/yaml.md`). The former copies
under `docs/design/compiler/yaml-corpus/` were byte-identical and removed during
0.40 documentation cleanup. Keep one canonical copy here.

The optional Go oracle's source inventory reads these inputs directly; the
native package fixtures already use this corpus. Do not store generated
investigation output beside the goldens.
