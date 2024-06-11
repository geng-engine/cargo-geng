{ lib, inputs, config, ... }:
{
  options.geng = {
    populateFlake = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  config = lib.mkIf config.geng.populateFlake {
    systems = inputs.nixpkgs.lib.systems.flakeExposed;
    perSystem = { lib, pkgs, config, ... }: {
      geng.rust.extensions = [ "rust-analyzer" ];
      devenv.shells.default = {
        packages = config.geng.packages;
        env = config.geng.env;
      };
      formatter = pkgs.nixpkgs-fmt;
    };
  };
}
