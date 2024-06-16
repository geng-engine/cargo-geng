{ lib, config, ... }:
let cfg = config.target.windows;
in
{
  options.target.windows.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  config = lib.mkIf cfg.enable {
    rust.targets = [ "x86_64-pc-windows-gnu" ];
  };
}
