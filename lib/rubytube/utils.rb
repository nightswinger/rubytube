module RubyTube
  module Utils
    module_function

    def regex_search(pattern, string, group)
      match = string.match(pattern)
      if match
        return match[group]
      end
      nil
    end
  end
end
