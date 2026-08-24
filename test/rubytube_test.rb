require "minitest/autorun"
require "json"
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

  def test_parses_all_streams_with_urls
    assert_operator @yt.streams.size, :>=, 10
    assert(@yt.streams.all? { |s| s.url.start_with?("https://") && s.itag.is_a?(Integer) })
  end

  def test_progressive_vs_adaptive
    progressive = @yt.streams.filter(progressive: true)
    assert_equal [18], progressive.map(&:itag)
    assert progressive.first.includes_audio_track?
    assert progressive.first.includes_video_track?
    assert @yt.streams.filter(adaptive: true).all?(&:adaptive?)
  end

  def test_filter_audio_and_subtype
    audio = @yt.streams.filter(only_audio: true)
    assert_operator audio.size, :>=, 2
    assert(audio.all? { |s| s.type == "audio" && s.video_codec.nil? && s.audio_codec })
    assert(@yt.streams.filter(only_audio: true, subtype: "webm").all? { |s| s.subtype == "webm" })
  end

  def test_filter_with_block_and_enumerable
    high = @yt.streams.filter { |s| (s.bitrate || 0) > 100_000 }
    assert_operator high.size, :>, 0
    assert_kind_of RubyTube::StreamQuery, high
    assert_equal @yt.streams.select(&:only_audio?).size, @yt.streams.filter(only_audio: true).size
  end

  def test_getters
    assert_equal 18, @yt.streams.get_by_itag(18).itag
    assert_equal "240p", @yt.streams.get_highest_resolution.resolution
    assert @yt.streams.get_highest_resolution.progressive?
    audio = @yt.streams.get_audio_only
    assert_equal "audio/mp4", audio.mime_type
    assert_equal 140, audio.itag
  end

  def test_order_by
    abrs = @yt.streams.filter(only_audio: true).order_by(:bitrate).map(&:bitrate)
    assert_equal abrs.sort, abrs
    resolutions = @yt.streams.filter(type: "video").order_by(:resolution).map { |s| s.resolution.to_i }
    assert_equal resolutions.sort, resolutions
  end

  def test_stream_attributes
    s = @yt.streams.get_by_itag(18)
    assert_equal "video", s.type
    assert_equal "mp4", s.subtype
    assert_equal 2, s.codecs.size
    assert_match(/\A\d+kbps\z/, s.abr)
    assert_equal "Me at the zoo.mp4", s.default_filename
    assert_operator @yt.streams.get_audio_only.filesize, :>, 0
  end

  def test_unavailable_video_raises
    yt = RubyTube::YouTube.new("jNQXAC9IVRw")
    innertube = Object.new
    def innertube.player(_id) = { "playabilityStatus" => { "status" => "LOGIN_REQUIRED", "reason" => "bot check" } }
    yt.instance_variable_set(:@innertube, innertube)
    error = assert_raises(RubyTube::VideoUnavailable) { yt.title }
    assert_equal "LOGIN_REQUIRED", error.status
  end
end
