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
  end
end
