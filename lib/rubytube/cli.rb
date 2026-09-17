require "optparse"
require "io/console"
require_relative "../rubytube"

module RubyTube
  class CLI
    def self.run(argv, out: $stdout, err: $stderr) = new(out, err).run(argv)

    def initialize(out, err)
      @out = out
      @err = err
    end

    def run(argv)
      opts = { container: "mp4" }
      parser = option_parser(opts)
      urls = parser.parse(argv)
      if opts[:version]
        @out.puts VERSION
        return 0
      end
      if opts[:help] || urls.size != 1
        @out.puts parser
        return opts[:help] ? 0 : 1
      end

      source = videos_for(urls.first)
      count = failed = 0
      source.each do |yt|
        count += 1
        process(yt, opts)
      rescue Error => e
        failed += 1
        @err.puts "rubytube: #{e.message}"
      end
      @err.puts "#{count} videos, #{failed} failed" unless source.is_a?(Array)
      failed.zero? ? 0 : 1
    rescue OptionParser::ParseError, Error => e
      @err.puts "rubytube: #{e.message}"
      1
    rescue Interrupt
      130
    end

    private

    def option_parser(opts)
      OptionParser.new("usage: rubytube [options] <video | playlist | channel url>") do |o|
        o.on("-o", "--output DIR", "Directory to save into (default: current directory)") { opts[:output] = it }
        o.on("-a", "--audio", "Download audio only (m4a)") { opts[:audio] = true }
        o.on("-l", "--list", "List available streams instead of downloading") { opts[:list] = true }
        o.on("--itag N", Integer, "Download a single stream by itag (no muxing)") { opts[:itag] = it }
        o.on("-r", "--max-res N", Integer, "Highest resolution to pick, e.g. 720") { opts[:max_res] = it }
        o.on("--container NAME", "mp4 (default) or webm") { opts[:container] = it }
        o.on("-V", "--version", "Print version") { opts[:version] = true }
        o.on("-h", "--help", "Show this help") { opts[:help] = true }
      end
    end

    # Video wins over playlist for watch?v=...&list=... urls.
    def videos_for(url)
      return [YouTube.new(url)] if matches?(YouTube::VIDEO_ID_PATTERNS, url)
      return Channel.new(url).videos.lazy.map(&:to_youtube) if matches?(Channel::CHANNEL_PATTERNS, url)
      return Playlist.new(url).videos.lazy.map(&:to_youtube) if matches?(Playlist::PLAYLIST_ID_PATTERNS, url)

      raise ExtractError, "could not recognize #{url.inspect} as a video, channel, or playlist url"
    end

    def matches?(patterns, url) = patterns.any? { |p| p.match?(url) }

    def process(yt, opts)
      @out.puts yt.title
      return yt.streams.each { |s| @out.puts s } if opts[:list]

      path =
        if opts[:itag]
          stream = yt.streams.get_by_itag(opts[:itag]) or raise ExtractError, "no stream with itag #{opts[:itag]}"
          stream.download(output_path: opts[:output], &progress)
        else
          yt.download(output_path: opts[:output], container: opts[:container], max_resolution: opts[:max_res],
                      audio_only: opts[:audio], &progress)
        end
      @out.puts path
    end

    def progress
      return nil unless @err.tty?

      total = nil
      lambda do |chunk, remaining|
        total ||= remaining + chunk.bytesize
        progress_bar(total - remaining, total)
      end
    end

    def progress_bar(received, total)
      width = ((IO.console&.winsize&.last || 80) * 0.55).to_i
      filled = (width * received / total.to_f).round
      @err.print "\r ↳ |#{"█" * filled}#{" " * (width - filled)}| #{(100.0 * received / total).round(1)}%"
      @err.puts if received >= total
    end
  end
end
