{
  description = "A flake for developing and building my personal website";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs = { self, nixpkgs, deepthought, flake-compat, flake-compat-ci }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
      themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);
    in
    {
      packages = forAllSystems (system: {
        website = with nixpkgsFor.${system};
          stdenv.mkDerivation rec {
            pname = "static-website";
            version = "2021-11-19";
            src = ./.;
            nativeBuildInputs = [ zola ];
            configurePhase = ''
              mkdir -p "themes/${themeName}"
              cp -r ${deepthought}/* "themes/${themeName}"
            '';
            buildPhase = "zola build";
            installPhase = "cp -r public $out";
          };
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.website);

      devShell = forAllSystems (system: with nixpkgsFor.${system}; mkShell {
        packages = [ zola nodePackages.gramma ];
        shellHook = ''
          mkdir -p themes
          ln -sn "${deepthought}" "themes/${themeName}"
        '';
      });

      ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
        flake = self;
      };
    };
}
