{
  description = "Nixify-Jsparser";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # GENERAL
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = system: nixpkgs.legacyPackages.${system};
      jsparser = rec {
        projectFor =
          system:
          let
            pkgs = nixpkgsFor system;

            project = pkgs.buildNpmPackage {
              pname = "jsparser";
              version = "0.1.0";
              src = ./.;
              npmDepsHash = "sha256-JuJ537/FT4HJ63suyxZOsHMK5gBr0n8qe0i0Wip3oKE=";

              # Allow network access during build
              npmFlags = [ "--legacy-peer-deps" ];

              # We need makeWrapper to create a proper executable wrapper
              nativeBuildInputs = [ pkgs.makeWrapper ];

              # Disable npm scripts that try to modify the file system outside of build dirs
              dontNpmBuild = true;

              # Custom npm build steps
              # npmBuildScript = ''npm run build'';

              # Define output package bin with proper NODE_PATH
              installPhase = ''
                # Create lib directory structure
                mkdir -p $out/lib/node_modules/jsparser

                # Copy dependencies
                cp -r node_modules $out/lib/node_modules/jsparser/

                # Copy script
                mkdir -p $out/bin
                cp jsparser $out/bin/jsparser.js

                # Create wrapper with proper NODE_PATH
                makeWrapper ${pkgs.nodejs}/bin/node $out/bin/jsparser \
                  --add-flags "$out/bin/jsparser.js" \
                  --set NODE_PATH "$out/lib/node_modules/jsparser/node_modules"
              '';

              meta = {
                description = "JavaScript parser for differential analysis";
                homepage = "https://github.com/lllssskkk/jsparser";
                license = pkgs.lib.licenses.mit;
                platforms = pkgs.lib.platforms.unix;
              };
            };
          in
          project;
      };
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = nixpkgsFor system;
      in
      {
        # Development shell
        devShells.default = jsparser.projectFor system;
        # Main package
        packages.default = jsparser.projectFor system;
        # Application - direct executable access
        apps.default = {
          type = "app";
          program = "${jsparser.projectFor system}/bin/jsparser";
        };
        # Application - run with example
        apps.example = {
          type = "app";
          program = "${pkgs.nodePackages.nodejs}/bin/node";
          args = [
            "${./jsparser}"
            "${./example.js}"
          ];
        };
      }
    );
}
