{
  description = "A flake for developing and building my personal website";

  nixConfig.extra-substituters = [ "https://kranzes.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "kranzes.cachix.org-1:aZ9SqRdirTyygTRMfD95HMvIuzCoDcq2SmvNkaf9cnk=" ];

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };
    nix-filter.url = "github:numtide/nix-filter";
    hercules-ci-effects = { url = "github:hercules-ci/hercules-ci-effects"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, deepthought, nix-filter, hercules-ci-effects }:
    let
      version = builtins.substring 0 8 self.lastModifiedDate;
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
      themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);
      hci-effects = hercules-ci-effects.lib.withPkgs nixpkgs.legacyPackages.x86_64-linux;
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
          if [[ -d themes/${themeName} ]]; then
            true
          else
            ln -sn "${deepthought}" "themes/${themeName}"
          fi
        '';
      });

      effects = { branch, ... }: {
        netlify = hci-effects.runIf (branch == "master") (hci-effects.mkEffect {
          inputs = [ nixpkgs.legacyPackages.x86_64-linux.netlify-cli ];
          secretsMap.netlify = "default-netlify";
          NETLIFY_SITE_ID = "9d17ad40-c2f8-4933-b7d8-bb0ac30f0907";
          src = self.defaultPackage.x86_64-linux;
          effectScript = ''
            export NETLIFY_AUTH_TOKEN="$(readSecretString netlify .authToken)"
            netlify deploy --prod --dir=.
          '';
        });
      };
    };
}
