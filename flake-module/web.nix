{ lib, config, ... }:
let cfg = config.target.web;
in
{
  options.target.web.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  config = lib.mkIf cfg.enable {
    rust.targets = [ "wasm32-unknown-unknown" ];
  };
}
