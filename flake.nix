# https://scvalex.net/posts/63/
{
  inputs = {
    # This must be the stable nixpkgs if you're running the app on a
    # stable NixOS install.  Mixing EGL library versions doesn't work.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    crane-flake.url = "github:ipetkov/crane";
    android.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, crane-flake, android, utils, nix-filter }:
    {
      inherit (utils.lib) eachDefaultSystem;
      makeFlakeSystemOutputs = system: { src, extraBuildInputs ? [ ], rust ? { }, ... }@config:
        let
          filter = nix-filter.lib;
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };
          rust-properties = ({
            version = "latest";
            toolchain-kind = "stable";
          } // rust);
          rust-toolchain = pkgs.rust-bin.${rust-properties.toolchain-kind}.${rust-properties.version}.default.override
            {
              extensions = [ "rust-src" ];
              targets = [
                "wasm32-unknown-unknown"
                "x86_64-pc-windows-gnu"
                "aarch64-linux-android"
              ];
            } // rust;
          crane = (crane-flake.lib.${system}).overrideToolchain rust-toolchain;
          waylandDeps = with pkgs; [
            libxkbcommon
            wayland
          ];
          xorgDeps = with pkgs; [
            xorg.libX11
            xorg.libXcursor
            xorg.libXi
            xorg.libXrandr
          ];
          libDeps = with pkgs;
            extraBuildInputs ++
            waylandDeps ++
            xorgDeps ++
            [
              # kdialog # for tinyfiledialogs
              openssl
              alsa-lib
              udev
              libGL
              xorg.libxcb
            ];
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; libDeps ++ [ xorg.libxcb ];
          libPath = pkgs.lib.makeLibraryPath libDeps;
          lib = rec {
            inherit crane;
            inherit filter;
            cargo-geng = crane.buildPackage {
              pname = "cargo-geng";
              src = filter {
                root = ./.;
                include = [
                  ./src
                  ./Cargo.lock
                  ./Cargo.toml
                ];
              };
            };
            buildGengPackage =
              { platform ? null
              , ...
              }@origArgs:
              let
                cleanedArgs = builtins.removeAttrs origArgs [
                  "installPhase"
                  "installPhaseCommand"
                  "platform"
                ];

                crateName = crane.crateNameFromCargoToml cleanedArgs;

                # Avoid recomputing values when passing args down
                args = cleanedArgs // {
                  pname = cleanedArgs.pname or crateName.pname;
                  version = cleanedArgs.version or crateName.version;
                  cargoVendorDir = cleanedArgs.cargoVendorDir or (crane.vendorCargoDeps cleanedArgs);
                  CARGO_BUILD_TARGET =
                    if platform == "web" then "wasm32-unknown-unknown"
                    else if platform == "android" then "aarch64-linux-android"
                    else if platform == "windows" then "x86_64-pc-windows-gnu"
                    else if builtins.isNull platform then null
                    else throw "unknown platform ${platform}";
                  depsBuildBuild =
                    if platform == "windows" then
                      with pkgs; [
                        pkgsCross.mingwW64.windows.pthreads
                        pkgsCross.mingwW64.stdenv.cc
                      ]
                    else [ ];
                  CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER =
                    if platform == "windows" then
                      "${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc"
                    else null;
                };
              in
              crane.mkCargoDerivation (args // {
                # pnameSuffix = "-trunk";
                cargoArtifacts = args.cargoArtifacts or (crane.buildDepsOnly (args // {
                  installCargoArtifactsMode = args.installCargoArtifactsMode or "use-zstd";
                  doCheck = args.doCheck or false;
                  inherit nativeBuildInputs;
                  inherit buildInputs;
                }));

                buildPhaseCargoCommand = args.buildPhaseCommand or (
                  let
                    args = if builtins.isNull platform then "" else "--platform " + platform;
                  in
                  ''
                    local args="${args}"
                    if [[ "$CARGO_PROFILE" == "release" ]]; then
                      args="$args --release"
                    fi

                    cargo geng build $args
                  ''
                );

                installPhaseCommand = args.installPhaseCommand or ''
                  cp -r target/geng $out
                '';

                # Installing artifacts on a distributable dir does not make much sense
                doInstallCargoArtifacts = args.doInstallCargoArtifacts or false;

                nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ nativeBuildInputs ++ [
                  cargo-geng
                ];
                buildInputs = buildInputs ++ (args.buildInputs or [ ]);
              });
            cargo-apk = crane.buildPackage {
              pname = "cargo-apk";
              version = "0.9.7";
              src = builtins.fetchGit {
                url = "https://github.com/geng-engine/cargo-apk";
                allRefs = true;
                rev = "3d64d642fc4adf68b8a828cc1c743303a360ae1d";
              };
              cargoExtraArgs = "--package cargo-apk";
              cargoVendorDir = crane.vendorCargoDeps {
                cargoLock = ./cargo-apk.Cargo.lock;
              };
            };
            androidsdk = (pkgs.androidenv.composeAndroidPackages {
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
          };
        in
        rec {
          inherit lib;
          # Executed by `nix build .`
          packages.default = lib.buildGengPackage { inherit src; };
          # Executed by `nix build .#web"
          packages.web = lib.buildGengPackage { inherit src; platform = "web"; };
          # Executed by `nix build .#windows"
          packages.windows = lib.buildGengPackage { inherit src; platform = "windows"; };
          # Executed by `nix build .#android"
          packages.android = lib.buildGengPackage { inherit src; platform = "android"; };
          # Executed by `nix run . -- <args?>`
          apps.default =
            {
              type = "app";
              program = "${packages.default}/${packages.default.pname}";
            };
          devShell = with pkgs; mkShell {
            inherit nativeBuildInputs;
            buildInputs = buildInputs ++ [
              just
              rust-toolchain
              rust-analyzer
              # wineWowPackages.waylandFull
              # pkgsCross.mingwW64.windows.pthreads
              lib.cargo-apk
              lib.androidsdk
              jre
            ] ++ (if (config.cargo-geng or true) then [ lib.cargo-geng ] else [ ]);
            shellHook =
              let
                libPath = pkgs.lib.makeLibraryPath (libDeps ++ [ pkgsCross.mingwW64.windows.pthreads ]);
                androidSdkRoot = "${lib.androidsdk}/libexec/android-sdk";
                androidNdkRoot = "${androidSdkRoot}/ndk-bundle";
              in
              ''
                export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS="-C link-args=''$(echo $NIX_LDFLAGS | tr ' ' '\n' | grep -- '^-L' | tr '\n' ' ')"
                export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${libPath}"
                export WINIT_UNIX_BACKEND=x11 # TODO fix
                export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="${pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc"
                export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUNNER="wine64"
                export ANDROID_SDK_ROOT="${androidSdkRoot}";
                export ANDROID_NDK_ROOT="${androidNdkRoot}"; 
              '';
          };
          formatter = pkgs.nixpkgs-fmt;
        };
      makeFlakeOutputs = f: utils.lib.eachDefaultSystem (system: self.makeFlakeSystemOutputs system (f system));
    } // utils.lib.eachDefaultSystem (system:
      with self.makeFlakeSystemOutputs system { src = ./.; cargo-geng = false; };
      {
        inherit formatter lib devShell;
        packages.default = lib.cargo-geng;
        apps.default =
          {
            type = "app";
            program = "${lib.cargo-geng}/bin/${lib.cargo-geng.pname}";
          };
      }
    );
}
