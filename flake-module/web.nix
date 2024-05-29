{
  perSystem = { lib, config, ... }:
    let cfg = config.geng.web;
    in
    {
      options.geng.web.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      config = lib.mkIf cfg.enable {
        geng.rust.targets = [ "wasm32-unknown-unknown" ];
      };
    };
}
