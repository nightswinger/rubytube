# frozen_string_literal: true

require 'faraday'

require_relative 'rubytube/version'

require_relative 'rubytube/client'
require_relative 'rubytube/extractor'
require_relative 'rubytube/innertube'
require_relative 'rubytube/request'
require_relative 'rubytube/utils'

module RubyTube
  class Error < StandardError; end

  class << self
    def new(url)
      Client.new(url)
    end
  end
end
