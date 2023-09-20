# RubyTube

RubyTube is a Ruby implementation of the popular Python library, pytube. This library facilitates the downloading and streaming of YouTube videos, offering the robust functionality of pytube in a Ruby-friendly format.

## Installation

    $ gem install rubytube

## Quick Start

```ruby
require 'rubytube'

# Initialize with video URL
video = RubyTube.new('https://www.youtube.com/watch?v=dQw4w9WgXcQ')

# Download video
video.download(filename: 'my_video.mp4')
```
