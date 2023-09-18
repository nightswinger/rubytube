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

    def target_directory(output_path = nil)
      if output_path
        result = File.join(Dir.pwd, output_path) unless File.absolute_path?(output_path)
      else
        result = Dir.pwd
      end

      FileUtils.mkdir_p(result) unless Dir.exist?(result)
      result
    end
  end
end
