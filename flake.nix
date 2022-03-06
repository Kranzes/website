{
  description = "A flake for developing and building my personal website";

  nixConfig.extra-substituters = [ "https://kranzes.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "kranzes.cachix.org-1:aZ9SqRdirTyygTRMfD95HMvIuzCoDcq2SmvNkaf9cnk=" ];

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, nixpkgs, deepthought, nix-filter }:
    let
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";
      version = builtins.substring 0 8 lastModifiedDate;
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
      themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);
    in
    {
      packages = forAllSystems (system: {
        website = pkgs.${system}.stdenvNoCC.mkDerivation rec {
          pname = "static-website";
          inherit version;
          src = nix-filter.lib {
            root = self;
            include = [
              (nix-filter.lib.inDirectory "content")
              (nix-filter.lib.inDirectory "static")
              "config.toml"
            ];
          };
          nativeBuildInputs = [ pkgs.${system}.zola ];
          configurePhase = ''
            mkdir -p "themes/${themeName}"
            cp -r ${deepthought}/* "themes/${themeName}"
          '';
          buildPhase = "zola build";
          installPhase = "cp -r public $out";
        };
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.website);

      devShell = forAllSystems (system: pkgs.${system}.mkShell {
        packages = with pkgs.${system}; [ zola nodePackages.gramma ];
        shellHook = ''
          mkdir -p themes
          ln -sn "${deepthought}" "themes/${themeName}"
        '';
      });

    };
}
