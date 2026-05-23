= Usage Instructions <usage>

appendix overview

this appendix about cli tool specifically, but
detailed documentation for the library is on docs.rs and mirrored on glowy.rso.pt

== Installing

2 different ways

=== Rust Package Registry

install directly from crates.io

ensure cargo+rustc stable >=1.91 and cc linker (usually installed via gcc package)

cargo install

have to make sure `~/.cargo/bin` is added to PATH

=== Building From Source

git clone

`nix develop -f shell.nix`, or ensure cargo+rustc stable >=1.91 and cc linker (usually installed via gcc package)

cargo build --release

== Analyzing Go Projects

...

you can use --time or wtv to time the actual analysis step (excluding or including parsing? define better)

== Running Validation Suites

for all of them, do: [cmd]

for only one of them, do: [cmd]

similarly to above, you can use --time or wtv

...
