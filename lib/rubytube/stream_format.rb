module RubyTube
  class StreamFormat
    PROGRESSIVE_VIDEO = {
      5 => ["240p", "64kbps"],
      6 => ["270p", "64kbps"],
      13 => ["144p", nil],
      17 => ["144p", "24kbps"],
      18 => ["360p", "96kbps"],
      22 => ["720p", "192kbps"],
      34 => ["360p", "128kbps"],
      35 => ["480p", "128kbps"],
      36 => ["240p", nil],
      37 => ["1080p", "192kbps"],
      38 => ["3072p", "192kbps"],
      43 => ["360p", "128kbps"],
      44 => ["480p", "128kbps"],
      45 => ["720p", "192kbps"],
      46 => ["1080p", "192kbps"],
      59 => ["480p", "128kbps"],
      78 => ["480p", "128kbps"],
      82 => ["360p", "128kbps"],
      83 => ["480p", "128kbps"],
      84 => ["720p", "192kbps"],
      85 => ["1080p", "192kbps"],
      91 => ["144p", "48kbps"],
      92 => ["240p", "48kbps"],
      93 => ["360p", "128kbps"],
      94 => ["480p", "128kbps"],
      95 => ["720p", "256kbps"],
      96 => ["1080p", "256kbps"],
      100 => ["360p", "128kbps"],
      101 => ["480p", "192kbps"],
      102 => ["720p", "192kbps"],
      132 => ["240p", "48kbps"],
      151 => ["720p", "24kbps"],
      300 => ["720p", "128kbps"],
      301 => ["1080p", "128kbps"],
    }

    DASH_VIDEO = {
      133 => ["240p", nil],
      134 => ["360p", nil],
      135 => ["480p", nil],
      136 => ["720p", nil],
      137 => ["1080p", nil],
      138 => ["2160p", nil],
      160 => ["144p", nil],
      167 => ["360p", nil],
      168 => ["480p", nil],
      169 => ["720p", nil],
      170 => ["1080p", nil],
      212 => ["480p", nil],
      218 => ["480p", nil],
      219 => ["480p", nil],
      242 => ["240p", nil],
      243 => ["360p", nil],
      244 => ["480p", nil],
      245 => ["480p", nil],
      246 => ["480p", nil],
      247 => ["720p", nil],
      248 => ["1080p", nil],
      264 => ["1440p", nil],
      266 => ["2160p", nil],
      271 => ["1440p", nil],
      272 => ["4320p", nil],
      278 => ["144p", nil],
      298 => ["720p", nil],
      299 => ["1080p", nil],
      302 => ["720p", nil],
      303 => ["1080p", nil],
      308 => ["1440p", nil],
      313 => ["2160p", nil],
      315 => ["2160p", nil],
      330 => ["144p", nil],
      331 => ["240p", nil],
      332 => ["360p", nil],
      333 => ["480p", nil],
      334 => ["720p", nil],
      335 => ["1080p", nil],
      336 => ["1440p", nil],
      337 => ["2160p", nil],
      394 => ["144p", nil],
      395 => ["240p", nil],
      396 => ["360p", nil],
      397 => ["480p", nil],
      398 => ["720p", nil],
      399 => ["1080p", nil],
      400 => ["1440p", nil],
      401 => ["2160p", nil],
      402 => ["4320p", nil],
      571 => ["4320p", nil],
      694 => ["144p", nil],
      695 => ["240p", nil],
      696 => ["360p", nil],
      697 => ["480p", nil],
      698 => ["720p", nil],
      699 => ["1080p", nil],
      700 => ["1440p", nil],
      701 => ["2160p", nil],
      702 => ["4320p", nil]
    }

    DASH_AUDIO = {
      139 => [nil, "48kbps"],
      140 => [nil, "128kbps"],
      141 => [nil, "256kbps"],
      171 => [nil, "128kbps"],
      172 => [nil, "256kbps"],
      249 => [nil, "50kbps"],
      250 => [nil, "70kbps"],
      251 => [nil, "160kbps"],
      256 => [nil, "192kbps"],
      258 => [nil, "384kbps"],
      325 => [nil, nil],
      328 => [nil, nil],
    }

    ITAGS = {
      **PROGRESSIVE_VIDEO,
      **DASH_VIDEO,
      **DASH_AUDIO
    }

    HDR = [330, 331, 332, 333, 334, 335, 336, 337]
    FORMAT_3D = [82, 83, 84, 85, 100, 101, 102]
    LIVE = [91, 92, 93, 94, 95, 96, 132, 151]

    attr_reader :itag, :resolution, :abr

    def initialize(_itag)
      @itag = _itag

      @resolution, @abr = ITAGS.fetch(itag)
    end

    def is_live?
      !!LIVE[itag]
    end

    def is_3d?
      !!FORMAT_3D[itag]
    end

    def is_hdr?
      !!HDR[itag]
    end

    def is_dash?
      !!DASH_AUDIO[itag] || !!DASH_VIDEO[itag]
    end
  end
end
