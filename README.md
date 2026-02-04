# ParallelSftp

Fast parallel SFTP downloads using lftp's segmented transfer. This gem wraps lftp to enable multi-connection parallel downloads for large files.

## Features

- Parallel/segmented downloads using multiple connections
- Resume interrupted downloads
- Progress callbacks for monitoring
- Configurable retry and timeout settings
- Optimized presets for large files (20GB+)

## Requirements

- **lftp** must be installed on the system

### Installing lftp

**macOS:**
```bash
brew install lftp
```

**Ubuntu/Debian:**
```bash
apt install lftp
```

**Heroku:**
```bash
heroku buildpacks:add --index 1 https://github.com/heroku/heroku-buildpack-apt
echo "lftp" > Aptfile
git add Aptfile && git commit -m "Add lftp via apt buildpack"
git push heroku master
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'parallel_sftp'
```

And then execute:

```bash
bundle install
```

## Usage

### Simple one-liner

```ruby
require 'parallel_sftp'

ParallelSftp.download(
  host: 'sftp.example.com',
  user: 'username',
  password: 'secret',
  remote_path: '/path/to/large_file.zip',
  local_path: '/tmp/large_file.zip'
)
```

### Using the Client

```ruby
client = ParallelSftp::Client.new(
  host: 'sftp.example.com',
  user: 'username',
  password: 'secret',
  port: 22
)

# Basic download
client.download('/remote/file.zip', '/local/file.zip')

# With options
client.download('/remote/file.zip', '/local/file.zip',
  segments: 8,           # parallel connections (default: 4)
  resume: true,          # continue interrupted downloads (default: true)
  timeout: 60,           # connection timeout seconds (default: 30)
  max_retries: 15,       # retry attempts (default: 10)
  on_progress: ->(info) { puts "#{info[:percent]}%" }
)
```

### Progress Callback

The progress callback receives a hash with:

```ruby
{
  percent: 45,                    # percentage complete
  bytes_transferred: 1073741824,  # bytes downloaded
  total_bytes: 21474836480,       # total file size
  speed: 10485760,                # bytes per second
  eta: "30m"                      # estimated time remaining
}
```

### Global Configuration

```ruby
ParallelSftp.configure do |config|
  config.default_segments = 8      # parallel connections
  config.timeout = 60              # connection timeout
  config.max_retries = 15          # retry attempts
  config.reconnect_interval = 10   # seconds between retries
  config.default_port = 22         # SFTP port
end
```

### Large File Optimization

For files 20GB+, use the optimized settings:

```ruby
ParallelSftp.configuration.optimize_for_large_files!
# Sets: segments=8, timeout=60, max_retries=15, reconnect_interval=10
```

## Tuned Settings

| Setting | Default | Large File (20GB+) | Purpose |
|---------|---------|-------------------|---------|
| `segments` | 4 | 8 | More parallel connections |
| `timeout` | 30 | 60 | Longer timeout for slow starts |
| `max_retries` | 10 | 15 | More retries for flaky connections |
| `reconnect_interval` | 5 | 10 | Wait longer between retries |

## Error Handling

```ruby
begin
  ParallelSftp.download(...)
rescue ParallelSftp::LftpNotFoundError
  # lftp is not installed
rescue ParallelSftp::ConnectionError => e
  # SFTP connection failed
  puts e.host
  puts e.exit_status
rescue ParallelSftp::DownloadError => e
  # Transfer failed
  puts e.remote_path
  puts e.exit_status
  puts e.output
rescue ParallelSftp::IntegrityError => e
  # File size mismatch
  puts e.expected_size
  puts e.actual_size
end
```

## Checking lftp Availability

```ruby
if ParallelSftp.lftp_available?
  puts "lftp version: #{ParallelSftp.lftp_version}"
else
  puts "lftp is not installed"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

### Running Integration Tests

Integration tests require a running SFTP server. Set these environment variables:

```bash
export SFTP_TEST_HOST=your-sftp-server.com
export SFTP_TEST_USER=username
export SFTP_TEST_PASSWORD=password
export SFTP_TEST_FILE=/path/to/test/file.txt

rspec spec/integration
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
