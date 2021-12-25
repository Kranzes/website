{
  description = "A flake for developing and building my personal website";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs = { self, nixpkgs, flake-utils, deepthought, flake-compat, flake-compat-ci }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);
      in
      {
        packages.website = pkgs.stdenv.mkDerivation rec {
          pname = "static-website";
          version = "2021-11-19";
          src = ./.;
          nativeBuildInputs = [ pkgs.zola ];
          configurePhase = ''
            mkdir -p "themes/${themeName}"
            cp -r ${deepthought}/* "themes/${themeName}"
          '';
          buildPhase = "zola build";
          installPhase = "cp -r public $out";
        };

        defaultPackage = self.packages.${system}.website;

        devShell = pkgs.mkShell {
          packages = with pkgs; [ zola nodePackages.gramma ];
          shellHook = ''
            mkdir -p themes
            ln -sn "${deepthought}" "themes/${themeName}"
          '';
        };

        ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
          flake = self;
        };
      }
    );
}
