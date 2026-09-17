require "minitest/autorun"
require "json"
require "tmpdir"
require "fileutils"
require_relative "../lib/rubytube"

def fixture(name) = JSON.parse(File.read(File.expand_path("fixtures/#{name}.json", __dir__), encoding: "utf-8"))

FIXTURE = fixture("player_response")
CHANNEL_PAGE = fixture("channel_page")
BROWSE_CONTINUATION = fixture("browse_continuation")
PLAYLIST_BROWSE = fixture("playlist_browse")
PLAYLIST_CONTINUATION = fixture("playlist_continuation")

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

class ChannelTest < Minitest::Test
  def setup
    @channel = RubyTube::Channel.new("https://www.youtube.com/@GoogleDevelopers/videos")
    @channel.instance_variable_set(:@initial_data, CHANNEL_PAGE)
    stub_browse { |calls| calls.size == 1 ? BROWSE_CONTINUATION : {} } # one continuation, then a final empty page
  end

  def stub_browse(&pages)
    @browse_calls = calls = []
    @channel.instance_variable_get(:@innertube).define_singleton_method(:browse) do |continuation:, visitor_data:|
      calls << continuation
      pages.call(calls)
    end
  end

  def test_extracts_channel_ref_from_common_shapes
    {
      "https://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw" => "UC_x5XG1OV2P6uZZ5FSM9Ttw",
      "https://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw/videos" => "UC_x5XG1OV2P6uZZ5FSM9Ttw",
      "UC_x5XG1OV2P6uZZ5FSM9Ttw" => "UC_x5XG1OV2P6uZZ5FSM9Ttw",
      "https://www.youtube.com/@GoogleDevelopers" => "@GoogleDevelopers",
      "https://www.youtube.com/@Google.Developers/shorts" => "@Google.Developers",
      "@GoogleDevelopers" => "@GoogleDevelopers",
      "https://www.youtube.com/@%E6%97%A5%E6%9C%AC%E8%AA%9E/videos" => "@日本語",
      "@日本語" => "@日本語"
    }.each { |url, ref| assert_equal ref, RubyTube::Channel.extract_channel_ref(url), url }
    assert_raises(RubyTube::ExtractError) { RubyTube::Channel.extract_channel_ref("https://example.com/") }
  end

  def test_channel_metadata
    assert_equal "UC_x5XG1OV2P6uZZ5FSM9Ttw", @channel.channel_id
    assert_equal "Google for Developers", @channel.name
  end

  def test_first_page_needs_no_browse_call
    videos = @channel.videos.first(3)
    assert_equal 3, videos.size
    assert_empty @browse_calls

    first = videos.first
    assert_equal "CBzLIKfWpdg", first.video_id
    assert_equal "Celebrating one billion Gemma downloads", first.title
    assert_equal 56, first.length
    assert_equal "16K views", first.view_count_text
    assert_equal "2 days ago", first.published_text
    assert_match %r{\Ahttps://i\.ytimg\.com/vi/CBzLIKfWpdg/}, first.thumbnail_url
    assert_equal "https://www.youtube.com/watch?v=CBzLIKfWpdg", first.url
    assert_equal "CBzLIKfWpdg", first.to_youtube.video_id
  end

  def test_follows_continuations_to_the_last_page
    videos = @channel.videos.to_a
    assert_equal 60, videos.size # page 1 (30) + one continuation (30)
    assert_equal 60, videos.map(&:video_id).uniq.size
    assert_equal 2, @browse_calls.size
    assert(videos.all? { |v| v.length.is_a?(Integer) && v.title })

    collab = videos.find { |v| v.video_id == "TNwKs39uSVk" } # metadata row 0 holds the collaborator names
    assert_equal "187K views", collab.view_count_text
    assert_equal "2 months ago", collab.published_text
  end

  def test_repeated_continuation_token_terminates
    stub_browse { BROWSE_CONTINUATION } # YouTube keeps handing back the same token
    assert_equal 90, @channel.videos.count
    assert_equal 2, @browse_calls.size
  end

  def test_youtube_channel_shortcut
    assert_equal "UC4QobU6STFB0P71PMvOGN5A", fixture_youtube.channel.instance_variable_get(:@ref)
  end
end

class PlaylistTest < Minitest::Test
  def setup
    @playlist = RubyTube::Playlist.new("https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H")
    @playlist.instance_variable_set(:@initial_data, PLAYLIST_BROWSE)
    stub_browse { |calls| calls.size == 1 ? PLAYLIST_CONTINUATION : {} }
  end

  def stub_browse(&pages)
    @browse_calls = calls = []
    @playlist.instance_variable_get(:@innertube).define_singleton_method(:browse) do |**kwargs|
      calls << kwargs
      pages.call(calls)
    end
  end

  def test_extracts_playlist_id_from_common_shapes
    {
      "https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H" => "PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H",
      "https://www.youtube.com/watch?v=Eb7rzMxHyOk&list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H&index=1" => "PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H",
      "https://music.youtube.com/playlist?list=OLAK5uy_kX7ZQd4mYQq0bPZLvK3f9FZrZQ7sKUbJc" => "OLAK5uy_kX7ZQd4mYQq0bPZLvK3f9FZrZQ7sKUbJc",
      "UU_x5XG1OV2P6uZZ5FSM9Ttw" => "UU_x5XG1OV2P6uZZ5FSM9Ttw",
      "PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H" => "PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H"
    }.each { |url, id| assert_equal id, RubyTube::Playlist.extract_playlist_id(url), url }
    ["jNQXAC9IVRw", "https://www.youtube.com/watch?v=jNQXAC9IVRw", "UC_x5XG1OV2P6uZZ5FSM9Ttw"].each do |bad|
      assert_raises(RubyTube::ExtractError, bad) { RubyTube::Playlist.extract_playlist_id(bad) }
    end
  end

  def test_metadata
    assert_equal "Compressor Head", @playlist.title
    assert_match(/\A6 episode video series/, @playlist.description.sub(/\ACompressor Head is a /, ""))
    assert_equal 9, @playlist.length
    assert_equal 80_317, @playlist.views
    assert_equal "Feb 23, 2026", @playlist.last_updated_text
    assert_equal "Google for Developers", @playlist.owner
    assert_equal "UC_x5XG1OV2P6uZZ5FSM9Ttw", @playlist.owner_id
    assert_equal "UC_x5XG1OV2P6uZZ5FSM9Ttw", @playlist.channel.instance_variable_get(:@ref)
    assert_match %r{\Ahttps://i\.ytimg\.com/vi/Eb7rzMxHyOk/}, @playlist.thumbnail_url
    assert_equal "https://www.youtube.com/playlist?list=PLOU2XLYxmsIJGErt5rrCqaSGTMyyqNt2H", @playlist.url
  end

  def test_metadata_falls_back_to_page_header_without_sidebar
    @playlist.instance_variable_set(:@initial_data, PLAYLIST_BROWSE.reject { |k, _| k == "sidebar" })
    assert_equal 9, @playlist.length
    assert_equal 80_317, @playlist.views
    assert_nil @playlist.last_updated_text # header rows carry no date
    assert_equal "Google for Developers", @playlist.owner
    assert_equal "UC_x5XG1OV2P6uZZ5FSM9Ttw", @playlist.owner_id
    assert_match %r{\Ahttps://i\.ytimg\.com/vi/Eb7rzMxHyOk/}, @playlist.thumbnail_url # microformat
  end

  def test_first_page_needs_no_browse_call
    videos = @playlist.videos.first(9)
    assert_equal 9, videos.size
    assert_empty @browse_calls

    first = videos.first
    assert_instance_of RubyTube::VideoItem, first
    assert_equal "Eb7rzMxHyOk", first.video_id
    assert_equal "Introducing Compressor Head", first.title
    assert_equal 100, first.length
    assert_equal "45K views", first.view_count_text
    assert_equal "12 years ago", first.published_text
  end

  def test_follows_sibling_and_trailing_continuations
    videos = @playlist.videos.to_a
    assert_equal 12, videos.size # first page (9, continuation as a sibling section) + one continuation page (3, trailing item)
    assert_equal 12, videos.map(&:video_id).uniq.size
    assert_equal 2, @browse_calls.size
    assert_match(/\A4qmFsgJb/, @browse_calls.first[:continuation])
  end

  def test_repeated_continuation_token_terminates
    stub_browse { PLAYLIST_CONTINUATION }
    assert_equal 15, @playlist.videos.count
    assert_equal 2, @browse_calls.size
  end

  def test_missing_playlist_raises_with_youtube_alert
    playlist = RubyTube::Playlist.new("PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
    playlist.instance_variable_get(:@innertube).define_singleton_method(:browse) do |**|
      { "alerts" => [{ "alertRenderer" => { "type" => "ERROR", "text" => { "runs" => [{ "text" => "The playlist does not exist." }] } } }] }
    end
    error = assert_raises(RubyTube::ExtractError) { playlist.title }
    assert_equal "playlist PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: The playlist does not exist.", error.message
  end
end

class ContinuationTokenTest < Minitest::Test
  def test_three_shapes_youtube_has_used
    assert_equal "a", RubyTube::InnerTube.continuation_token(
      { "continuationItemRenderer" => { "continuationEndpoint" => { "continuationCommand" => { "token" => "a" } } } })
    assert_equal "b", RubyTube::InnerTube.continuation_token(
      { "continuationItemViewModel" => { "continuationCommand" => { "innertubeCommand" => { "continuationCommand" => { "token" => "b" } } } } })
    assert_equal "c", RubyTube::InnerTube.continuation_token(
      { "continuationItemRenderer" => { "continuationEndpoint" => { "commandExecutorCommand" => { "commands" => [
        { "other" => {} }, { "continuationCommand" => { "token" => "c" } }
      ] } } } })
    assert_nil RubyTube::InnerTube.continuation_token({ "lockupViewModel" => {} })
  end
end

require "minitest/mock"
require "stringio"
require_relative "../lib/rubytube/cli"

class CLITest < Minitest::Test
  def run_cli(*argv)
    out, err = StringIO.new, StringIO.new
    status = RubyTube::YouTube.stub(:new, fixture_youtube) { RubyTube::CLI.run(argv, out:, err:) }
    [status, out.string, err.string]
  end

  def test_list_prints_title_and_streams
    status, out, err = run_cli("jNQXAC9IVRw", "-l")
    assert_equal 0, status
    assert_equal "", err
    lines = out.lines
    assert_equal "Me at the zoo\n", lines.first
    assert_equal fixture_youtube.streams.size, lines.size - 1
    assert(lines.drop(1).all? { |l| l.start_with?("#<RubyTube::Stream itag=") })
  end

  def test_rejects_unknown_url_and_bad_option
    status, _, err = run_cli("https://example.com/")
    assert_equal 1, status
    assert_match(/could not recognize/, err)

    status, _, err = run_cli("jNQXAC9IVRw", "--bogus")
    assert_equal 1, status
    assert_match(/invalid option/, err)
  end

  def test_version_and_help
    assert_equal [0, "#{RubyTube::VERSION}\n"], run_cli("-V").first(2)
    status, out, = run_cli
    assert_equal 1, status
    assert_match(/usage: rubytube/, out)
  end
end
