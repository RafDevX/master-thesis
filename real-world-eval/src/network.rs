use std::{
    fs::File,
    io::{BufWriter, Seek, Write},
    time,
};

use backon::BlockingRetryable;
use url::Url;

use crate::errors::{AppError, AppResult};

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
        self.get_with_exponential_backoff(url, |response| response.text().map_err(Into::into))
    }

    pub fn download(&self, url: impl reqwest::IntoUrl + Copy) -> AppResult<File> {
        self.get_with_exponential_backoff(url, |mut response| {
            let mut file = tempfile::tempfile()?;

            let mut writer = BufWriter::new(file.try_clone()?);

            response.copy_to(&mut writer)?;

            writer.flush()?;
            file.rewind()?;

            Ok(file)
        })
    }

    fn get_with_exponential_backoff<R>(
        &self,
        url: impl reqwest::IntoUrl + Copy,
        process_response: impl Fn(reqwest::blocking::Response) -> AppResult<R>,
    ) -> AppResult<R> {
        (|| {
            let response = self
                .0
                .get(url)
                .send()
                .and_then(reqwest::blocking::Response::error_for_status)?;

            process_response(response)
        })
        .retry(EXPONENTIAL_RETRY)
        .when(|err| {
            if let AppError::Network(inner) = err {
                inner
                    .status()
                    .is_none_or(|status| status != reqwest::StatusCode::NOT_FOUND)
            } else {
                // io errors during response processing should not retry the
                // request, since it's not really the remote server's fault
                false
            }
        })
        .notify(|err, duration| {
            if let AppError::Network(inner) = err {
                println!(
                    "Retrying GET request to `{}` in {:?}: {}",
                    inner.url().map_or("<unknown>", Url::as_str),
                    duration,
                    // cannot use `err.without_url` as we only have &err
                    inner.to_string().split(" for url ").next().unwrap()
                );
            } else {
                unreachable!("already filtered above ({err:?})");
            }
        })
        .call()
    }
}
