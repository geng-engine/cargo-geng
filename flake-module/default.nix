{ localFlake, ... }:
toplevel@ { lib, ... }: {
  imports = [
    ./populate.nix
    ./rust.nix
    ./linux.nix
    ./web.nix
    ./android.nix
    ./windows.nix
  ];
  config = {
    perSystem = { system, pkgs, lib, config, ... }: {
      options.geng = {
        packages = lib.mkOption {
          # TODO buildInputs/nativeBuildInputs?
          type = lib.types.listOf lib.types.package;
          description = "list of dependencies";
          default = [ ];
        };
        env = lib.mkOption {
          # TODO figure out what this means KEKW
          # https://github.com/cachix/devenv/blob/main/src/modules/top-level.nix
          type = lib.types.submoduleWith {
            modules = [
              (env: {
                config._module.freeformType = lib.types.lazyAttrsOf lib.types.anything;
              })
            ];
          };
          description = "Environment variables";
          default = { };
        };
        lib = lib.mkOption {
          type = lib.types.anything;
          default = {
            flake = localFlake;
            crane = localFlake.inputs.crane-flake.mkLib pkgs;
          };
        };
      };
      config = {
        _module.args.pkgs = import toplevel.inputs.nixpkgs {
          inherit system;
          overlays = [
            (import localFlake.inputs.rust-overlay)
          ];
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
      };
    };
  };
}
