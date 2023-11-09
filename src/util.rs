use std::process::Command;

pub fn exec<C: std::borrow::BorrowMut<Command>>(mut cmd: C) -> Result<(), anyhow::Error> {
    if cmd.borrow_mut().status()?.success() {
        Ok(())
    } else {
        anyhow::bail!("Failure")
    }
}

pub fn maybe_arg(arg: &str, value: Option<impl AsRef<str>>) -> impl Iterator<Item = String> {
    value
        .map(|value| [arg.to_owned(), value.as_ref().to_owned()])
        .into_iter()
        .flatten()
}

pub fn maybe_flag(flag: &str, enable: bool) -> Option<String> {
    enable.then(|| flag.to_owned())
}
