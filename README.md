# rubytube

RubyTube is a Ruby implementation of the popular Python library, pytube. This library facilitates the downloading and streaming of YouTube videos, offering the robust functionality of pytube in a Ruby-friendly format.

## Installation

```sh
gem install rubytube
```

## Usage

```ruby
require "rubytube"

yt = RubyTube::YouTube.new("https://www.youtube.com/watch?v=jNQXAC9IVRw")
yt.title    # => "Me at the zoo"
yt.length   # => 19
yt.author   # => "jawed"

# StreamQuery is Enumerable — filter/order_by or plain select/sort_by
yt.streams.filter(only_audio: true, subtype: "mp4")
yt.streams.filter { |s| s.bitrate > 100_000 }
yt.streams.order_by(:resolution).last
yt.streams.get_by_itag(18)

stream = yt.streams.get_highest_resolution
stream.download(output_path: "~/Movies") do |chunk, bytes_remaining|
  puts "#{bytes_remaining} bytes to go"
end
```

## Development

```sh
ruby test/rubytube_test.rb   # offline tests (recorded innertube fixture)
ruby scripts/smoke.rb        # live smoke test against real YouTube
```
