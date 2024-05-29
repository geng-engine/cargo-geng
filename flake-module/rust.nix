{ inputs, ... }: {
  perSystem = { pkgs, lib, config, system, ... }: {
    options.geng.rust = {
      toolchain-kind = lib.mkOption {
        type = lib.types.enum [ "stable" "nightly" ];
        default = "stable";
      };
      version = lib.mkOption {
        type = lib.types.str;
        default = "latest";
      };
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "rust-src" ];
      };
      targets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "rust-src" ];
      };
      finalPackage = lib.mkOption {
        type = lib.types.package;
      };
    };
    config = {
      geng.rust.finalPackage = pkgs.rust-bin.${config.geng.rust.toolchain-kind}.${config.geng.rust.version}.default.override
        {
          extensions = config.geng.rust.extensions;
          targets = config.geng.rust.targets;
        };
    };
  };
}
