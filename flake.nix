{
  inputs = {
    # This must be the stable nixpkgs if you're running the app on a
    # stable NixOS install.  Mixing EGL library versions doesn't work.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    crane-flake.url = "github:ipetkov/crane";
    android.url = "github:tadfisher/android-nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ flake-parts-lib, withSystem, ... }:
      let
        flakeModule = flake-parts.lib.importApply ./flake-module { localFlake = inputs.self; inherit withSystem; };
      in
      {
        imports = [
          inputs.devenv.flakeModule
          flakeModule
        ];
        geng.populateFlake = true;
        flake.flakeModule = flakeModule;
        perSystem = { config, pkgs, system, ... }: {
          geng = {
            web.enable = true;
            linux.enable = true;
            android.enable = true;
            windows.enable = true;
          };
        };
      }
    );
}
