use std::path::Path;

pub fn run(executable: impl AsRef<Path>, out_dir: impl AsRef<Path>) -> anyhow::Result<()> {
    let mut wasm_bindgen = wasm_bindgen_cli_support::Bindgen::new();
    wasm_bindgen
        .input_path(&executable)
        .web(true)?
        .typescript(false)
        .generate_output()?
        .emit(&out_dir)?;
    Ok(())
}
