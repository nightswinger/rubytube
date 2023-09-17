module RubyTube
  class Cipher
    attr_accessor :transform_plan, :transform_map, :js_func_patterns, :throttling_plan, :throttling_array, :calculation_plan, :calculation_n

    def initialize(js)
      self.transform_plan = get_transform_plan(js)

      var_regex = /^\w+\W/
      var_match = @transform_plan[0].match(var_regex)
      
      if var_match.nil?
        raise "RegexMatchError, caller: __init__, pattern: #{var_regex.source}"
      end
      
      var = var_match[0][0..-2]
      
      self.transform_map = get_transform_map(js, var)

      self.js_func_patterns = [
        %r"\w+\.(\w+)\(\w,(\d+)\)",
        %r"\w+\[(\"\w+\")\]\(\w,(\d+)\)"
      ]
    end

    def get_signature(ciphered_signature)
      signature = ciphered_signature.split('')

      transform_plan.each do |js_func|
        name, argument = parse_function(js_func)
        signature = transform_map[name].call(signature, argument)
      end

      signature.join('')
    end

    private

    def parse_function(js_func)
      js_func_patterns.each do |pattern|
        regex = Regexp.new(pattern)
        parse_match = js_func.match(regex)

        if parse_match
          fn_name = parse_match[1]
          fn_arg = parse_match[2]

          return [fn_name, fn_arg]
        end

        raise RegexMatchError.new('parse_function', 'js_func_patterns')
      end
    end

    def get_initial_function_name(js)
      function_patterns = [
        %r"\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r"\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r'(?:\b|[^a-zA-Z0-9$])(?<sig>[a-zA-Z0-9$]{2})\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)',  # noqa: E501
        %r'(?<sig>[a-zA-Z0-9$]+)\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)',  # noqa: E501
        %r'(?<quote>["\'])signature\k<quote>\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(',
        %r"\.sig\|\|(?<sig>[a-zA-Z0-9$]+)\(",
        %r"yt\.akamaized\.net/\)\s*\|\|\s*.*?\s*[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*(?:encodeURIComponent\s*\()?\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r"\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r"\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r"\bc\s*&&\s*a\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r"\bc\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
        %r"\bc\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(",  # noqa: E501
      ]

      function_patterns.each do |pattern|
        regex = Regexp.new(pattern)
        function_match = js.match(regex)
        if function_match
          return function_match[:sig]
        end
      end

      raise RegexMatchError.new('get_initial_function_name', 'multiple')
    end

    def get_transform_plan(js)
      name = Regexp.escape(get_initial_function_name(js))
      pattern = "#{name}=function\\(\\w\\)\\{[a-z=\\.\(\"\\)]*;(.*);(?:.+)\\}"

      Utils.regex_search(pattern, js, 1).split(';')
    end

    def get_transform_object(js, var)
      escaped_var = Regexp.escape(var)
      pattern = "var #{escaped_var}={(.*?)};"
      regex = Regexp.new(pattern, Regexp::MULTILINE)
      transform_match = regex.match(js)
      
      if transform_match.nil?
        raise RegexMatchError.new('get_transform_object', pattern)
      end
      
      transform_match[1].gsub("\n", " ").split(", ")
    end

    def get_transform_map(js, var)
      transform_obejct = get_transform_object(js, var)
      mapper = {}
      
      transform_obejct.each do |obj|
        name, function = obj.split(':')
        fn = map_functions(function)
        mapper[name] = fn
      end

      mapper
    end

    def reverse(arr)
      # Ruby equivalent of JavaScript's Array.reverse()
      arr.reverse!
    end
    
    def splice(arr, index)
      # Ruby equivalent of JavaScript's Array.splice(0, index)
      arr.shift(index.to_i)
    end
    
    def swap(arr, index)
      # Ruby equivalent of the JavaScript swapping function
      temp = arr[0]
      arr[0] = arr[index.to_i % arr.length]
      arr[index.to_i % arr.length] = temp
    end

    def map_functions(function)
      mapper = [
        # function(a){a.reverse()}
        [%r"{\w\.reverse\(\)}", method(:reverse)],
        # function(a,b){a.splice(0,b)}
        [%r"{\w\.splice\(0,\w\)}", method(:splice)],
        # function(a,b){var c=a[0];a[0]=a[b%a.length];a[b]=c}
        [%r"{var\s\w=\w\[0\];\w\[0\]=\w\[\w\%\w.length\];\w\[\w\]=\w}", method(:swap)],
        # function(a,b){var c=a[0];a[0]=a[b%a.length];a[b%a.length]=c}
        [%r"{var\s\w=\w\[0\];\w\[0\]=\w\[\w\%\w.length\];\w\[\w\%\w.length\]=\w}", method(:swap)]
      ]

      mapper.each do |pattern, fn|
        return fn if Regexp.new(pattern).match?(function)
      end
    
      raise RegexMatchError.new('map_functions', 'multiple')
    end
  end
end
