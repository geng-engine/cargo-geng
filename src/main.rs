use anyhow::Context;
use std::{
    path::{Path, PathBuf},
    process::Command,
};

mod platform;
use platform::Platform;

mod util;
use util::*;

mod args;
use args::{Args, Sub};

impl Args {
    fn args_without_target(&self) -> impl Iterator<Item = String> + '_ {
        itertools::chain![
            maybe_arg("--package", self.package.as_ref()),
            maybe_flag("--release", self.release),
            maybe_arg("--profile", self.profile.as_ref()),
            maybe_arg("--example", self.example.as_ref()),
            maybe_flag("--all-features", self.all_features),
            maybe_flag("--no-default-features", self.no_default_features),
            self.features
                .iter()
                .flat_map(|feature| ["--features".to_owned(), feature.to_owned()]),
            self.jobs.map(|jobs| format!("--jobs={jobs}")),
        ]
    }
    fn all_args(&self) -> impl Iterator<Item = String> + '_ {
        itertools::chain![
            self.args_without_target(),
            maybe_arg(
                "--target",
                self.platform.map(|platform| match platform {
                    Platform::Linux => "x86_64-unknown-linux-gnu",
                    Platform::Windows => "x86_64-pc-windows-gnu",
                    Platform::Mac => todo!(),
                    Platform::Web => "wasm32-unknown-unknown",
                    Platform::Android => "aarch64-linux-android",
                })
            ),
        ]
    }
}

#[derive(serde::Deserialize)]
struct GengMetadata {
    assets: Option<Vec<PathBuf>>,
}
#[derive(serde::Deserialize)]
struct AndroidMetadata {
    apk_name: Option<String>,
}
#[derive(serde::Deserialize)]
struct Metadata {
    geng: Option<GengMetadata>,
    android: Option<AndroidMetadata>,
}

fn package_metadata(package: &cargo_metadata::Package) -> anyhow::Result<Metadata> {
    Ok(serde_json::from_value::<Metadata>(
        package.metadata.clone(),
    )?)
}

