# rubytube

Download YouTube videos from Ruby. YouTube serves video and audio as separate tracks;
rubytube picks the best of each and muxes them with ffmpeg, or hands you the tracks directly.

## Installation

```sh
gem install rubytube
brew install ffmpeg   # only needed for muxed video downloads (YouTube#download)
```

## Usage

```ruby
require "rubytube"

yt = RubyTube::YouTube.new("https://www.youtube.com/watch?v=jNQXAC9IVRw")
yt.title    # => "Me at the zoo"
yt.length   # => 19
yt.author   # => "jawed"

# One call: best video + best audio, muxed with ffmpeg (stream copy, no re-encode)
yt.download(output_path: "~/Movies")                          # => "~/Movies/Me at the zoo.mp4"
yt.download(container: "webm", max_resolution: 1080)          # vp9 + opus
yt.download(audio_only: true)                                 # => "Me at the zoo.m4a", no ffmpeg needed
yt.download { |chunk, bytes_remaining| puts "#{bytes_remaining} bytes to go" }

# Individual tracks
yt.streams.best_video                    # highest resolution mp4 (video only)
yt.streams.best_video(container: "webm", max_resolution: 720)
yt.streams.best_audio                    # highest bitrate m4a
yt.streams.best_audio.download(output_path: "~/Music")

# StreamQuery is Enumerable — filter/order_by or plain select/sort_by
yt.streams.video_streams.filter(container: "mp4") { |s| s.fps == 60 }.order_by(:bitrate).last
yt.streams.audio_streams
yt.streams.get_by_itag(140)
```

`Stream#download` writes a single track. Progressive (video+audio in one file) formats
are no longer served in a downloadable form by YouTube, so they are not exposed.

## Development

```sh
ruby test/rubytube_test.rb   # offline tests (recorded innertube fixture)
ruby scripts/smoke.rb        # live smoke test against real YouTube (needs ffmpeg)
```
