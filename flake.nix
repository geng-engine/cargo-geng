{
  inputs = {
    # This must be the stable nixpkgs if you're running the app on a
    # stable NixOS install.  Mixing EGL library versions doesn't work.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    nix-filter.url = "github:numtide/nix-filter";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    crane-flake.url = "github:ipetkov/crane";
    android.url = "github:tadfisher/android-nixpkgs"; # TODO: unused?
  };

  outputs = { self, nixpkgs, systems, rust-overlay, crane-flake, ... }:
    let
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      forEachSystem = f: nixpkgs.lib.genAttrs (import systems) (system:
        let pkgs = pkgsFor system;
        in f system pkgs);
    in
    {
      lib = {
        mkEnv = config@{ system, ... }:
          let
            pkgs = pkgsFor system;
            configExtraModules = config.modules or [ ];
            configModule = {
              config = builtins.removeAttrs config [ "system" "modules" ];
            };
            crane = crane-flake.mkLib pkgs;
          in
          (pkgs.lib.evalModules {
            modules = [ ./flake-module configModule ] ++ configExtraModules;
            specialArgs = { inherit pkgs crane; };
          }).config;
        mkShell = config@{ system, ... }:
          let
            pkgs = pkgsFor system;
            shellModule = { rust.dev = true; };
            finalConfig = config // { modules = [ shellModule ] ++ config.modules or [ ]; };
            env = self.lib.mkEnv finalConfig;
          in
          pkgs.mkShell
            {
              packages = env.packages;
            } // env.env;
      };
      packages = forEachSystem (system: pkgs: {
        # TODO default = cargo-geng package
      });
      devShells = forEachSystem (system: pkgs: {
        default = self.lib.mkShell {
          inherit system;
          target.linux.enable = false; # we only develop cargo-geng itself, not games with geng
        };
        full = self.lib.mkShell {
          inherit system;
          target.linux.enable = true;
          target.web.enable = true;
          target.android.enable = true;
          target.windows.enable = true;
        };
      });
      formatter = forEachSystem (system: pkgs: pkgs.nixpkgs-fmt);
    };
}
