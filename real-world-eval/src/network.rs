use std::{
    fs::File,
    io::{BufWriter, Write},
    time,
};

use backon::BlockingRetryable;
use url::Url;

use crate::errors::AppResult;

const USER_AGENT: &str = concat!(env!("CARGO_PKG_NAME"), "/", env!("CARGO_PKG_VERSION"));
const NETWORK_TIMEOUT: Option<time::Duration> = Some(time::Duration::from_mins(2));
const EXPONENTIAL_RETRY: backon::ExponentialBuilder = backon::ExponentialBuilder::new()
    .with_jitter()
    .with_max_times(5);

pub struct NetworkClient(reqwest::blocking::Client);

impl NetworkClient {
    pub fn new() -> AppResult<Self> {
        let inner = reqwest::blocking::Client::builder()
            .timeout(NETWORK_TIMEOUT)
            .user_agent(USER_AGENT)
            .gzip(true)
            .brotli(true)
            .build()?;

        Ok(Self(inner))
    }

    pub fn get(&self, url: impl reqwest::IntoUrl + Copy) -> AppResult<String> {
        let response = self.get_with_exponential_backoff(url)?;

        response.text().map_err(Into::into)
    }

    pub fn download(&self, url: impl reqwest::IntoUrl + Copy) -> AppResult<File> {
        let mut response = self.get_with_exponential_backoff(url)?;

        let file = tempfile::tempfile()?;

        let mut writer = BufWriter::new(file.try_clone()?);

        response.copy_to(&mut writer)?;

        writer.flush()?;

        Ok(file)
    }

    fn get_with_exponential_backoff(
        &self,
        url: impl reqwest::IntoUrl + Copy,
    ) -> AppResult<reqwest::blocking::Response> {
        (|| {
            self.0
                .get(url)
                .send()
                .and_then(reqwest::blocking::Response::error_for_status)
        })
        .retry(EXPONENTIAL_RETRY)
        .notify(|err, duration| {
            println!(
                "Retrying GET request to `{}` in {:?}: {}",
                err.url().map_or("<unknown>", Url::as_str),
                duration,
                // cannot use `err.without_url` as we only have &err
                err.to_string().split(" for url ").next().unwrap()
            );
        })
        .call()
        .map_err(Into::into)
    }
}
