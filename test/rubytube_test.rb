require "minitest/autorun"
require "json"
require "tmpdir"
require "fileutils"
require_relative "../lib/rubytube"

FIXTURE = JSON.parse(File.read(File.expand_path("fixtures/player_response.json", __dir__)))

def fixture_youtube
  yt = RubyTube::YouTube.new("jNQXAC9IVRw")
  yt.instance_variable_set(:@player_response, FIXTURE)
  yt
end

class VideoIdTest < Minitest::Test
  def test_extracts_from_common_url_shapes
    %w[
      https://www.youtube.com/watch?v=jNQXAC9IVRw
      https://www.youtube.com/watch?feature=share&v=jNQXAC9IVRw
      https://youtu.be/jNQXAC9IVRw?t=1
      https://www.youtube.com/shorts/jNQXAC9IVRw
      https://www.youtube.com/embed/jNQXAC9IVRw
      jNQXAC9IVRw
    ].each do |url|
      assert_equal "jNQXAC9IVRw", RubyTube::YouTube.extract_video_id(url), url
    end
  end

  def test_rejects_garbage
    assert_raises(RubyTube::ExtractError) { RubyTube::YouTube.extract_video_id("https://example.com/") }
  end
end

class MetadataTest < Minitest::Test
  def setup = @yt = fixture_youtube

  def test_video_details
    assert_equal "Me at the zoo", @yt.title
    assert_equal "jawed", @yt.author
    assert_equal 19, @yt.length
    assert_operator @yt.views, :>, 400_000_000
    assert_match %r{\Ahttps://}, @yt.thumbnail_url
  end
end

class StreamsTest < Minitest::Test
  def setup = @yt = fixture_youtube

  def test_parses_only_adaptive_streams
    assert_operator @yt.streams.size, :>=, 10
    assert(@yt.streams.all? { |s| s.url.start_with?("https://") && s.itag.is_a?(Integer) && s.codecs.size == 1 })
    assert_nil @yt.streams.get_by_itag(18)
  end

  def test_video_and_audio_streams
    assert @yt.streams.video_streams.all?(&:video?)
    assert @yt.streams.audio_streams.all?(&:audio?)
    assert_equal @yt.streams.size, @yt.streams.video_streams.size + @yt.streams.audio_streams.size
    assert(@yt.streams.audio_streams.all? { |s| s.video_codec.nil? && s.audio_codec })
  end

  def test_filter_and_enumerable
    assert(@yt.streams.filter(type: "audio", container: "webm").all? { |s| s.container == "webm" })
    high = @yt.streams.filter { |s| (s.bitrate || 0) > 100_000 }
    assert_operator high.size, :>, 0
    assert_kind_of RubyTube::StreamQuery, high
    assert_equal @yt.streams.select(&:audio?).size, @yt.streams.filter(type: "audio").size
  end

  def test_best_video
    best = @yt.streams.best_video
    assert_equal 133, best.itag
    assert_equal "240p", best.resolution
    assert_equal 242, @yt.streams.best_video(container: "webm").itag
    assert_equal 160, @yt.streams.best_video(max_resolution: 144).itag
    assert_nil @yt.streams.best_video(max_resolution: 100)
  end

  def test_best_audio
    assert_equal 140, @yt.streams.best_audio.itag
    assert_equal 251, @yt.streams.best_audio(container: "webm").itag
  end

  def test_order_by
    abrs = @yt.streams.audio_streams.order_by(:bitrate).map(&:bitrate)
    assert_equal abrs.sort, abrs
    resolutions = @yt.streams.video_streams.order_by(:resolution).map { |s| s.resolution.to_i }
    assert_equal resolutions.sort, resolutions
  end

  def test_stream_attributes
    s = @yt.streams.get_by_itag(133)
    assert_equal "video", s.type
    assert_equal "mp4", s.container
    assert_equal "avc1.4d400c", s.video_codec
    assert_match(/\A\d+kbps\z/, s.abr)
    assert_equal "Me at the zoo.mp4", s.default_filename
    assert_equal "Me at the zoo.m4a", @yt.streams.best_audio.default_filename
    assert_equal "Me at the zoo.webm", @yt.streams.best_audio(container: "webm").default_filename
    assert_operator @yt.streams.best_audio.filesize, :>, 0
  end
end

class DownloadTest < Minitest::Test
  def setup
    @yt = fixture_youtube
    @dir = Dir.mktmpdir
    @yt.streams.each do |s|
      def s.download(output_path:, filename: nil, **)
        path = File.join(output_path, filename || default_filename)
        File.write(path, "#{itag}|")
        yield "#{itag}|", 0 if block_given?
        path
      end
    end
    def @yt.mux(inputs, target) = File.write(target, inputs.map { File.read(it) }.join)
  end

  def teardown = FileUtils.rm_rf(@dir)

  def test_download_muxes_best_video_and_audio
    seen = []
    path = @yt.download(output_path: @dir) { |chunk, remaining| seen << [chunk, remaining] }
    assert_equal File.join(@dir, "Me at the zoo.mp4"), path
    assert_equal "133|140|", File.read(path)
    assert_equal ["133|", "140|"], seen.map(&:first)
    assert_equal ["Me at the zoo.mp4"], Dir.children(@dir)
  end

  def test_download_options
    assert_equal "242|251|", File.read(@yt.download(output_path: @dir, container: "webm", filename: "x.webm"))
    assert_equal "140|", File.read(@yt.download(output_path: @dir, audio_only: true))
    assert_equal "160|140|", File.read(@yt.download(output_path: @dir, max_resolution: 144, filename: "low.mp4"))
  end

  def test_download_skips_existing
    target = File.join(@dir, "Me at the zoo.mp4")
    File.write(target, "old")
    assert_equal target, @yt.download(output_path: @dir)
    assert_equal "old", File.read(target)
  end
end

class AvailabilityTest < Minitest::Test
  def test_unavailable_video_raises
    yt = RubyTube::YouTube.new("jNQXAC9IVRw")
    innertube = Object.new
    def innertube.player(_id) = { "playabilityStatus" => { "status" => "LOGIN_REQUIRED", "reason" => "bot check" } }
    yt.instance_variable_set(:@innertube, innertube)
    error = assert_raises(RubyTube::VideoUnavailable) { yt.title }
    assert_equal "LOGIN_REQUIRED", error.status
  end
end
