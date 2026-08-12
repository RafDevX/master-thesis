= Usage Instructions <usage>

The present appendix specifies how to use the Glowy static taint analyzer
Rust implementation.

Focus is put specifically on the `glowy-cli` tool, but detailed documentation
for the the underlying `glowy` library is available on the crate's `docs.rs`
page and is mirrored at #link("https://glowy.rso.pt").

== Installing

There are two alternative possible ways for installing Glowy: either directly
from `crates.io` (the Rust central package registry) or from the latest source
code in the public GitHub repository.

Both alternatives require Cargo to be installed.

=== Rust Package Registry

Run:

```
cargo install glowy-cli
```

The binary is made available at `~/.cargo/bin`, which should be added to `PATH`.

=== Building From Source

On a system with Git available, run:

```
git clone https://github.com/RafDevX/glowy
cd glowy
cargo build --release
```

The command `nix develop -f shell.nix` can be used to install the relevant
supporting programs if not already available, if Nix is.

== Analyzing Go Projects

After installing, run:

```
glowy-cli ./path/to/go/module/directory
```

Additional parameters and flags are available. Run `glowy-cli --help` to list
usage information.

== Running the Benchmarks Corpus

After installing, run:

```
glowy-cli --multi-suites ./ifc-benchmarks
```

The `--summary-only` flag can also be specified for more concise output.
