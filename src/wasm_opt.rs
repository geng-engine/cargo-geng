use std::path::Path;

pub fn run(wasm_bg_path: impl AsRef<Path>, out: impl AsRef<Path>) -> anyhow::Result<()> {
    #[cfg(feature = "wasm-opt")]
    wasm_opt::OptimizationOptions::new_optimize_for_size_aggressively().run(&wasm_bg_path, out)?;
    #[cfg(not(feature = "wasm-opt"))]
    std::fs::copy(&wasm_bg_path, out)?;

    std::fs::remove_file(&wasm_bg_path)?;
    Ok(())
}
