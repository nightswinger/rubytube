# frozen_string_literal: true

require 'faraday'
require 'faraday/follow_redirects'

require_relative 'rubytube/version'

require_relative 'rubytube/cipher'
require_relative 'rubytube/client'
require_relative 'rubytube/error'
require_relative 'rubytube/extractor'
require_relative 'rubytube/innertube'
require_relative 'rubytube/monostate'
require_relative 'rubytube/parser'
require_relative 'rubytube/request'
require_relative 'rubytube/stream_format'
require_relative 'rubytube/stream_query'
require_relative 'rubytube/stream'
require_relative 'rubytube/utils'

module RubyTube
  class << self
    def new(url)
      Client.new(url)
    end
  end
end
