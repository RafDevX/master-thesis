{
  lib,
  rustPlatform,
  pkg-config,
}:
rustPlatform.buildRustPackage {
  pname = "glowy-eval";
  version = "1.0.0";

  nativeBuildInputs = [ pkg-config ];

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "Evaluation orchestrator for Glowy analysis of real-world Go projects";
    homepage = "https://github.com/RafDevX/master-thesis";
    license = licenses.mit;
    mainProgram = "glowy-eval";
  };
}
