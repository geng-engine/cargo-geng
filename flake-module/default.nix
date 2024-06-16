{ lib, config, cargo-geng, ... }: {
  imports = [
    ./rust.nix
    ./linux.nix
    ./web.nix
    ./android.nix
    ./windows.nix
  ];
  options = {
    cargo-geng.package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = cargo-geng;
    };
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
  };
  config = {
    packages = lib.mkIf (!builtins.isNull config.cargo-geng.package) [ config.cargo-geng.package ];
  };
}
