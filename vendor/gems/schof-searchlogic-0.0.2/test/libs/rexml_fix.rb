module REXML
  module Formatters
    class Pretty < Default
      private
      def wrap(string, width)
        # Recursivly wrap string at width.
        return string if string.length <= width
        place = string.rindex(/\s+/, width) # Position in string with last ' ' before cutoff
        return string if place.nil?
        return string[0,place] + "\n" + wrap(string[place+1..-1], width)
      end
    end
  end
end