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
        sdk = lib.mkOption {
          type = lib.types.package;
        };
      };
      config = lib.mkIf cfg.enable {
        geng.rust.targets = [ "aarch64-linux-android" ];
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
        devenv.shells.default = {
          env = rec {
            ANDROID_SDK_ROOT = "${config.geng.android.sdk}/libexec/android-sdk";
            ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";
          };
          packages = [
            config.geng.android.sdk
          ];
        };
      };
    };
}
