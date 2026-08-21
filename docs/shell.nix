{
  pkgs ? (import <nixpkgs> { }),
  unstable ? (import <unstable> { }),
}:
pkgs.mkShellNoCC {
  buildInputs = with pkgs; [
    unstable.typst
    unstable.typstyle
    poppler-utils # for pdfinfo, to see metadata
    figtree # font
    pdfpc
  ];

  shellHook = ''
    export TYPST_FONT_PATHS="${pkgs.figtree}/share/fonts/truetype"
  '';
}
