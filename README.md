# yaml

Development API 0.19.0 requires a matching Nyra SDK 1.0.5 or newer.
Rebuild precompiled consumers against the matching interfaces and runtime.

Nyra YAML parser and document model. Import `yaml:yaml.ny`.

See [MIGRATION.md](MIGRATION.md) for source history and the current workspace
layout. Run the package suite from NyraLang with
`python3 nyra.py test --package yaml`. Test data is owned by this repository.

## Portable Git dependency

This working API requires matching Nyra SDK 1.0.5 compiler, runtime and analyzer
capabilities. Its manifest uses implicit SDK packages and contains no paths into
the private compiler checkout. Use the SDK's native `nyra` for Git preparation.
Older source tags retain their documented SDK requirements; they do not qualify
this development API. SDK/package publication remains a separate operation.

Add this dependency to your application's `package.yaml`:

```yaml
dependencies:
  yaml:
    git: https://github.com/nylang/yaml.git
    rev: d072294555cc8184b12d24253abcff1da5fdbd13
```

Run `nyra lock ./app` and commit `nyra.lock`; use
`nyra fetch ./app --frozen` to prepare the same graph again. The example pins
an existing public development commit whose API matches this source. It does
not select the older stable `main` or claim a newly published package tag.
Normal compiler and analyzer operations do not fetch dependencies.

For local multi-package development, list package-file pointers in a common
`workspace.yaml`. Workspace replacements keep Git declarations shareable;
origin lock updates deliberately disable replacements. A package entry and its
SDK can move without rewriting publisher paths.

## License

Licensed under the [MIT License](LICENSE).

## Module architecture

See [module responsibilities, ownership and dependency boundaries](ARCHITECTURE.md).

## Coding-rule lint

`package.yaml` selects the portable `lint.yaml` profile. It requires the
1.0.5 P7 analyzer candidate (or a later SDK containing those rules); the
published 1.0.4 analyzer does not implement them. `import: default` inherits
the selected workspace profile when present, otherwise analyzer SDK defaults.
No sibling source path is required. Run `nyra-analyzer lint . --json`. Lint checks
coding rules; runtime qualification is a separate gate.

## 1.0.5 source API migration

This working source requires the 1.0.5 kernel capabilities (checked string byte
access and allocator-owned string views); it is not compatible with an unchanged
1.0.4 SDK. No new package tag or release is claimed. Rebuild precompiled users
with matching interfaces and runtime objects. Required native test/ABI entry
points remain free declarations; product and implementation operations now use
real value, cursor, writer and DOM-state owners. No legacy API alias is retained.

Use `node.AsInt()` / `AsMap()` / `AsSeq()`, `left.Equals(right)` and
`node.CanonicalDump()` instead of YamlAs*, YamlTreesEqual and YamlCanonicalDump.
YamlReader/Document/Writer retain their existing public parse/event/emit surface.
Internal syntax operations remain outside the product barrel. Token vocabulary
now lives in the lower lexical module; parser and scanner cursors remain private.
