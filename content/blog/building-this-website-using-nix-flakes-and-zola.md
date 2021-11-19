
+++
title = "Building this website using Nix Flakes and Zola"
date = 2021-11-19
+++


### A quick first blog post introduction

Welcome, this is my new and only website where I will share my finest thoughts and ideas,  
I have been procrastinating for a while about creating my own blog, so here it is! 🎉

#### I think it will only make sense if I start by showing how I *actually* build this website.  

### Nix
Nix is an extremely powerful tool which I use all the time as DevOps enthusiast, I mostly use Nix for building software and for managing my machines running NixOS; it's a GNU/Linux distribution that was made with Nix at it's core, it uses Nix to manage all of it's system configuration. *I don't want the focus of this post to be about NixOS, so if you are interested in knowing more about NixOS you can read more about it [here](https://nixos.org/manual/nixos/stable).*

For building this website I use one of the new experimental features in Nix, **Flakes**, it's main attraction me is that it is pure and reproducible by default. Flakes are great because they're a standardized way to structure Nix-based projects. If you would like to learn more about Flakes, these are my go-to resources:
- Tweag's three-part series blog posts - [1 - Introduction and tutorial](https://www.tweag.io/blog/2020-05-25-flakes), [2 - Evaluation caching](https://www.tweag.io/blog/2020-06-25-eval-cache), [3 - NixOS systems management](https://www.tweag.io/blog/2020-07-31-nixos-flakes)
- Eelco Dolstra's talk at NixCon 2019 - [Nix flakes (NixCon 2019)](https://youtu.be/UeBX7Ide5a0)
- Flakes' NixOS wiki page - [nixos.wiki/wiki/flakes](https://nixos.wiki/wiki/Flakes)

### Zola and static site generators
***My experience with SSGs is so little that you should probably take everything I say about them with a grain (bucket) of salt.***

My journey with SSGs started with Hugo, I used have played around with Hugo to create a couple of fairly small sites for the sake of testing, I did not like some of the complexity of Hugo like the many ways of managing "themes" and Go's html and text templating, so I started looking for new solution, I wanted something lightweight and minimal so I can focus more on the actual content of the site; that's where Zola came into the picture, I read a bit about Zola and liked some of it's features, like built-in syntax highlighting and Sass compilation, alongside that it has a nice command line interface and is also a single binary like Hugo, though with Hugo, if you use Hugo "modules" you will also need to have Go installed.

### Writing the flake.nix

**The nixpkgs input:**  
When I start writing a flake for a new project that takes use of [nixpkgs](https://github.com/NixOS/nixpkgs) I ask myself if I care about it using the latest software updates from the "unstable" branch or use the more thoroughly tested software versions from the "stable" branch.  

Avoid using the "master" branch since it hasn't gone through the [Hydra](https://hydra.nixos.org) build system so you wouldn't be able to use the binary cache, which means you'd have to compile/build the software on your local system.

To set the branch to use for nixpkgs by declaring the "nixpkgs" input in `flake.nix` like so:
```nix
inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
```
In the example above I declared to use the `nixpkgs-unstable` branch, you can read about the available branches/channels here → [nixos.wiki/wiki/nix_channels](https://nixos.wiki/wiki/Nix_channels).

**The flake-utils input:**  
In this flake I also used [flake-utils](https://github.com/numtide/flake-utils) which is a collection of pure Nix functions that dont depend on nixpkgs. They can be useful for writing other Nix flakes, I used one of it's system related functions, `eachDefaultSystem` in this case, all this function does is populates the outputs with a list of all systems nixpkgs builds for, this is a simple and clean way to make a flake output buildable for many system types and architectures, I checked that it makes sense to use it here by seeing which systems Zola on nixpkgs builds to, by looking at Zola's Nix expression I can see that it builds for all systems available, so it makes sense to use that function here.


**The outputs:**  
Let's take a look at the outputs used in this flake:  
```nix
{
  packages.website = pkgs.stdenv.mkDerivation rec {
    pname = "static-website";
    version = "2021-11-19";
    src = ./.;
    buildInputs = [ pkgs.zola ];
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
I'll start with the `packages.website` output, this output builds a package called `website`, this package includes a derivation called `${pname}-${version}`, which in this case will just be `static-website-2021-11-19`.  

This derivation's src is the current directory, `./.` and it depends on the package `pkgs.zola`.  

The Nix derivations are built using phases, the build phase here runs the command `zola build`, and the install phase runs the command `cp -r public $out`.  

This end result will be that it builds the Zola site in the current directory and put it's generated contents in the `$out` directory, which by default is a symlink called `result` and it's linked to the Nix store.

Now onto the `defaultPackage` output, this output is pretty simple, all it does is set the default output to get when running `nix build` to the output called `packages.website` that we just went over.

And finally, the `devShell` output, this is the output I use to develop this website, all this output does is create a new shell environment with the package `pkgs.zola` inside of it, in order to enter that shell you have to run `nix develop` in the root of the flake/repo.

### The complete flake.nix recipe
The complete flake.nix for this site looks like this:
```nix
{
  description = "A flake for developing and building my personal website";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in
      {
        packages.website = pkgs.stdenv.mkDerivation rec {
          pname = "static-website";
          version = "2021-11-19";
          src = ./.;
          buildInputs = [ pkgs.zola ];
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
