module RubyTube
  module Parser
    module_function

    def parse_for_object(html, preceding_regex)
      regex = Regexp.new(preceding_regex)
      result = regex.match(html)

      if result.nil?
        raise HTMLParseError, "No matches for regex #{preceding_regex}"
      end
      start_index = result.end(0)

      return parse_for_object_from_startpoint(html, start_index)
    end

    def find_object_from_startpoint(html, start_point)
      html = html[start_point..-1]
      unless ['{', '['].include?(html[0])
        raise HTMLParseError, "Invalid start point. Start of HTML:\n#{html[0..19]}"
      end

      last_char = '{'
      curr_char = nil
      stack = [html[0]]
      i = 1

      context_closers = {
        '{' => '}',
        '[' => ']',
        '"' => '"',
        '/' => '/',
      }

      while i < html.length
        break if stack.empty?

        last_char = curr_char unless [' ', '\n'].include?(curr_char)
        curr_char = html[i]
        curr_context = stack.last

        if curr_char == context_closers[curr_context]
          stack.pop
          i += 1
          next
        end

        if ['"', '/'].include?(curr_context)
          if curr_char == '\\'
            i += 2
            next
          end
        else
          if context_closers.keys.include?(curr_char)
            unless curr_char == '/' && !['(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}', ';'].include?(last_char)
              stack.push(curr_char)
            end
          end
        end

        i += 1
      end

      full_obj = html[0...i]
      full_obj
    end

    def parse_for_object_from_startpoint(html, start_point)
      html = html[start_point..-1]

      unless ['{', '['].include?(html[0])
        raise HTMLParseError, "Invalid start point. Start of HTML:\n#{html[0..19]}"
      end

      # First letter MUST be an open brace, so we put that in the stack,
      # and skip the first character.
      last_char = '{'
      curr_char = nil
      stack = [html[0]]
      i = 1

      context_closers = {
        '{' => '}',
        '[' => ']',
        '"' => '"',
        '\'': '\'',
        '/' => '/' # JavaScript regex
      }

      while i < html.length
        break if stack.empty?
    
        last_char = curr_char unless [' ', '\n'].include?(curr_char)
        curr_char = html[i]
        curr_context = stack.last
    
        # If we've reached a context closer, we can remove an element off the stack
        if curr_char == context_closers[curr_context]
          stack.pop
          i += 1
          next
        end
        # Strings and regex expressions require special context handling because they can contain
        # context openers *and* closers
        if ['"', '/'].include?(curr_context)
          # If there's a backslash in a string or regex expression, we skip a character
          if curr_char == '\\'
            i += 2
            next
          end
        else
          # Non-string contexts are when we need to look for context openers.
          if context_closers.keys.include?(curr_char)
            # Slash starts a regular expression depending on context
            unless curr_char == '/' && ['(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}', ';'].include?(last_char)
              stack << curr_char
            end
          end
        end

        i += 1
      end

      full_obj = html[0..(i - 1)]
      full_obj
    end

    def throttling_array_split(js_array)
      results = []
      curr_substring = js_array[1..-1]
    
      comma_regex = /,/
      func_regex = /function\([^)]*\)/
    
      until curr_substring.empty?
        if curr_substring.start_with?('function')
          match = func_regex.match(curr_substring)
          match_start = match.begin(0)
          match_end = match.end(0)
    
          function_text = find_object_from_startpoint(curr_substring, match_end)
          full_function_def = curr_substring[0, match_end + function_text.length]
          results << full_function_def
          curr_substring = curr_substring[full_function_def.length + 1..-1]
        else
          match = comma_regex.match(curr_substring)

          begin
            match_start = match.begin(0)
            match_end = match.end(0)
          rescue NoMethodError
            match_start = curr_substring.length - 1
            match_end = match_start + 1
          end
    
          curr_el = curr_substring[0, match_start]
          results << curr_el
          curr_substring = curr_substring[match_end..-1]
        end
      end
    
      results
    end
  end
end