pub fn main() -> anyhow::Result<()> {
    let args = args::parse();
    let metadata = cargo_metadata::MetadataCommand::new().exec()?;
    let package = metadata
        .packages
        .iter()
        .find(|package| {
            if let Some(name) = &args.package {
                package.name == *name
            } else {
                package.id
                    == *metadata
                        .resolve
                        .as_ref()
                        .unwrap()
                        .root
                        .as_ref()
                        .expect("No root package or --package")
            }
        })
        .unwrap();

    let assets: Vec<PathBuf> = {
        fn package_assets(
            package: &cargo_metadata::Package,
            example: Option<&str>,
        ) -> Vec<PathBuf> {
            let mut root_dir = Path::new(&package.manifest_path)
                .parent()
                .unwrap()
                .to_owned();
            if let Some(example) = example {
                root_dir = root_dir.join("examples").join(example);
            }
            let mut result = Vec::new();
            let metadata = package_metadata(package).unwrap();
            if let Some(assets) = metadata.geng.and_then(|geng| geng.assets) {
                result.extend(assets.into_iter().map(|path| root_dir.join(path)));
            } else {
                // default assets paths
                let assets_dir = root_dir.join("assets");
                if assets_dir.is_dir() {
                    result.push(assets_dir);
                }
            }
            result
        }
        let mut paths = Vec::new();
        for dep in &metadata.packages {
            if package.name == dep.name {
                if let Some(example) = &args.example {
                    paths.extend(package_assets(dep, Some(example)));
                }
            }
            paths.extend(package_assets(dep, None));
        }
        paths
    };

    let out_dir = args
        .out_dir
        .clone()
        .unwrap_or(metadata.target_directory.join("geng").into());

    let platform = args.platform.unwrap_or(Platform::current());

    log::info!("Building {package:?}");
    if out_dir.exists() {
        log::debug!("{out_dir:?} exists, cleaning");
        std::fs::remove_dir_all(&out_dir)?;
    }
    std::fs::create_dir_all(&out_dir)?;

    let executable = match platform {
        Platform::Android => {
            let assets_dir = metadata.target_directory.join("android-assets");
            if assets_dir.exists() {
                std::fs::remove_dir_all(&assets_dir)?;
            }
            std::fs::create_dir_all(&assets_dir)?;
            fs_extra::copy_items(&assets, &assets_dir, &{
                let mut options = fs_extra::dir::CopyOptions::new();
                options.copy_inside = true;
                options
            })
            .context("Failed to copy assets")?;
            exec(
                Command::new("cargo")
                    .arg("apk")
                    .arg(if args.sub == Sub::Run { "run" } else { "build" })
                    .arg("--assets")
                    .arg(&assets_dir)
                    .args(args.args_without_target()),
            )?;
            let apk_name = package_metadata(package)
                .unwrap()
                .android
                .and_then(|android| android.apk_name)
                .unwrap_or(package.name.clone());
            let apk_filename = format!("{apk_name}.apk");
            let apk_path = metadata
                .target_directory
                .join(if args.release { "release" } else { "debug" })
                .join("apk")
                .join(&apk_filename);
            let final_apk_path = out_dir.join(&apk_filename);
            std::fs::copy(apk_path, &final_apk_path)
                .context(format!("Failed to copy {apk_filename:?}"))?;
            final_apk_path
        }
        _ => {
            exec(Command::new("cargo").arg("build").args(args.all_args()))?;
            fs_extra::copy_items(&assets, &out_dir, &{
                let mut options = fs_extra::dir::CopyOptions::new();
                options.copy_inside = true;
                options
            })?;

            let mut command = Command::new("cargo")
                .arg("build")
                .args(args.all_args())
                .arg("--message-format=json")
                .stdout(std::process::Stdio::piped())
                .stderr(std::process::Stdio::null())
                .spawn()?;
            let reader = std::io::BufReader::new(command.stdout.take().unwrap());
            let mut executable = None;
            for message in cargo_metadata::Message::parse_stream(reader) {
                if let cargo_metadata::Message::CompilerArtifact(cargo_metadata::Artifact {
                    executable: Some(path),
                    ..
                }) = message.unwrap()
                {
                    if executable.is_some() {
                        anyhow::bail!("Found several executable files");
                    }
                    executable = Some(path);
                }
            }
            command.wait()?;
            let executable = executable.ok_or_else(|| anyhow::anyhow!("executable not found"))?;

            if platform == Platform::Web {
                let stem = executable.file_stem().unwrap();
                platform::web::run_wasm_bindgen(&executable, &out_dir)?;
                let wasm_bg_path = out_dir.join(format!("{stem}_bg.wasm"));
                let wasm_path = out_dir.join(format!("{stem}.wasm"));
                if args.release {
                    platform::web::run_wasm_opt(wasm_bg_path, wasm_path)?;
                } else {
                    std::fs::rename(wasm_bg_path, wasm_path)?;
                }
                let index_file_path =
                    out_dir.join(args.web.index_file.as_deref().unwrap_or("index.html"));
                std::fs::write(
                    &index_file_path,
                    include_str!("index.html").replace("<app-name>", stem),
                )?;
                std::fs::write(out_dir.join("sound-fix.js"), include_str!("sound-fix.js"))?;
                index_file_path
            } else {
                let final_executable_path = out_dir.join(executable.file_name().unwrap());
                std::fs::copy(&executable, &final_executable_path)?;
                final_executable_path
            }
        }
    };

    match platform {
        Platform::Linux | Platform::Windows | Platform::Mac => {
            if args.sub == Sub::Serve {
                panic!("no serving for platform {platform:?}");
            }
            if args.sub == Sub::Run {
                exec(Command::new(executable).args(args.passthrough_args).env(
                    "CARGO_MANIFEST_DIR",
                    package.manifest_path.parent().unwrap(),
                ))?;
            }
        }
        Platform::Web => {
            if let Sub::Run | Sub::Serve = args.sub {
                platform::web::serve(&out_dir, args.web.serve_port, args.sub == Sub::Run);
            }
        }
        Platform::Android => {
            if args.sub == Sub::Serve {
                panic!("no serving for platform {platform:?}");
            }
            if args.sub == Sub::Run {
                // TODO currently running happens while building :)
                // todo!("Running android not yet implemented");
            }
        }
    }

    Ok(())
}
