{
  perSystem = { lib, config, pkgs, ... }:
    let cfg = config.geng.linux;
    in
    {
      options.geng.linux = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true; # TODO based on system?
        };
      };
      config = lib.mkIf cfg.enable {
        geng.rust.targets = [ "wasm32-unknown-unknown" ];
        devenv.shells.default.packages = with pkgs; [
          libxkbcommon
          wayland
          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
          xorg.libxcb
          kdialog # for tinyfiledialogs
          openssl
          alsa-lib
          udev
          libGL
          pkg-config
        ];
      };
    };
}
