use std::path::PathBuf;

#[derive(clap::Subcommand, PartialEq, Eq, Clone, strum::EnumString, strum::Display)]
#[strum(serialize_all = "snake_case")]
pub enum Sub {
    Build,
    Run,
    Serve,
}

#[derive(clap::Parser)]
pub struct Args {
    pub sub: Sub,
    #[clap(long)]
    pub out_dir: Option<PathBuf>,
    #[clap(long, short = 'p')]
    pub package: Option<String>,
    #[clap(long)]
    pub release: bool,
    #[clap(long)]
    pub profile: Option<String>,
    #[clap(long)]
    pub features: Vec<String>,
    #[clap(long)]
    pub all_features: bool,
    #[clap(long)]
    pub no_default_features: bool,
    #[clap(long)]
    pub example: Option<String>,
    #[clap(long, short = 'j')]
    pub jobs: Option<usize>,
    pub passthrough_args: Vec<String>,
    #[clap(long)]
    pub platform: Option<crate::Platform>,
    #[clap(flatten)]
    pub web: crate::platform::web::Args,
}

pub fn parse() -> Args {
    let mut args: Vec<_> = std::env::args().collect();
    if args.len() >= 2 && args[1] == "geng" {
        args.remove(1);
    }
    if args.is_empty() {
        todo!("Help");
    }
    clap::Parser::parse_from(args)
}
