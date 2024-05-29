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
      devenv.shells.default = {
        packages = [ config.geng.rust.finalPackage ];
      };
      formatter = pkgs.nixpkgs-fmt;
    };
  };
}
