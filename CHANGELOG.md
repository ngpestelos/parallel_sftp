# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-02-05

### Added
- Runtime dependencies `ed25519` and `bcrypt_pbkdf` for net-ssh Ed25519 key support

## [0.3.0] - 2026-02-05

### Added
- `ZipIntegrityError` class for zip file corruption detection
- Automatic zip integrity verification using `unzip -t` after download
- Auto-retry on zip corruption with parallel-first strategy
- New `retry_on_corruption` option (default: true) to enable/disable auto-retry
- New `parallel_retries` option (default: 2) - retries with same segment count before reducing

### Changed
- Downloads now verify zip integrity before returning success
- Corrupted downloads are automatically cleaned up before retry

## [0.2.0] - 2026-02-04

### Added
- Per-segment progress tracking via `on_segment_progress` callback
- `SegmentProgressParser` class for parsing `.lftp-pget-status` files
- `TimeEstimator` class for calculating download speed and ETA with moving window
- Calculated time estimates independent of lftp's reported ETA
- Elapsed time tracking since download start
- Average speed calculation from download start

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
