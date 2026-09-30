{ pkgs, ... }:

let
  pnpm = pkgs.pnpm_10;
in
pkgs.stdenv.mkDerivation rec {
  pname = "free-coding-models";
  version = "0.5.97";

  src = pkgs.fetchFromGitHub {
    owner = "vava-nessa";
    repo = "free-coding-models";
    rev = "v${version}";
    hash = "sha256-1jjEBKoNUslrJEDNuqEQ7dHHiecJ3urOdH7MRrdhD1E=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pkgs.makeWrapper
    pkgs.pnpmConfigHook
    pnpm
  ];

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit pname version src pnpm;

    fetcherVersion = 4;

    hash = "sha256-TYOXu2XAdoLqbJPB8idemkWcxahs4+Z6UXAnh3+C47o=";
  };

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/free-coding-models
    cp -r . $out/lib/node_modules/free-coding-models

    mkdir -p $out/bin
    ln -s $out/lib/node_modules/free-coding-models/bin/free-coding-models.js \
      $out/bin/free-coding-models

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/free-coding-models \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs ]}
  '';

  meta = {
    description = "Find, benchmark and install free coding LLM models";
    homepage = "https://github.com/vava-nessa/free-coding-models";
    license = pkgs.lib.licenses.mit;
    mainProgram = "free-coding-models";
  };
}
