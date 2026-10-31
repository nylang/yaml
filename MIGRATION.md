# Source provenance

Extracted with `git subtree split --prefix=source/yaml` from NyraLang
revision `697ee111dbde913641adcaffe31bc1107bd52254`. The extracted history ends
at `6dc6074f701fc7d612eee5c22597a6f662118669` before the independent-package migration commit.

At extraction, the manifests referenced a NyraLang workspace and relative SDK
source paths. That describes the historical extraction, not the current package
setup. Current development sources use the installed matching Nyra SDK's implicit
stdlib and ntest packages; no private compiler checkout is required.

For a portable application dependency, use the immutable public Git revision and
API migration notes in [README.md](README.md). Keep publisher Git declarations in
`package.yaml`; use local `workspace.yaml` package pointers for development
replacements. Commit the origin `nyra.lock` for reproducible fetches. Existing
historical tags keep their original manifests and compatibility requirements.
