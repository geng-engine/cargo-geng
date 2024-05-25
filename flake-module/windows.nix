{
  perSystem = { lib, config, ... }:
    let cfg = config.geng.windows;
    in
    {
      options.geng.windows.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      config = lib.mkIf cfg.enable {
        geng.rust.targets = [ "x86_64-pc-windows-gnu" ];
      };
    };
}
