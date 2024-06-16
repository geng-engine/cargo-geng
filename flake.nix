{
  inputs = {
    # This must be the stable nixpkgs if you're running the app on a
    # stable NixOS install.  Mixing EGL library versions doesn't work.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    nix-filter.url = "github:numtide/nix-filter";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    crane-flake.url = "github:ipetkov/crane";
    android.url = "github:tadfisher/android-nixpkgs"; # TODO: unused?
  };

  outputs = { self, nixpkgs, systems, rust-overlay, crane-flake, nix-filter, ... }:
    let
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      forEachSystem = f: nixpkgs.lib.genAttrs (import systems) (system:
        let pkgs = pkgsFor system;
        in f system pkgs);
    in
    {
      lib = {
        filter = nix-filter.lib;
        mkEnv = config@{ system, ... }:
          let
            pkgs = pkgsFor system;
            configExtraModules = config.modules or [ ];
            configModule = {
              config = builtins.removeAttrs config [ "system" "modules" ];
            };
            crane = crane-flake.mkLib pkgs;
          in
          (pkgs.lib.evalModules {
            modules = [ ./flake-module configModule ] ++ configExtraModules;
            specialArgs = { inherit pkgs crane; };
          }).config;
        mkShell = config@{ system, ... }:
          let
            pkgs = pkgsFor system;
            shellModule = { rust.dev = true; };
            finalConfig = config // { modules = [ shellModule ] ++ config.modules or [ ]; };
            env = self.lib.mkEnv finalConfig;
          in
          pkgs.mkShell
            {
              packages = env.packages;
              shellHook =
                let
                  libPath = pkgs.lib.makeLibraryPath env.packages;
                in
                ''
                  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${libPath}"
                '';
            } // env.env;

        buildGengPackage =
          origArgs@{ system, platform ? "linux", package ? null, envConfig ? { }, ... }:
          let
            pkgs = pkgsFor system;
            crane = crane-flake.mkLib pkgs;
            env = self.lib.mkEnv {
              inherit system;
              modules = [
                {
                  target.${platform}.enable = true;
                  packages = [ self.packages.${system}.default ];
                }
                envConfig
              ];
            };
            cleanedArgs = builtins.removeAttrs origArgs [
              "system"
              "package"
              "platform"
              "envConfig"
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
                else if platform == "linux" then "x86_64-unknown-linux-gnu"
                else throw "unknown platform ${platform}";
              buildInputs = cleanedArgs.buildInputs or [ ] ++ env.packages;
              dontWrapQtApps = true; # No idea where this shit is documented
            } // env.env;
          in
          crane.mkCargoDerivation (args // {
            # pnameSuffix = "-trunk";
            cargoArtifacts = args.cargoArtifacts or (crane.buildDepsOnly (args // {
              installCargoArtifactsMode = args.installCargoArtifactsMode or "use-zstd";
              doCheck = args.doCheck or false;
            }));
            buildPhaseCargoCommand = args.buildPhaseCommand or (
              let
                packageArg = if builtins.isNull package then "" else "--package=${package}";
                platformArg = "--platform=${platform}";
              in
              ''
                local args=${platformArg}${packageArg}
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
          });
      };
      packages = forEachSystem (system: pkgs:
        let
          src = self.lib.filter {
            root = ./.;
            include = [
              "Cargo.toml"
              "Cargo.lock"
              "src"
            ];
          };
        in
        {
          default = (crane-flake.mkLib pkgs).buildPackage {
            inherit src;
          };
          buildSelf = self.lib.buildGengPackage {
            inherit system;
            inherit src;
          };
          # TODO default = cargo-geng package
        });
      devShells = forEachSystem (system: pkgs: {
        default = self.lib.mkShell {
          inherit system;
          target.linux.enable = false; # we only develop cargo-geng itself, not games with geng
        };
        full = self.lib.mkShell {
          inherit system;
          target.linux.enable = true;
          target.web.enable = true;
          target.android.enable = true;
          target.windows.enable = true;
        };
      });
      formatter = forEachSystem (system: pkgs: pkgs.nixpkgs-fmt);
    };
}
