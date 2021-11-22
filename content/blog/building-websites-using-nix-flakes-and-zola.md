+++
title = "Building websites using Nix Flakes and Zola"
date = 2021-11-19
+++


### A quick first blog post introduction

Welcome! This is my new and only website, where I will share my finest thoughts and ideas.  
I have been procrastinating for a while about creating my own blog, but here it is! 🎉

#### I think it will only make sense if I start by showing how I *actually* build this website.  

### Nix
Nix is an extremely powerful tool, which I use all the time as a DevOps enthusiast. I mostly use Nix for building software and for managing my machines running NixOS; it's a GNU/Linux distribution that was made with Nix at it's core. It uses Nix to manage all of its system configuration. *I don't want the focus of this post to be about NixOS, so if you are interested in knowing more about NixOS, you can read more about it [here](https://nixos.org/manual/nixos/stable).*

For building this website, we make use of a new experimental feature in Nix called **Flakes**, whose main attraction for me is that it is pure and reproducible by default. Flakes are great because they're a standardized way to structure Nix-based projects. If you would like to learn more about Flakes, these are my go-to resources:
- Tweag's three-part series blog post - [1 - Introduction and tutorial](https://www.tweag.io/blog/2020-05-25-flakes), [2 - Evaluation caching](https://www.tweag.io/blog/2020-06-25-eval-cache), [3 - NixOS systems management](https://www.tweag.io/blog/2020-07-31-nixos-flakes)
- Eelco Dolstra's talk at NixCon 2019 - [Nix flakes (NixCon 2019)](https://youtu.be/UeBX7Ide5a0)
- Flakes' NixOS wiki page - [nixos.wiki/wiki/flakes](https://nixos.wiki/wiki/Flakes)

### Zola and static site generators

***My experience with SSGs is so little that you should probably take everything I say about them with a grain (bucket) of salt.***

My journey with SSGs started with Hugo. I have played around with Hugo to create a couple of fairly small sites for the sake of testing. I did not like some complexity of Hugo, like the many ways of managing "themes" and Go's HTML and text templating, so I started looking for new solution. I wanted something lightweight and minimal, so I can focus more on the actual content of the site; that's where Zola came into the picture. I read a bit about Zola and liked some of its features, like built-in syntax highlighting and Sass compilation, alongside that it has a nice command line interface and is also a single binary like Hugo, though with Hugo, if one decides to use Hugo "modules", they will also need to have Go installed.

### Writing the flake.nix

**The nixpkgs input:**  
When starting to write a flake for a new project that takes use of [nixpkgs](https://github.com/NixOS/nixpkgs), one should consider if they care about it using the latest software updates from the "unstable" branch or use the more thoroughly tested software updates from the "stable" branch. I personally avoid using the "master" branch since the changes in it haven't gone through the [Hydra](https://hydra.nixos.org) build system, so you wouldn't be able to use the provided binary cache, which means you'd have to compile/build the software on your local system. We can set the branch to use for nixpkgs by declaring the `nixpkgs` input in `flake.nix` like so:

```nix
inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
```

In the example above we declared to use the `nixpkgs-unstable` branch. You can read about the available branches/channels here → [nixos.wiki/wiki/nix_channels](https://nixos.wiki/wiki/Nix_channels).

**The flake-utils input:**  
In this flake we will also be using [flake-utils](https://github.com/numtide/flake-utils), which is a collection of pure Nix functions that don't depend on nixpkgs. They can be useful for writing other Nix flakes. We use one of its system related functions, `eachDefaultSystem` in this case. All this function does is populate the outputs with a list of all systems nixpkgs builds for. This is a simple and clean way to make a flake output buildable for many system types and architectures. It makes sense to use it here because, fortunately, Zola on nixpkgs builds for all the system types.

**The outputs:**  
Let's take a look at the outputs used in this flake:  

```nix
{
  packages.website = pkgs.stdenv.mkDerivation rec {
    pname = "static-website";
    version = "2021-11-19";
    src = ./.;
    nativeBuildInputs = [ pkgs.zola ];
    buildPhase = "zola build";
    installPhase = "cp -r public $out";
  };
  defaultPackage = self.packages.${system}.website;
  devShell = pkgs.mkShell {
    packages = with pkgs; [
      zola
    ];
  };
}
```

Starting with the `packages.website` output, this output builds a package called `website`. This package includes a derivation called `${pname}-${version}`, which in this case will just be `static-website-2021-11-19`. This derivation's `src` is the current directory, `./.` and it depends on the package `pkgs.zola`. Nix derivations are built using phases. The build phase here runs the command `zola build`, and the install phase runs the command `cp -r public $out`.
The end result will be that it builds the Zola site in the current directory and puts its generated contents in the `$out` directory, which by default is a symlink called `result` that's linked to the Nix store.

Now onto the `defaultPackage` output, this output is pretty simple. All it does is set the default output to get when running `nix build` to the output called `packages.website` that we just went over.

And finally, the `devShell` output, this is the output you will use to develop your website. What this output does is create a new shell environment with the package `pkgs.zola` inside it. In order to enter that shell you have to run `nix develop` in the root of the flake/repo.

### The complete flake.nix recipe
This is the complete flake.nix for the explanation we went over above.
You are more than welcome to use it for your own site.

```nix
{
  description = "A flake for developing and building my personal website";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.website = pkgs.stdenv.mkDerivation rec {
          pname = "static-website";
          version = "2021-11-19";
          src = ./.;
          nativeBuildInputs = [ pkgs.zola ];
          buildPhase = "zola build";
          installPhase = "cp -r public $out";
        };
        defaultPackage = self.packages.${system}.website;
        devShell = pkgs.mkShell {
          packages = with pkgs; [
            zola
          ];
        };
      }
    );
}
```

### But there is more! - Declarative Zola themes management
If you want to go **overkill** you can even manage your Zola themes declaratively as flake inputs. This is a bit more hacky than you might think. What we are doing here is actually adding another `src` of some sort into the build sandbox, in the configuration phase, right before the build phase. One of the things people always try to achieve when writing Nix code is making it as modular as possible. I tried to get it as modular as possible by writing a variable with the value of the theme name that is specified inside the theme's `theme.toml`. It was done by squashing together a couple of *fancy* built-in functions, `builtins.fromTOML` and `builtins.readFile`. These functions convert the TOML file into a Nix file and then grab the value of `name` inside.
```nix
themeName = ((builtins.fromTOML (builtins.readFile "${deepthought}/theme.toml")).name);
```
In the configuration phase, we create a directory (two actually, if you consider the parent one) that is named after the value of `${themeName}`, which we set before. Now a simple `cp -r` to copy the contents of the `deepthought` (the theme used in this case) flake input. This will make the theme available in the `sourceRoot`. For making development easier, we can add a shell hook to the `mkShell` , which will symlink the content of the theme's input to `themes/${themeName}` so we can use `zola serve` as normal.

The finished and only *slightly* **overkill** `flake.nix` is available below, and *anyone* is free to use it.

```nix
{
  description = "A flake for developing and building my personal website";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.deepthought = { url = "github:RatanShreshtha/DeepThought"; flake = false; };

  outputs = { self, nixpkgs, flake-utils, deepthought }:
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
          packages = [ pkgs.zola ];
          shellHook = ''
            mkdir -p themes
            ln -sn "${deepthought}" "themes/${themeName}"
          '';
        };
      }
    );
}
```

**And that's about it, thanks for reading my first ever blog post!**
