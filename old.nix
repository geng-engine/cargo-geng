{
  outputs2 = { self, nixpkgs, rust-overlay, crane-flake, android, utils, nix-filter }:
    {
      inherit (utils.lib) eachDefaultSystem;
      makeFlakeSystemOutputs = system: { src, extraBuildInputs ? [ ], rust ? { }, ... }@config:
        let
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
          with self.makeFlakeSystemOutputs system { src = ./.;
          cargo-geng = false;
          };
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
