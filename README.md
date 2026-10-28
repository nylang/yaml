# yaml

Nyra YAML parser and document model. Import `yaml:yaml.ny`.

See [MIGRATION.md](MIGRATION.md) for source history and the current workspace
layout. Run the package suite from NyraLang with
`python3 nyra.py test --package yaml`. Test data is owned by this repository.

## Portable Git dependency

Source imports use the installed SDK's implicit runtime packages (SDK 1.0.2 or
later); package manifests contain no paths into the private compiler checkout.
For automatic Git preparation use native `nyra` 1.0.3 or later. That manager's
public SDK publication is separate from this package; SDK 1.0.2 does not ship it.
With SDK 1.0.2, a manual clone and explicit local consumer path remain usable.

Add this dependency to your application's `package.yaml`:

```yaml
dependencies:
  yaml:
    git: https://github.com/nylang/yaml.git
    rev: main
```

Then run `nyra lock ./app` and commit `nyra.lock`; use
`nyra fetch ./app --frozen` to prepare the pinned graph again. `main` above is
an initial selector; the lock fixes the exact commit/content. Normal compiler
and analyzer operations do not fetch dependencies. Historical tags are immutable
and may retain older workspace-specific manifests.

For local multi-package development, list package-file pointers in a common
`workspace.yaml`. Workspace replacements keep Git declarations shareable;
origin lock updates deliberately disable replacements. A package entry and its
SDK can move without rewriting publisher paths.

## License

Licensed under the [MIT License](LICENSE).
