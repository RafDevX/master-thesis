#import "../utils/dependencies.typ": codly

#import codly: codly

#codly(number-format: none)

= Usage Instructions <usage>

The present appendix specifies how to install and use the developed Rust
implementation for the Glowy static taint analyzer described in this report.

Focus is put specifically on the `glowy-cli` tool, but detailed documentation
for the underlying `glowy` library is available on the crate's `docs.rs`
page#footnote(link("https://docs.rs/glowy")) and is mirrored at
#link("https://glowy.rso.pt").

== Installing

There are two alternative possible ways for installing Glowy: either directly
from `crates.io` (the Rust central package registry) or from the latest source
code revision tracked in the public GitHub repository.

Both alternatives need a sufficiently-recent version of Cargo to be available
#footnote(link("https://rust-lang.org/tools/install")) on the target system. A
minimum Rust version of 1.91 is required for artifact compilation, and a `cc`
linker must also be present#footnote[Usually a symbolic link pointing to either
  of `gcc` or `clang`, depending on the @os, and automatically created upon
  their installation.].

After installation (as described on the following page, depending on the
selected method), the compiled binary is made available in Cargo's output
directory, which defaults to `~/.cargo/bin`. To support direct invocation, this
referenced directory should be added to the `PATH` environment variable, using a
command such as:

```sh
export PATH="$PATH:$HOME/.cargo/bin"
```

This appends the Cargo binaries directory to the configured lookup path. In
order to avoid running the command above every time Glowy is to be used, it can
be added to the shell's startup script, such as `~/.bashrc` or `~/.zshrc`.

=== Rust Package Registry

This is the simplest option and the recommended method of installation for
Glowy, not only due to its convenience but also because it automatically selects
the latest stable release available, rather than whichever is the most recent
development version (not necessarily stable).

Using a command-line shell, simply run the command:

```sh
cargo install glowy-cli
```

This instructs the Cargo package manager to query `crates.io` (by default),
download all necessary data for `glowy-cli` and its recursive dependencies, and
build a final executable.

=== Building From Source

Otherwise, especially if the absolute most recent software revision is
necessary, it is possible to manually download Glowy's source code and build an
executable from the corresponding source directory.

Glowy uses Git for version control management and hosts its source code in a
public GitHub repository#footnote(link("https://github.com/RafDevX/glowy")), so
on a system with Git already available
#footnote(link("https://git-scm.com/install")), run:

```sh
git clone https://github.com/RafDevX/glowy
cd glowy
cargo install --path .
```

Prior to the third command, `git` may optionally be used to select a specific
commit by checking out an arbitrary repository revision from its history.

A `flake.nix` file is provided, defining `glowy-cli` as its default package and
providing a development shell with all relevant external dependencies and setup
steps. This means that on systems with Nix#footnote(link("https://nixos.org"))
available, one can conveniently install Cargo, GCC, and other tooling all at
once by running ```sh nix develop```. The entire binary can also be compiled and
run using ```sh nix run```.

It should be noted, however, that Nix is not required for installing nor for
running Glowy, with the `flake.nix` file being included just to assist users
already using Nix, especially on NixOS systems.

== Analyzing Go Projects

After installing Glowy, a Go module can easily be analyzed by means of running
the shell command:

```sh
glowy-cli ./path/to/go/module/directory
```

The path should point to the module root, where `go.mod` is located. Often,
Glowy is invoked directly from the module's root, so ```sh glowy-cli .``` is
used.

Additional parameters and flags are available. Run ```sh glowy-cli --help``` to
list usage information. The following options are available for the default
command (analysis):
- ```sh --strict```: upgrade all warnings to errors before reporting them;
- ```sh --context-lines N```: how many source-code lines to show for context
  before and after error snippet annotations (defaults to $1$);
- ```sh --suite```: analyze a directory of directories containing Go modules,
  instead of just one module overall;
- ```sh --multi-suites```: analyze multiple suites, i.e., several directories of
  directories containing Go modules;
- ```sh --summary-only```: omit per-module output when analyzing multiple Go
  modules; and
- ```sh --time-analysis```: report elapsed time for the entire analysis process,
  including parsing.

The other command provided is ```sh glowy-cli base-security-policy```, which
writes to standard output the analyzer's built-in Base Security Policy. This
policy can be exported into an editable `glowy.toml` template using the command
```sh glowy-cli base-security-policy --eject```.

== Running the Benchmarks Corpus

The correctness benchmarks corpus is included alongside the Rust source code,
in the `./ifc-benchmarks` directory. After installing Glowy and cloning its
Git repository, run from the latter's root:

```sh
glowy-cli --multi-suites ./ifc-benchmarks
```

This instructs the @cli application to analyze all benchmark modules in each of
the corpus's suites. In addition, the ```sh --summary-only``` flag can also be
specified in order to obtain more concise output.
