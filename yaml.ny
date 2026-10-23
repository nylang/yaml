/**
 * @brief Sole public entry for package `yaml` — Handler/Reader/Document/Writer + DOM.
 * @note External importers use `import "yaml:yaml.ny";` only. Import `stdlib:stdlib.ny` only (no source/stdlib/private).
 * @note ADR 0013 — product `export` is interface + public (no free Parse/ParseFile/Emit).
 * @see docs/design/compiler/yaml.md
 */

export "interface/yaml.ni";
export "public/yaml.ny";
import "interface/yaml.ni";
import "public/yaml.ny";
