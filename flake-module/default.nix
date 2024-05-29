{ localFlake, ... }:
toplevel@ { lib, ... }: {
  imports = [
    ./populate.nix
    ./rust.nix
    ./linux.nix
    ./web.nix
    ./android.nix
    ./windows.nix
  ];
  config = {
    perSystem = { system, lib, config, ... }: {
      config = {
        _module.args.pkgs = import toplevel.inputs.nixpkgs {
          inherit system;
          overlays = [ (import localFlake.inputs.rust-overlay) ];
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
      };
    };
  };
}
