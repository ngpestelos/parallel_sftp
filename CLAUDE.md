# parallel_sftp Gem Guidelines

> **Purpose**: Fast parallel SFTP downloads using lftp's segmented transfer (`pget` command)

## Project Overview

- **Test Framework**: RSpec
- **Ruby Version**: >= 2.5.0
- **External Dependency**: lftp (must be installed on system)
- **License**: MIT

## Quick Commands

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/parallel_sftp/segment_progress_parser_spec.rb

# Run with documentation format
bundle exec rspec --format documentation

# Integration tests (require SFTP server)
SFTP_TEST_HOST=host SFTP_TEST_USER=user SFTP_TEST_PASSWORD=pass bundle exec rspec spec/integration
```

## Architecture

```
lib/parallel_sftp/
├── client.rb                  # High-level API, creates LftpCommand and Download
├── configuration.rb           # Global settings (segments, timeout, retries)
├── download.rb                # Executes lftp, handles progress callbacks
├── errors.rb                  # Custom error classes
├── lftp_command.rb            # Builds lftp script with pget command
├── progress_parser.rb         # Parses lftp stdout for progress info
├── segment_progress_parser.rb # Parses .lftp-pget-status file for per-segment progress
├── time_estimator.rb          # Calculates speed/ETA with moving window
└── version.rb                 # Gem version
```

## Key Patterns

### Adding New Options

When adding a new option that flows through the API:

1. Add to `Configuration` class (with default)
2. Add to `LftpCommand#initialize` parameters
3. Add to `Client#download` options handling
4. Add to `ParallelSftp.download` module method
5. Update specs for all affected classes

### Progress Callbacks

Two callback types exist:

- **`on_progress`**: Parsed from lftp stdout (percent, speed, eta)
- **`on_segment_progress`**: Polled from `.lftp-pget-status` file (per-segment detail)

### Thread Safety

The `Download` class spawns a background thread for segment progress polling. Key patterns:

```ruby
# Start polling
@stop_polling = false
@polling_thread = Thread.new { poll_segment_progress(status_file) }

# Stop polling (with timeout)
@stop_polling = true
@polling_thread.join(2)
@polling_thread.kill if @polling_thread.alive?
```

### lftp Status File Format

lftp creates `{filename}.lftp-pget-status` during pget downloads:

```
size=20955686931
0.pos=57442304
0.limit=2619460869
1.pos=2670611717
1.limit=5238921735
```

- `size`: Total file size (-2 indicates unknown/error)
- `N.pos`: Current byte position for segment N
- `N.limit`: End byte position for segment N
- Segment start = previous segment's limit (or 0 for segment 0)

### Password Escaping

Special characters in passwords must be URL-encoded for lftp:

```ruby
# In LftpCommand
def escaped_password
  CGI.escape(password)
end
```

### Legacy SSH Server Support

Some servers only offer `ssh-rsa` host keys. Configure via:

```ruby
ParallelSftp.configure do |config|
  config.sftp_connect_program = 'ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa'
end

# Or pass explicitly (recommended for rake tasks)
ParallelSftp.download(
  sftp_connect_program: 'ssh -o HostKeyAlgorithms=+ssh-rsa',
  ...
)
```

## Testing Patterns

### Mocking lftp Availability

```ruby
before do
  allow(ParallelSftp).to receive(:lftp_available?).and_return(true)
end
```

### Mocking Download Execution

```ruby
download_mock = instance_double(ParallelSftp::Download, execute: local_path)
allow(ParallelSftp::Download).to receive(:new).and_return(download_mock)
```

### Testing Progress Callbacks

```ruby
it "passes progress callback to Download" do
  progress_callback = ->(info) { puts info }

  expect(ParallelSftp::Download).to receive(:new)
    .with(anything, on_progress: progress_callback, on_segment_progress: nil)
    .and_return(download_mock)

  client.download(remote_path, local_path, on_progress: progress_callback)
end
```

### Using Tempfile for Status File Tests

```ruby
Tempfile.create("status") do |f|
  f.write("size=1000\n0.pos=500\n0.limit=1000\n")
  f.rewind
  expect(parser.parse(f.path)).to be true
end
```

## Error Handling

Custom errors inherit from `ParallelSftp::Error`:

- `LftpNotFoundError` - lftp not installed
- `ConnectionError` - SFTP connection failed (includes host, exit_status)
- `DownloadError` - Transfer failed (includes remote_path, exit_status, output)
- `IntegrityError` - File size mismatch (includes expected_size, actual_size)

## Code Style

- Frozen string literals in all files
- RSpec `described_class` for subject
- Keyword arguments for complex methods
- Guard clauses for early returns
- Struct for simple data objects (e.g., `Segment`, `Sample`)

