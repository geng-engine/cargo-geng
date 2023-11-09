use futures::future;
use hyper::service::{make_service_fn, service_fn};
use hyper::{Body, Request, Response};
use hyper_staticfile::Static;
use std::io::Error as IoError;
use std::path::Path;

#[derive(clap::Args)]
#[group(id = "WebArgs")]
pub struct Args {
    #[clap(long, default_value = "8000")]
    pub serve_port: u16,
    #[clap(long)]
    pub index_file: Option<String>,
}

pub fn run_wasm_bindgen(
    executable: impl AsRef<Path>,
    out_dir: impl AsRef<Path>,
) -> anyhow::Result<()> {
    let mut wasm_bindgen = wasm_bindgen_cli_support::Bindgen::new();
    wasm_bindgen
        .input_path(&executable)
        .web(true)?
        .typescript(false)
        .generate_output()?
        .emit(&out_dir)?;
    Ok(())
}

pub fn run_wasm_opt(wasm_bg_path: impl AsRef<Path>, out: impl AsRef<Path>) -> anyhow::Result<()> {
    #[cfg(feature = "wasm-opt")]
    wasm_opt::OptimizationOptions::new_optimize_for_size_aggressively().run(&wasm_bg_path, out)?;
    #[cfg(not(feature = "wasm-opt"))]
    std::fs::copy(&wasm_bg_path, out)?;

    std::fs::remove_file(&wasm_bg_path)?;
    Ok(())
}

pub fn serve(dir: impl AsRef<Path>, port: u16, open: bool) {
    async fn handle_request<B>(
        req: Request<B>,
        r#static: Static,
    ) -> Result<Response<Body>, IoError> {
        r#static.clone().serve(req).await
    }

    tokio::runtime::Runtime::new().unwrap().block_on(async {
        let r#static = Static::new(dir.as_ref());

        let make_service = make_service_fn(|_| {
            let static_ = r#static.clone();
            future::ok::<_, hyper::Error>(service_fn(move |req| {
                handle_request(req, static_.clone())
            }))
        });

        let addr = ([0, 0, 0, 0], port).into();
        let server = hyper::server::Server::bind(&addr).serve(make_service);
        eprintln!("Server running on {addr}. You can open http://localhost:{port}");
        if open {
            open::that(format!("http://localhost:{port}")).expect("Failed to open browser");
        }
        server.await.expect("Server failed");
    });
}
