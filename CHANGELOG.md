# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-02-04

### Added
- Initial release
- `ParallelSftp.download` one-liner for simple downloads
- `ParallelSftp::Client` for multiple downloads with shared connection settings
- Parallel/segmented downloads via lftp's `pget` command
- Resume support for interrupted downloads
- Progress callbacks with percent, speed, ETA
- Global configuration with `ParallelSftp.configure`
- `optimize_for_large_files!` preset for 20GB+ files
- Error classes: `LftpNotFoundError`, `ConnectionError`, `DownloadError`, `IntegrityError`
- lftp availability check with `lftp_available?` and `lftp_version`
