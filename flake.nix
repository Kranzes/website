{
  description = "A flake for developing and building my personal website";

  nixConfig.extra-substituters = [ "https://kranzes.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "kranzes.cachix.org-1:aZ9SqRdirTyygTRMfD95HMvIuzCoDcq2SmvNkaf9cnk=" ];

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };
    nix-filter.url = "github:numtide/nix-filter";
    hercules-ci-effects = { url = "github:kranzes/hercules-ci-effects"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, deepthought, nix-filter, hercules-ci-effects }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      version = builtins.substring 0 8 self.lastModifiedDate;
      hci-effects = hercules-ci-effects.lib.withPkgs pkgs;
      themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);
    in
    {
      packages.${system}.website = pkgs.stdenvNoCC.mkDerivation {
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
        nativeBuildInputs = [ pkgs.zola ];
        configurePhase = ''
          mkdir -p "themes/${themeName}"
          cp -r ${deepthought}/* "themes/${themeName}"
        '';
        buildPhase = "zola build";
        installPhase = "cp -r public $out";
      };

      defaultPackage.${system} = self.packages.${system}.website;

      devShell.${system} = pkgs.mkShell {
        packages = with pkgs; [ zola nodePackages.gramma ];
        shellHook = ''
          mkdir -p themes
          if [[ -d themes/${themeName} ]]; then
            true
          else
            ln -sn "${deepthought}" "themes/${themeName}"
          fi
        '';
      };

      effects = { branch, ... }: {
        netlify = hci-effects.runIf (branch == "master") (hci-effects.netlifyDeploy {
          websitePackage = self.defaultPackage.${system};
          secretName = "default-netlify";
          secretData = "authToken";
          siteId = "9d17ad40-c2f8-4933-b7d8-bb0ac30f0907";
          productionDeployment = true;
        });
      };
    };
}
