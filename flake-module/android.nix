{ inputs, ... }:
{
  perSystem = { lib, config, pkgs, system, ... }:
    let cfg = config.geng.android;
    in
    {
      options.geng.android = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        cargo-apk = lib.mkOption {
          type = lib.types.package;
        };
        sdk = lib.mkOption {
          type = lib.types.package;
        };
      };
      config = lib.mkIf cfg.enable {
        geng.rust.targets = [ "aarch64-linux-android" ];
        geng.android.cargo-apk = config.geng.lib.crane.buildPackage {
          pname = "cargo-apk";
          version = "0.9.7";
          src = builtins.fetchGit {
            url = "https://github.com/geng-engine/cargo-apk";
            ref = "dev";
            rev = "977278e9b298d6f99c03c3e3a8fac18cbbd42daa";
          };
          cargoExtraArgs = "--package cargo-apk";
          cargoVendorDir = config.geng.lib.crane.vendorCargoDeps {
            cargoLock = ./cargo-apk.Cargo.lock;
            src = ./.;
          };
        };
        geng.android.sdk = (pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "8.0";
          toolsVersion = "26.1.1";
          platformToolsVersion = "34.0.1";
          buildToolsVersions = [ "30.0.3" ];
          includeEmulator = false;
          emulatorVersion = "33.1.6";
          platformVersions = [ "33" ];
          includeSources = false;
          includeSystemImages = false;
          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = [
            "armeabi-v7a"
            "arm64-v8a"
          ];
          cmakeVersions = [ "3.10.2" ];
          includeNDK = true;
          ndkVersions = [ "25.2.9519653" ];
          useGoogleAPIs = false;
          useGoogleTVAddOns = false;
          includeExtras = [
            # "extras;google;gcm"
          ];
        }).androidsdk;
        geng.env = rec {
          ANDROID_SDK_ROOT = "${config.geng.android.sdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";
        };
        geng.packages = [
          config.geng.android.sdk
          config.geng.android.cargo-apk
        ];
      };
    };
}
