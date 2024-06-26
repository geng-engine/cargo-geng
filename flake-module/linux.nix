{ lib, config, pkgs, ... }:
let cfg = config.target.linux;
in
{
  options.target.linux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true; # TODO based on system?
    };
  };
  config = lib.mkIf cfg.enable {
    rust.targets = [ "x86_64-unknown-linux-gnu" ];
    packages = with pkgs; [
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
}

