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

### Channels

```ruby
channel = RubyTube::Channel.new("https://www.youtube.com/@GoogleDevelopers")  # also UC..., @handle, /channel/UC...
channel.name        # => "Google for Developers"
channel.channel_id  # => "UC_x5XG1OV2P6uZZ5FSM9Ttw"

# Lazy: only as many pages are fetched as you consume
channel.videos.first(5).map(&:title)
channel.videos.take_while { |v| v.published_text.end_with?("days ago") }.to_a
channel.videos.to_a                                       # every video on the Videos tab

video = channel.videos.first                              # RubyTube::VideoItem
video.video_id; video.title; video.length                 # length in seconds
video.view_count_text; video.published_text               # "16K views", "2 days ago" (as YouTube shows them)
video.thumbnail_url; video.url
video.to_youtube.download(output_path: "~/Movies")        # promote to a YouTube for streams/download

yt.channel                                                # Channel of a video's uploader

# Bulk download; members-only or scheduled videos raise VideoUnavailable
channel.videos.each { |v| v.to_youtube.download(output_path: "~/Movies") rescue RubyTube::VideoUnavailable }
```

### Playlists

```ruby
playlist = RubyTube::Playlist.new("https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H")  # also PL..., watch?v=...&list=...
playlist.title              # => "Compressor Head"
playlist.length             # => 9 (videos)
playlist.views              # => 80317
playlist.last_updated_text  # => "Feb 23, 2026" or "3 days ago" (as YouTube shows it)
playlist.owner; playlist.owner_id; playlist.channel   # uploader name, UC..., and its Channel
playlist.description; playlist.thumbnail_url; playlist.url

# Same lazy VideoItem enumeration as Channel#videos; private/deleted entries are listed when YouTube shows them
playlist.videos.first(5).map(&:title)
playlist.videos.each { |v| v.to_youtube.download(output_path: "~/Movies") rescue RubyTube::VideoUnavailable }
```

`Stream#download` writes a single track. Progressive (video+audio in one file) formats
are no longer served in a downloadable form by YouTube, so they are not exposed.

## Command line

`gem install rubytube` also installs a `rubytube` command:

```sh
rubytube https://www.youtube.com/watch?v=jNQXAC9IVRw          # best video + audio, muxed -> ./Me at the zoo.mp4
rubytube URL -o ~/Movies -r 720                               # save elsewhere, cap resolution
rubytube URL -a                                               # audio only (m4a, no ffmpeg needed)
rubytube URL --container webm                                 # vp9 + opus
rubytube URL -l                                               # list streams
rubytube URL --itag 140                                       # one raw track, no muxing
rubytube https://www.youtube.com/playlist?list=PL...          # every video in a playlist
rubytube https://www.youtube.com/@GoogleDevelopers -a         # every video on a channel
```

Playlist and channel urls apply the same options to each video; failures are reported and skipped,
and the exit status is 1 if any video failed. A `watch?v=...&list=...` url is treated as the single
video; pass the `playlist?list=` url or the bare `PL...` id for the whole playlist.

## Development

```sh
ruby test/rubytube_test.rb   # offline tests (recorded innertube fixture)
ruby scripts/smoke.rb        # live smoke test against real YouTube (needs ffmpeg)
ruby scripts/channel.rb URL  # live check of Channel listing
ruby scripts/playlist.rb URL # live check of Playlist listing
ruby exe/rubytube URL -l     # CLI against real YouTube
```
