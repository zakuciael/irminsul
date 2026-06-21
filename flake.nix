{
  description = "Irminsul is a utility to extract data from Genshin Impact and export it for use with Genshin Optimizer, and other websites.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      debug = true;

      perSystem =
        {
          pkgs,
          inputs',
          ...
        }:
        let
          toolchain = inputs'.fenix.packages.combine (
            with inputs'.fenix.packages.complete;
            [
              cargo
              clippy
              rust-analyzer
              rust-src
              rustc
              rustfmt
            ]
          );

          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;

          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter =
              path: type:
              (craneLib.filterCargoSources path type)
              || (builtins.match ".*/keys/.*" path != null)
              || (builtins.match ".*/assets/.*" path != null);
          };

          desktopItem = pkgs.makeDesktopItem {
            name = "irminsul";
            exec = "irminsul";
            icon = "irminsul";
            desktopName = "Irminsul";
            comment = "Genshin Impact data extractor for Genshin Optimizer";
            startupWMClass = "irminsul";
            categories = [
              "Game"
              "Utility"
            ];
          };

          commonArgs = {
            inherit src;
            strictDeps = true;

            nativeBuildInputs = with pkgs; [
              autoPatchelfHook
              pkg-config
            ];

            buildInputs = with pkgs; [
              libGL
              libpcap
              libxkbcommon
              openssl
              stdenv.cc.cc.lib
              wayland
              libX11
              libXcursor
              libXi
              libXrandr
            ];
          };

          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          irminsul = craneLib.buildPackage (
            commonArgs
            // {
              inherit cargoArtifacts;
              nativeBuildInputs = commonArgs.nativeBuildInputs ++ (with pkgs; [
                copyDesktopItems
                makeWrapper
              ]);
              desktopItems = [ desktopItem ];
              RELEASE_BUILD = "1";

              postInstall = ''
                install -Dm644 assets/icon-256.png \
                  $out/share/icons/hicolor/256x256/apps/irminsul.png
                wrapProgram $out/bin/irminsul \
                  --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath (with pkgs; [ libGL libxkbcommon wayland ])}
              '';

              meta = with pkgs.lib; {
                description = "Genshin Impact data extractor using packet capture for use with Genshin Optimizer";
                homepage = "https://github.com/zakuciael/irminsul";
                license = licenses.mit;
                maintainers = [ ];
                mainProgram = "irminsul";
                platforms = [ "x86_64-linux" ];
              };
            }
          );
        in
        {
          packages.default = irminsul;

          devShells.default = pkgs.mkShell {
            inputsFrom = [ irminsul ];
            packages = [ toolchain ];

            RUST_SRC_PATH = "${inputs'.fenix.packages.complete.rust-src}/lib/rustlib/src/rust/library";

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
              with pkgs;
              [
                libGL
                libxkbcommon
                openssl
                stdenv.cc.cc.lib
                wayland
                libpcap
              ]
            );
          };
        };

      flake = {
        nixosModules.default = import ./nix/nixos-module.nix inputs.self;
      };
    };
}
