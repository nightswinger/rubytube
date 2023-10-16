module RubyTube
  class Cipher
    attr_accessor :transform_plan, :transform_map, :js_func_patterns, :throttling_plan, :throttling_array, :calculation_plan, :calculation_n

    def initialize(js)
      self.transform_plan = get_transform_plan(js)

      var_regex = %r{^\$*\w+\W}
      var_match = @transform_plan[0].match(var_regex)

      if var_match.nil?
        raise "RegexMatchError, caller: __init__, pattern: #{var_regex.source}"
      end

      var = var_match[0][0..-2]

      self.transform_map = get_transform_map(js, var)

      self.js_func_patterns = [
        %r{\w+\.(\w+)\(\w,(\d+)\)},
        %r{\w+\[("\w+")\]\(\w,(\d+)\)}
      ]

      self.throttling_array = get_throttling_function_array(js)
      self.throttling_plan = get_throttling_plan(js)
    end

    def calculate_n(initial_n)
      throttling_array.map! do |item|
        (item == "b") ? initial_n : item
      end

      throttling_plan.each do |step|
        curr_func = throttling_array[step[0].to_i]

        unless curr_func.respond_to?(:call)
          raise ExtractError.new("calculate_n", "curr_func")
        end

        first_arg = throttling_array[step[1].to_i]

        case step.length
        when 2
          curr_func.call(first_arg)
        when 3
          second_arg = throttling_array[step[2].to_i]
          curr_func.call(first_arg, second_arg)
        end
      end

      initial_n.join
    end

    def get_signature(ciphered_signature)
      signature = ciphered_signature.split("")

      transform_plan.each do |js_func|
        name, argument = parse_function(js_func)
        signature = transform_map[name].call(signature, argument)
      end

      signature.join("")
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

        raise RegexMatchError.new("parse_function", "js_func_patterns")
      end
    end

    def get_initial_function_name(js)
      function_patterns = [
        %r{\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r{\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r'(?:\b|[^a-zA-Z0-9$])(?<sig>[a-zA-Z0-9$]{2})\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)',  # noqa: E501
        %r'(?<sig>[a-zA-Z0-9$]+)\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)',  # noqa: E501
        %r{(?<quote>["\'])signature\k<quote>\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(},
        %r{\.sig\|\|(?<sig>[a-zA-Z0-9$]+)\(},
        %r{yt\.akamaized\.net/\)\s*\|\|\s*.*?\s*[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*(?:encodeURIComponent\s*\()?\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r{\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r{\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r{\bc\s*&&\s*a\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r{\bc\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(},  # noqa: E501
        %r{\bc\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*\([^)]*\)\s*\(\s*(?<sig>[a-zA-Z0-9$]+)\(}  # noqa: E501
      ]

      function_patterns.each do |pattern|
        regex = Regexp.new(pattern)
        function_match = js.match(regex)
        if function_match
          return function_match[:sig]
        end
      end

      raise RegexMatchError.new("get_initial_function_name", "multiple")
    end

    def get_transform_plan(js)
      name = Regexp.escape(get_initial_function_name(js))
      pattern = "#{name}=function\\(\\w\\)\\{[a-z=\\.(\"\\)]*;(.*);(?:.+)\\}"

      Utils.regex_search(pattern, js, 1).split(";")
    end

    def get_transform_object(js, var)
      escaped_var = Regexp.escape(var)
      pattern = "var #{escaped_var}={(.*?)};"
      regex = Regexp.new(pattern, Regexp::MULTILINE)
      transform_match = regex.match(js)

      if transform_match.nil?
        raise RegexMatchError.new("get_transform_object", pattern)
      end

      transform_match[1].tr("\n", " ").split(", ")
    end

    def get_transform_map(js, var)
      transform_obejct = get_transform_object(js, var)
      mapper = {}

      transform_obejct.each do |obj|
        name, function = obj.split(":")
        fn = map_functions(function)
        mapper[name] = fn
      end

      mapper
    end

    def reverse(arr, _ = nil)
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
      arr
    end

    def push(arr, val)
      arr.push(val)
    end

    def throttling_mod_func(d, e)
      (e % d.length + d.length) % d.length
    end

    def throttling_unshift(d, e)
      e = throttling_mod_func(d, e)
      new_arr = d[-e..-1] + d[0...-e]
      d.clear
      new_arr.each { |el| d << el }
    end

    def throttling_cipher_function(d, e)
      h = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".split("")
      f = 96
      self_arr = e.split("")

      copied_array = d.clone

      copied_array.each_with_index do |l, m|
        bracket_val = (h.index(l) - h.index(self_arr[m]) + m - 32 + f) % h.length
        self_arr << h[bracket_val]
        d[m] = h[bracket_val]
        f -= 1
      end
    end

    def throttling_nested_splice(d, e)
      e = throttling_mod_func(d, e)
      inner_splice = js_splice(d, e, 1, d[0])
      js_splice(d, 0, 1, inner_splice[0])
    end

    def throttling_prepend(d, e)
      start_len = d.length

      e = throttling_mod_func(d, e)

      new_arr = d[-e..-1] + d[0...-e]

      d.clear.concat(new_arr)

      end_len = d.length
      raise "Length mismatch" unless start_len == end_len
    end

    def js_splice(arr, start, delete_count = nil, *items)
      if start.is_a? Integer
        start = arr.length if start > arr.length
        start += arr.length if start < 0
      else
        start = 0
      end

      delete_count = arr.length - start if delete_count.nil? || delete_count >= arr.length - start
      deleted_elements = arr[start, delete_count]

      new_arr = arr[0...start] + items + arr[(start + delete_count)..-1]

      arr.clear.concat(new_arr)

      deleted_elements
    end

    def map_functions(function)
      mapper = [
        # function(a){a.reverse()}
        [%r"{\w\.reverse\(\)}", method(:reverse)],
        # function(a,b){a.splice(0,b)}
        [%r"{\w\.splice\(0,\w\)}", method(:splice)],
        # function(a,b){var c=a[0];a[0]=a[b%a.length];a[b]=c}
        [%r"{var\s\w=\w\[0\];\w\[0\]=\w\[\w%\w.length\];\w\[\w\]=\w}", method(:swap)],
        # function(a,b){var c=a[0];a[0]=a[b%a.length];a[b%a.length]=c}
        [%r"{var\s\w=\w\[0\];\w\[0\]=\w\[\w%\w.length\];\w\[\w%\w.length\]=\w}", method(:swap)]
      ]

      mapper.each do |pattern, fn|
        return fn if Regexp.new(pattern).match?(function)
      end

      raise RegexMatchError.new("map_functions", "multiple")
    end

    def get_throttling_function_name(js)
      function_patterns = [
        %r{a\.[a-zA-Z]\s*&&\s*\([a-z]\s*=\s*a\.get\("n"\)\)\s*&&.*?\|\|\s*([a-z]+)},
        %r{\([a-z]\s*=\s*([a-zA-Z0-9$]+)(\[\d+\])\([a-z]\)}
      ]

      function_patterns.each do |pattern|
        regex = Regexp.new(pattern)
        function_match = js.match(regex)
        next unless function_match

        if function_match.captures.length == 1
          return function_match[1]
        end

        idx = function_match[2]
        if idx
          idx = idx.tr("[]", "")
          array_match = js.match(/var #{Regexp.escape(function_match[1])}\s*=\s*(\[.+?\])/)
          if array_match
            array = array_match[1].tr("[]", "").split(",")
            array = array.map(&:strip)
            return array[idx.to_i]
          end
        end
      end

      raise RegexMatchError.new("get_throttling_function_name", "multiple")
    end

    def get_throttling_function_code(js)
      name = Regexp.escape(get_throttling_function_name(js))

      pattern_start = %r{#{name}=function\(\w\)}
      regex = Regexp.new(pattern_start)
      match = js.match(regex)

      code_lines_list = Parser.find_object_from_startpoint(js, match.end(0)).split("\n")
      joined_lines = code_lines_list.join("")

      "#{match[0]}#{joined_lines}"
    end

    def get_throttling_function_array(js)
      raw_code = get_throttling_function_code(js)

      array_regex = /,c=\[/
      match = raw_code.match(array_regex)
      array_raw = Parser.find_object_from_startpoint(raw_code, match.end(0) - 1)
      str_array = Parser.throttling_array_split(array_raw)

      converted_array = []
      str_array.each do |el|
        begin
          converted_array << Integer(el)
          next
        rescue ArgumentError
          # Not an integer value.
        end

        if el == "null"
          converted_array << nil
          next
        end

        if el.start_with?('"') && el.end_with?('"')
          converted_array << el[1..-2]
          next
        end

        if el.start_with?("function")
          mapper = [
            [%r"{for\(\w=\(\w%\w\.length\+\w\.length\)%\w\.length;\w--;\)\w\.unshift\(\w.pop\(\)\)}", method(:throttling_unshift)],
            [%r"{\w\.reverse\(\)}", method(:reverse)],
            [%r"{\w\.push\(\w\)}", method(:push)],
            [%r";var\s\w=\w\[0\];\w\[0\]=\w\[\w\];\w\[\w\]=\w}", method(:swap)],
            [%r{case\s\d+}, method(:throttling_cipher_function)],
            [%r{\w\.splice\(0,1,\w\.splice\(\w,1,\w\[0\]\)\[0\]\)}, method(:throttling_nested_splice)],
            [%r";\w\.splice\(\w,1\)}", method(:js_splice)],
            [%r"\w\.splice\(-\w\)\.reverse\(\)\.forEach\(function\(\w\){\w\.unshift\(\w\)}\)", method(:throttling_prepend)],
            [%r"for\(var \w=\w\.length;\w;\)\w\.push\(\w\.splice\(--\w,1\)\[0\]\)}", method(:reverse)]
          ]

          found = false
          mapper.each do |pattern, fn|
            if el.match?(pattern)
              converted_array << fn
              found = true
            end
          end
          next if found
        end

        converted_array << el
      end

      converted_array.map! { |el| el.nil? ? converted_array : el }
      converted_array
    end

    def get_throttling_plan(js)
      raw_code = get_throttling_function_code(js)

      transform_start = "try{"
      plan_regex = Regexp.new(transform_start)
      match = raw_code.match(plan_regex)

      transform_plan_raw = Parser.find_object_from_startpoint(raw_code, match.end(0) - 1)
      step_regex = %r{c\[(\d+)\]\(c\[(\d+)\](,c(\[(\d+)\]))?\)}
      matches = transform_plan_raw.scan(step_regex)
      transform_steps = []

      matches.each do |match|
        if match[3]
          transform_steps.push([match[0], match[1], match[3]])
        else
          transform_steps.push([match[0], match[1]])
        end
      end

      transform_steps
    end
  end
end
