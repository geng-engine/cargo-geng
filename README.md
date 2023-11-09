# cargo-geng

Cargo helper for geng projects

## Install

```sh
cargo install --git https://github.com/geng-engine/cargo-geng
```

## Usage

```sh
cargo geng build --release # will package executable & assets in `target/geng` folder
cargo geng build --release --platform web # package web build instead of current target
cargo geng serve --platform web # build web package and serve it
```
