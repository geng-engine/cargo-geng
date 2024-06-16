{ pkgs, lib, config, ... }: {
  options.rust = {
    dev = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
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
      default = [ ];
    };
    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    finalPackage = lib.mkOption {
      type = lib.types.package;
    };
  };
  config = {
    rust.extensions = lib.mkIf config.rust.dev [
      "rust-src"
      "rust-analyzer"
    ];
    rust.finalPackage = pkgs.rust-bin.${config.rust.toolchain-kind}.${config.rust.version}.default.override
      {
        extensions = config.rust.extensions;
        targets = config.rust.targets;
      };
    packages = [ config.rust.finalPackage ];
  };
}

