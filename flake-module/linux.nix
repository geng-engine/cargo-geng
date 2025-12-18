{ lib, config, pkgs, ... }:
let cfg = config.target.linux;
in
{
  options.target.linux = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true; # TODO based on system?
    };
    mold.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
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
      kdePackages.kdialog # for tinyfiledialogs
      openssl
      alsa-lib
      udev
      libGL
      pkg-config
    ];
    env = lib.mkIf cfg.mold.enable {
      CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "${pkgs.clang}/bin/clang";
      CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS = "-C link-arg=--ld-path=${pkgs.mold}/bin/mold";
    };
  };
}

